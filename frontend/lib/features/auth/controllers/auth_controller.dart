import '../../../core/controllers/base_controller.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/app_user.dart';

final class AuthController extends BaseController {
  AuthController(this._repository);

  final AuthRepository _repository;
  AppUser? user;
  bool ready = false;
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

  Future<void> register(String name, String email, String password) =>
      _authenticate(
        () =>
            _repository.register(name: name, email: email, password: password),
      );

  Future<void> _authenticate(Future<AppUser> Function() operation) {
    final session = ++_session;
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
    await _repository.logout();
    user = null;
    sessionMessage = null;
    safeNotify();
  }

  void expireSession() {
    ++_session;
    user = null;
    sessionMessage = 'Your session expired. Please sign in again.';
    safeNotify();
  }
}
