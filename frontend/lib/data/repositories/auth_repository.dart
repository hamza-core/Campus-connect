import '../../domain/models/app_user.dart';

abstract interface class AuthRepository {
  Future<AppUser> login({required String email, required String password});
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String? studentId,
  });
  Future<AppUser?> restoreSession();
  Future<void> logout();
}
