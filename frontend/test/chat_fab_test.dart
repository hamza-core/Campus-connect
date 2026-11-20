import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/features/assistant/widgets/chat_fab.dart';

Widget _app(VoidCallback onTap) => MaterialApp(
  home: Scaffold(
    body: SizedBox.expand(child: DraggableChatFab(onPressed: onTap)),
  ),
);

void main() {
  testWidgets('tap opens the chat', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(() => taps++));
    await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded));
    expect(taps, 1);
  });

  testWidgets('can be dragged to the left and snaps to the edge', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_app(() => taps++));
    final finder = find.byIcon(Icons.chat_bubble_outline_rounded);
    final before = tester.getCenter(finder);
    await tester.drag(finder, Offset(-before.dx + 100, -150));
    await tester.pumpAndSettle();
    final after = tester.getCenter(finder);
    expect(after.dx, lessThan(before.dx / 2));
    expect(after.dx, closeTo(12 + 28, 1)); // snapped to the left margin
    expect(after.dy, lessThan(before.dy));
    expect(taps, 0, reason: 'a drag must not count as a tap');
  });

  testWidgets('stays on screen when dragged far outside', (tester) async {
    await tester.pumpWidget(_app(() {}));
    final finder = find.byIcon(Icons.chat_bubble_outline_rounded);
    await tester.drag(finder, const Offset(2000, 2000));
    await tester.pumpAndSettle();
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final center = tester.getCenter(finder);
    expect(center.dx, lessThan(size.width));
    expect(center.dy, lessThan(size.height));
  });
}
