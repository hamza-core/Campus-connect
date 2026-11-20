import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:go_router/go_router.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/platform/android_background_alerts.dart';
import 'core/platform/background_alerts.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/error_view.dart';
import 'di/app_dependencies.dart';
import 'di/app_scope.dart';
import 'domain/enums/user_role.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'routing/app_router.dart';
import 'routing/feature_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  // System alerts while minimized are only available on Android with a live API.
  final BackgroundAlerts alerts =
      !config.useMock && !kIsWeb && Platform.isAndroid
      ? AndroidBackgroundAlerts()
      : const NoopBackgroundAlerts();
  if (alerts is AndroidBackgroundAlerts) {
    FlutterForegroundTask.initCommunicationPort();
  }

  final dependencies = AppDependencies.create(config);
  final auth = AuthController(
    dependencies.auth,
    onSessionChange: dependencies.cache.clear,
  );
  dependencies.tokens?.onExpired = auth.expireSession;
  final GoRouter router = AppRouter.authenticated(
    auth: auth,
    featureRoutes: featureRoutes(auth),
  );

  void openComplaint(String id) =>
      router.go('/student/complaints/${Uri.encodeComponent(id)}');
  await alerts.init(onOpenComplaint: openComplaint);

  // Only students receive notifications; connect while a student is signed in.
  auth.addListener(() {
    if (auth.user?.role == UserRole.student) {
      dependencies.notifications.start();
      alerts
          .requestPermissions()
          .then((_) => alerts.startKeepAlive())
          .catchError((Object _) {});
    } else {
      dependencies.notifications.stop();
      alerts.stopKeepAlive().catchError((Object _) {});
    }
  });

  // Pop up a system notification when a live update arrives while the app is
  // minimized (the in-app banner covers the foreground case).
  String? lastAlerted;
  dependencies.notifications.addListener(() {
    final latest = dependencies.notifications.latest;
    if (latest == null || latest.id == lastAlerted) return;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      lastAlerted = latest.id;
      alerts.show(latest).catchError((Object _) {});
    }
  });

  runApp(
    AppScope(
      dependencies: dependencies,
      child: CampusConnectApp(router: router, theme: theme, auth: auth),
    ),
  );
  auth.restore();

  // If a notification tap launched the app, open that complaint after sign-in.
  alerts.launchedFromComplaint().then((id) {
    if (id == null) return;
    void go() {
      if (auth.user?.role == UserRole.student) {
        auth.removeListener(go);
        openComplaint(id);
      }
    }

    auth.addListener(go);
    go();
  });
}
