import 'package:flutter_test/flutter_test.dart';
import 'package:project/core/config/app_config.dart';
import 'package:project/core/errors/app_exception.dart';
import 'package:project/di/app_dependencies.dart';
import 'package:project/domain/enums/complaint_category.dart';
import 'package:project/domain/enums/complaint_status.dart';
import 'package:project/domain/enums/priority.dart';
import 'package:project/domain/models/complaint_filter.dart';

AppDependencies _mock() =>
    AppDependencies.create(const AppConfig(apiBaseUrl: '', useMock: true));

Future<void> _student(AppDependencies d) =>
    d.auth.login(email: 'ali@student.com', password: 'Ali@1234');
Future<void> _library(AppDependencies d) =>
    d.auth.login(email: 'library.admin@campus.com', password: 'Admin@1234');
Future<void> _super(AppDependencies d) =>
    d.auth.login(email: 'super.admin@campus.com', password: 'Admin@1234');

void main() {
  test(
    'Submit keeps sub-issue, priority and location; list filters by priority',
    () async {
      final d = _mock();
      await _student(d);
      final created = await d.complaints.submit(
        category: ComplaintCategory.library,
        title: 'Seats are broken',
        description: 'Several seats in the reading hall are broken.',
        subIssue: ComplaintCategory.library.subIssues.last,
        priority: Priority.high,
        location: '  Reading hall  ',
      );
      expect(created.summary.priority, Priority.high);
      expect(created.subIssue, ComplaintCategory.library.subIssues.last);
      expect(created.location, 'Reading hall');
      expect(created.dueAt, isNotNull);

      final high = await d.complaints.list(
        filter: const ComplaintFilter(priority: Priority.high),
      );
      expect(high.items.map((c) => c.id), contains(created.summary.id));
      expect(high.items.every((c) => c.priority == Priority.high), isTrue);
    },
  );

  test('Anonymous complaints hide the author name', () async {
    final d = _mock();
    await _student(d);
    final created = await d.complaints.submit(
      category: ComplaintCategory.cafeteria,
      title: 'Prices went up again',
      description: 'The prices went up without any notice.',
      anonymousToStaff: true,
    );
    expect(created.authorName, isNull);
  });

  test('A student can rate a resolved complaint exactly once', () async {
    final d = _mock();
    await _student(d);
    final created = await d.complaints.submit(
      category: ComplaintCategory.library,
      title: 'Lights are off',
      description: 'The reading room lights do not turn on.',
    );
    // Not resolved yet.
    await expectLater(
      d.complaints.submitFeedback(id: created.summary.id, rating: 5),
      throwsA(isA<ConflictException>()),
    );

    await _library(d);
    final open = await d.complaints.detail(created.summary.id);
    final started = await d.complaints.updateStatus(
      id: open.summary.id,
      rowVersion: open.rowVersion,
      status: ComplaintStatus.inProgress,
    );
    await d.complaints.updateStatus(
      id: started.summary.id,
      rowVersion: started.rowVersion,
      status: ComplaintStatus.resolved,
      remark: 'Fixed',
    );

    await _student(d);
    await expectLater(
      d.complaints.submitFeedback(id: created.summary.id, rating: 9),
      throwsA(isA<ValidationException>()),
    );
    final rated = await d.complaints.submitFeedback(
      id: created.summary.id,
      rating: 4,
      comment: ' Quick fix ',
    );
    expect(rated.feedback?.rating, 4);
    expect(rated.feedback?.comment, 'Quick fix');
    await expectLater(
      d.complaints.submitFeedback(id: created.summary.id, rating: 5),
      throwsA(isA<ConflictException>()),
    );
  });

  test('CSV export is for staff only and honours the filter', () async {
    final d = _mock();
    await _student(d);
    await expectLater(
      d.complaints.exportCsv(),
      throwsA(isA<ForbiddenException>()),
    );
    await _super(d);
    final csv = await d.complaints.exportCsv(
      filter: const ComplaintFilter(status: ComplaintStatus.resolved),
    );
    final lines = csv.trim().split('\r\n');
    expect(lines.first, startsWith('ticket,title,category'));
    expect(lines.length, greaterThan(1));
    expect(lines.skip(1).every((l) => l.contains('RESOLVED')), isTrue);
  });

  test('Recurring issues and averages are available to admins only', () async {
    final d = _mock();
    await _student(d);
    await expectLater(
      d.dashboard.recurring(),
      throwsA(isA<ForbiddenException>()),
    );
    await _super(d);
    final recurring = await d.dashboard.recurring();
    expect(recurring, isNotEmpty);
    expect(recurring.first.count, greaterThanOrEqualTo(recurring.last.count));
  });
}
