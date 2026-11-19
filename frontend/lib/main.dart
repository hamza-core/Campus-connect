import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/error_view.dart';
import 'di/app_dependencies.dart';
import 'di/app_scope.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'routing/app_router.dart';
import 'routing/feature_routes.dart';

void main() {
  final config = AppConfig.fromEnvironment();
  final theme = AppTheme.student();
  if (!config.useMock && config.apiBaseUrl.isEmpty) {
    final router = AppRouter.create(
      home: (context) => const Scaffold(
        body: Center(
          child: ErrorView(
            message: 'Set API_BASE_URL to connect to CampusConnect.',
          ),
        ),
      ),
    );
    runApp(CampusConnectApp(router: router, theme: theme));
    return;
  }
  final dependencies = AppDependencies.create(config);
  final auth = AuthController(dependencies.auth);
  dependencies.tokens?.onExpired = auth.expireSession;
  final GoRouter router = AppRouter.authenticated(
    auth: auth,
    featureRoutes: featureRoutes(auth),
  );
  runApp(
    AppScope(
      dependencies: dependencies,
      child: CampusConnectApp(router: router, theme: theme),
    ),
  );
  auth.restore();
}
