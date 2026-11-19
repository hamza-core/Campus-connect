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
    if (!auth.ready) {
      return path == '/splash'
          ? null
          : '/splash?next=${Uri.encodeQueryComponent(uri.toString())}';
    }
    final user = auth.user;
    final publicAuth = path == '/login' || path == '/register';
    if (user == null) return publicAuth ? null : '/login';
    final destination = home(user.role);
    if (path == '/splash') {
      final next = uri.queryParameters['next'];
      return next != null &&
              next.startsWith('/') &&
              !next.startsWith('//') &&
              next != '/splash'
          ? next
          : destination;
    }
    if (path == '/' || publicAuth) return destination;
    if (['/student', '/department', '/admin'].any(
      (prefix) =>
          (path == prefix || path.startsWith('$prefix/')) &&
          prefix != destination,
    )) {
      return '/access-denied';
    }
    return null;
  }
}
