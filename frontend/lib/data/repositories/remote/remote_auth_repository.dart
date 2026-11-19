import '../../../core/errors/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/token_store.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../../../domain/models/app_user.dart';
import '../auth_repository.dart';

final class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._api, this._tokens, [this._storage]);

  final ApiClient _api;
  final TokenStore _tokens;
  final SecureTokenStorage? _storage;
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
    final token = data['token'] as String;
    _tokens.replace(token);
    await _remember(token);
    return user;
  }

  @override
  Future<AppUser?> restoreSession() async {
    var token = _tokens.accessToken;
    // After a restart, pick up the session saved on this device.
    if (token == null) {
      token = await _saved();
      if (token == null) return null;
      _tokens.replace(token);
    }
    try {
      final response = await _api.request('GET', ApiEndpoints.me);
      if (_tokens.accessToken != token) return null;
      return AppUser.fromJson(response['data'] as Map<String, Object?>);
    } on UnauthorizedException {
      await _forget();
      return null;
    }
  }

  @override
  Future<void> logout() async {
    _generation++;
    _tokens.clear();
    await _forget();
  }

  // Secure storage can fail on some devices; the session then simply is not
  // remembered.
  Future<void> _remember(String token) async {
    try {
      await _storage?.writeRefreshToken(token);
    } on Object {
      // ignore
    }
  }

  Future<String?> _saved() async {
    try {
      return await _storage?.readRefreshToken();
    } on Object {
      return null;
    }
  }

  Future<void> _forget() async {
    try {
      await _storage?.clearRefreshToken();
    } on Object {
      // ignore
    }
  }
}
