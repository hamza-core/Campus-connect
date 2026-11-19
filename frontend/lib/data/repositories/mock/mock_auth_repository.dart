import '../../../core/errors/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/enums/user_role.dart';
import '../../../domain/models/app_user.dart';
import '../../mock_data/mock_seed.dart';
import '../auth_repository.dart';

final class MockAuthRepository implements AuthRepository {
  final _accounts = MockSeed.accounts();
  AppUser? _user;
  int _nextId = 1;

  AppUser get requiredUser => _user ?? (throw const UnauthorizedException());

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw const UnauthorizedException('Invalid email or password.');
    }
    return _user = account.user;
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String? studentId,
  }) async {
    final address = email.trim().toLowerCase();
    if (Validators.email(address) != null ||
        Validators.length(name, 'Name', 2, 80) != null ||
        password.length < 8 ||
        password.length > 72 ||
        (studentId?.length ?? 0) > 30) {
      throw const ValidationException('Check the registration details.');
    }
    if (_accounts.containsKey(address)) {
      throw const ConflictException('An account already uses this email.');
    }
    final user = AppUser(
      id: 'registered-${_nextId++}',
      name: name.trim(),
      email: address,
      role: UserRole.student,
      studentId: studentId,
    );
    _accounts[address] = (user: user, password: password);
    return _user = user;
  }

  @override
  Future<AppUser?> restoreSession() async => _user;

  @override
  Future<void> logout() async => _user = null;
}
