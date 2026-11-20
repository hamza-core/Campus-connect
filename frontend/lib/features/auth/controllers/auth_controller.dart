import '../../../core/controllers/base_controller.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/app_user.dart';

final class AuthController extends BaseController {
  AuthController(this._repository, {this.onSessionChange});

  final AuthRepository _repository;

  /// Called when the signed-in user may change (sign in, out, expiry), so
  /// per-user caches can be dropped.
  final void Function()? onSessionChange;
  AppUser? user;
  bool ready = false;
  bool signedOut = false;
  String? sessionMessage;
  int _session = 0;

  Future<void> restore() async {
    final session = _session;
    await Future.wait<void>([
      Future<void>.delayed(const Duration(milliseconds: 1200)),
      run<AppUser?>(
        _repository.restoreSession,
        onSuccess: (value) {
          if (session == _session) user = value;
        },
      ),
    ]);
    ready = true;
    safeNotify();
  }

  Future<void> signIn(String email, String password) =>
      _authenticate(() => _repository.login(email: email, password: password));

  Future<void> register(
    String name,
    String email,
    String password, {
    String? studentId,
  }) => _authenticate(
    () => _repository.register(
      name: name,
      email: email,
      password: password,
      studentId: studentId,
    ),
  );

  Future<void> _authenticate(Future<AppUser> Function() operation) {
    final session = ++_session;
    onSessionChange?.call();
    signedOut = false;
    sessionMessage = null;
    return run(
      operation,
      onSuccess: (value) {
        if (session == _session) user = value;
      },
    );
  }

  Future<void> signOut() async {
    ++_session;
    onSessionChange?.call();
    await _repository.logout();
    user = null;
    signedOut = true;
    sessionMessage = null;
    safeNotify();
  }

  void expireSession() {
    ++_session;
    onSessionChange?.call();
    user = null;
    signedOut = false;
    sessionMessage = 'Your session expired. Please sign in again.';
    safeNotify();
  }
}
