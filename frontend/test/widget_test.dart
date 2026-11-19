import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/app.dart';
import 'package:project/routing/app_router.dart';

void main() {
  testWidgets('Unknown routes show a recoverable 404 page', (tester) async {
    final router = AppRouter.create(
      home: (context) => const Scaffold(body: Text('CampusConnect home')),
    );
    addTearDown(router.dispose);
    router.go('/missing');

    await tester.pumpWidget(CampusConnectApp(router: router));
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.text('Go home'));
    await tester.pumpAndSettle();
    expect(find.text('CampusConnect home'), findsOneWidget);
  });
}
