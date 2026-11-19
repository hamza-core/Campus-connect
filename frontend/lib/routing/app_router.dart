import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/screens/auth_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/shared/screens/access_denied_screen.dart';
import '../features/shared/screens/not_found_screen.dart';
import 'route_guard.dart';

final class AppRouter {
  const AppRouter._();

  static GoRouter create({required WidgetBuilder home}) => GoRouter(
    routes: [GoRoute(path: '/', builder: (context, state) => home(context))],
    errorBuilder: _notFound,
  );

  static GoRouter authenticated({
    required AuthController auth,
    required List<RouteBase> featureRoutes,
  }) => GoRouter(
    refreshListenable: auth,
    redirect: (context, state) => RouteGuard.redirect(auth, state.uri),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => AuthScreen(controller: auth),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            AuthScreen(controller: auth, registration: true),
      ),
      GoRoute(
        path: '/access-denied',
        builder: (context, state) => const AccessDeniedScreen(),
      ),
      ...featureRoutes,
    ],
    errorBuilder: _notFound,
  );

  static Widget _notFound(BuildContext context, GoRouterState state) =>
      NotFoundScreen(onGoHome: () => context.go('/'));
}
