import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/app.dart';
import 'package:project/core/config/app_config.dart';
import 'package:project/core/theme/app_theme.dart';
import 'package:project/di/app_dependencies.dart';
import 'package:project/di/app_scope.dart';
import 'package:project/features/auth/controllers/auth_controller.dart';
import 'package:project/routing/app_router.dart';
import 'package:project/routing/feature_routes.dart';

void main() {
  testWidgets('Switching tabs never shows two screens at once', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final dependencies = AppDependencies.create(
      const AppConfig(apiBaseUrl: '', useMock: true),
    );
    final auth = AuthController(
      dependencies.auth,
      onSessionChange: dependencies.cache.clear,
    )..ready = true;
    final router = AppRouter.authenticated(
      auth: auth,
      featureRoutes: featureRoutes(auth),
    );
    addTearDown(() {
      router.dispose();
      auth.dispose();
    });
    await tester.pumpWidget(
      AppScope(
        dependencies: dependencies,
        child: CampusConnectApp(router: router, theme: AppTheme.student()),
      ),
    );
    await tester.pumpAndSettle();
    await auth.signIn('ali@student.com', 'Ali@1234');
    router.go('/student');
    await tester.pumpAndSettle();
    expect(find.text('Hi, Ali'), findsOneWidget);

    // Mid-transition: the old screen must already be gone.
    router.go('/student/complaints');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('Hi, Ali'), findsNothing, reason: 'old tab still visible');
    expect(find.text('My complaints'), findsWidgets);

    router.go('/student/profile');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      find.text('My complaints'),
      findsNothing,
      reason: 'old tab still visible',
    );
    await tester.pumpAndSettle();
  });
}
