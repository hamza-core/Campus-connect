import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/core/widgets/app_button.dart';
import 'package:project/data/repositories/mock/mock_auth_repository.dart';
import 'package:project/data/repositories/mock/mock_complaint_repository.dart';
import 'package:project/domain/models/complaint_filter.dart';
import 'package:project/domain/models/timeline_entry.dart';
import 'package:project/features/shared/controllers/complaint_list_controller.dart';
import 'package:project/features/shared/widgets/complaint_filters.dart';
import 'package:project/features/shared/widgets/complaint_timeline.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Widget _filters({required bool category, bool department = false}) {
  final auth = MockAuthRepository();
  return _wrap(
    ComplaintFilters(
      controller: ComplaintListController(MockComplaintRepository(auth)),
      departments: const [],
      showDepartment: department,
      showCategory: category,
    ),
  );
}

void main() {
  test('year filter round-trips and clears', () {
    const filter = ComplaintFilter(year: 2026);
    expect(ComplaintFilter.fromJson(filter.toJson()).year, 2026);
    expect(filter.copyWith(year: () => null).year, isNull);
    expect(filter.copyWith(search: 'x').year, 2026);
  });

  testWidgets('department admins do not get a category filter', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_filters(category: false));
    expect(find.text('Category'), findsNothing);
    expect(find.text('Department'), findsNothing);
    expect(find.text('Priority'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('Overdue only'), findsOneWidget);
  });

  testWidgets('super admins keep category and department filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_filters(category: true, department: true));
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Department'), findsOneWidget);
  });

  testWidgets('destructive and success buttons use distinct colours', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        Column(
          children: [
            AppButton(
              label: 'Reject',
              tone: AppButtonTone.destructive,
              onPressed: () {},
            ),
            AppButton(
              label: 'Resolve',
              tone: AppButtonTone.success,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    Color? fill(String label) => tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, label))
        .style
        ?.backgroundColor
        ?.resolve({});
    expect(fill('Reject'), const Color(0xFFB91C1C));
    expect(fill('Resolve'), const Color(0xFF15803D));
  });

  testWidgets('timeline shows who acted and when', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ComplaintTimeline(
          departmentName: 'Library',
          entries: [
            TimelineEntry.fromJson({
              'id': '1',
              'type': 'CREATED',
              'createdAt': '2026-11-01T09:00:00Z',
              'toStatus': 'PENDING',
              'actor': {'name': 'Ali', 'role': 'STUDENT'},
            }),
            TimelineEntry.fromJson({
              'id': '2',
              'type': 'STATUS_CHANGED',
              'createdAt': '2026-11-02T10:30:00Z',
              'fromStatus': 'PENDING',
              'toStatus': 'REJECTED',
              'body': 'Duplicate',
              'actor': {'name': 'Library Admin', 'role': 'DEPT_ADMIN'},
            }),
          ],
        ),
      ),
    );
    expect(find.text('Ali · Student'), findsOneWidget);
    expect(find.text('Library Admin · Department admin'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
  });
}
