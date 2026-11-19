import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/error_view.dart';
import 'di/app_dependencies.dart';
import 'di/app_scope.dart';
import 'routing/app_router.dart';

void main() {
  final config = AppConfig.fromEnvironment();
  AppDependencies? dependencies;
  if (config.useMock || config.apiBaseUrl.isNotEmpty) {
    dependencies = AppDependencies.create(config);
  }
  final router = AppRouter.create(
    home: (context) => Scaffold(
      body: Center(
        child: dependencies == null
            ? const ErrorView(
                message: 'Set API_BASE_URL to connect to CampusConnect.',
              )
            : const Text('CampusConnect'),
      ),
    ),
  );
  final app = CampusConnectApp(router: router, theme: AppTheme.student());
  runApp(
    dependencies == null
        ? app
        : AppScope(dependencies: dependencies, child: app),
  );
}
