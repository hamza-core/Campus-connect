import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/token_store.dart';
import '../../../domain/models/app_user.dart';
import '../auth_repository.dart';

final class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;
  int _generation = 0;

  @override
  Future<AppUser> login({required String email, required String password}) =>
      _authenticate(ApiEndpoints.login, {'email': email, 'password': password});

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String? studentId,
  }) => _authenticate(ApiEndpoints.register, {
    'name': name,
    'email': email,
    'password': password,
    'studentId': ?studentId,
  });

  Future<AppUser> _authenticate(
    String endpoint,
    Map<String, Object?> body,
  ) async {
    final generation = ++_generation;
    final response = await _api.request(
      'POST',
      endpoint,
      body: body,
      authenticated: false,
    );
    // The API returns { token, user } at the top level for login/register.
    // Also accept a { data: { token, user } } envelope.
    final data = response['data'] is Map<String, Object?>
        ? response['data'] as Map<String, Object?>
        : response;
    final user = AppUser.fromJson(data['user'] as Map<String, Object?>);
    if (generation != _generation) throw const UnauthorizedException();
    _tokens.replace(data['token'] as String);
    return user;
  }

  @override
  Future<AppUser?> restoreSession() async {
    final token = _tokens.accessToken;
    if (token == null) return null;
    try {
      final response = await _api.request('GET', ApiEndpoints.me);
      if (_tokens.accessToken != token) return null;
      return AppUser.fromJson(response['data'] as Map<String, Object?>);
    } on UnauthorizedException {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    _generation++;
    _tokens.clear();
  }
}
