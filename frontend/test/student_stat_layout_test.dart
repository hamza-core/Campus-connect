import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/features/student/widgets/student_stat.dart';

void main() {
  testWidgets('Pending, In progress and Resolved cards are the same size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(
                    child: StudentStat(
                      label: 'Pending',
                      value: 4,
                      image: 'pending.jpg',
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: StudentStat(
                      label: 'In progress',
                      value: 12,
                      image: 'in-progress.jpg',
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: StudentStat(
                      label: 'Resolved',
                      value: 106,
                      image: 'resolved.jpg',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sizes = [
      for (final label in ['Pending', 'In progress', 'Resolved'])
        tester.getSize(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(DecoratedBox),
              )
              .first,
        ),
    ];
    expect(sizes[1], sizes[0]);
    expect(sizes[2], sizes[0]);
  });
}
