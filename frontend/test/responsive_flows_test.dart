import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:project/app.dart';
import 'package:project/core/config/app_config.dart';
import 'package:project/core/theme/app_theme.dart';
import 'package:project/di/app_dependencies.dart';
import 'package:project/di/app_scope.dart';
import 'package:project/features/auth/controllers/auth_controller.dart';
import 'package:project/routing/app_router.dart';
import 'package:project/routing/feature_routes.dart';

void main() {
  for (final width in [360.0, 600.0, 900.0, 1440.0]) {
    testWidgets('Core pages fit at ${width.toInt()} px with larger text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.25;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = _Harness();
      addTearDown(harness.dispose);
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _check(tester, harness.router, '/register', 'Create your account');

      await harness.auth.signIn('ali@student.com', 'Ali@1234');
      for (final (path, title) in const [
        ('/student', 'Hi, Ali'),
        ('/student/complaints', 'My complaints'),
        ('/student/new', "What's the issue about?"),
        ('/student/complaints/demo-1', 'Projector not working in Lab 3'),
        ('/student/profile', 'Profile'),
      ]) {
        await _check(tester, harness.router, path, title);
      }
      await _check(
        tester,
        harness.router,
        '/student/new',
        "What's the issue about?",
      );
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      if (width <= 600) {
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
      }
      expect(find.text('Title'), findsOneWidget);

      await harness.auth.signOut();
      await harness.auth.signIn('library.admin@campus.com', 'Admin@1234');
      for (final (path, title) in const [
        ('/department', 'Library Administration'),
        ('/department/complaints', 'Department complaints'),
        (
          '/department/complaints/demo-2',
          'Library closes too early before exams',
        ),
        ('/department/complaints/demo-1', 'Access denied'),
      ]) {
        await _check(tester, harness.router, path, title);
      }

      await harness.auth.signOut();
      await harness.auth.signIn('super.admin@campus.com', 'Admin@1234');
      for (final (path, title) in const [
        ('/admin', 'Campus dashboard'),
        ('/admin/complaints', 'All complaints'),
        ('/admin/complaints/demo-1', 'Projector not working in Lab 3'),
      ]) {
        await _check(tester, harness.router, path, title);
      }
      expect(find.text('Post remark'), findsNothing);
    });
  }

  testWidgets(
    'Login resumes a complaint deep link with server-like scope checks',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      harness.router.go('/department/complaints/demo-1');
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'library.admin@campus.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Admin@1234');
      final submit = find.widgetWithText(FilledButton, 'Log in');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Access denied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Submitting from the student dashboard updates the complaint list',
    (tester) async {
      final harness = _Harness();
      addTearDown(harness.dispose);
      await harness.auth.signIn('ali@student.com', 'Ali@1234');
      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-issue')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Reading room lights',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'The upstairs reading room lights no longer turn on.',
      );
      final submit = find.widgetWithText(FilledButton, 'Submit complaint');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Complaint submitted'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();
      expect(find.text('Reading room lights'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _check(
  WidgetTester tester,
  GoRouter router,
  String location,
  String title,
) async {
  router.go(location);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: location);
  expect(find.text(title), findsWidgets, reason: location);
}

final class _Harness {
  _Harness() {
    auth = AuthController(dependencies.auth)..ready = true;
    router = AppRouter.authenticated(
      auth: auth,
      featureRoutes: featureRoutes(auth),
    );
  }

  final dependencies = AppDependencies.create(
    const AppConfig(apiBaseUrl: '', useMock: true),
  );
  late final AuthController auth;
  late final GoRouter router;

  Widget get app => AppScope(
    dependencies: dependencies,
    child: CampusConnectApp(router: router, theme: AppTheme.student()),
  );

  void dispose() {
    router.dispose();
    auth.dispose();
  }
}
