import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/features/auth/widgets/auth_heading.dart';

void main() {
  testWidgets('Password checklist ticks rules as the user types', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PasswordChecklist(controller: controller)),
      ),
    );
    expect(find.byIcon(Icons.check_circle), findsNothing);

    controller.text = 'abcdefgh';
    await tester.pump();
    expect(
      find.byIcon(Icons.check_circle),
      findsNWidgets(2),
    ); // length + letter

    controller.text = 'abcdefg1';
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));

    controller.text = 'a1';
    await tester.pump();
    expect(
      find.byIcon(Icons.check_circle),
      findsNWidgets(2),
    ); // letter + number
  });

  testWidgets('Auth toggle reports the tab that was tapped', (tester) async {
    bool? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuthToggle(registration: false, onChanged: (v) => picked = v),
        ),
      ),
    );
    await tester.tap(find.text('Sign up'));
    expect(picked, isTrue);
    await tester.tap(find.text('Log in'));
    expect(picked, isFalse);
  });
}
