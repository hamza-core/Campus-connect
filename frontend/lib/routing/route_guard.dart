import '../domain/enums/user_role.dart';
import '../features/auth/controllers/auth_controller.dart';

abstract final class RouteGuard {
  static String home(UserRole role) => switch (role) {
    UserRole.student => '/student',
    UserRole.departmentAdmin => '/department',
    UserRole.superAdmin => '/admin',
  };

  static String? redirect(AuthController auth, Uri uri) {
    final path = uri.path;
    final next = _next(uri.queryParameters['next']);
    if (!auth.ready) {
      return path == '/splash' ? null : _withNext('/splash', uri.toString());
    }
    final user = auth.user;
    final publicAuth = path == '/login' || path == '/register';
    if (user == null) {
      if (publicAuth) return null;
      if (auth.signedOut) return '/login';
      final requested = path == '/splash' ? next : _next(uri.toString());
      return _withNext('/login', requested);
    }
    final destination = home(user.role);
    if (path == '/splash' || publicAuth) return next ?? destination;
    if (path == '/') return destination;
    if (UserRole.values.any((role) {
      final prefix = home(role);
      return prefix != destination &&
          (path == prefix || path.startsWith('$prefix/'));
    })) {
      return '/access-denied';
    }
    return null;
  }

  static String? _next(String? value) {
    if (value == null || !value.startsWith('/') || value.startsWith('//')) {
      return null;
    }
    final path = Uri.tryParse(value)?.path;
    if (path == null ||
        !UserRole.values.any((role) {
          final prefix = home(role);
          return path == prefix || path.startsWith('$prefix/');
        })) {
      return null;
    }
    return value;
  }

  static String _withNext(String path, String? next) => Uri(
    path: path,
    queryParameters: next == null ? null : {'next': next},
  ).toString();
}
