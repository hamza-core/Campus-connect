import 'package:flutter_test/flutter_test.dart';
import 'package:project/core/config/app_config.dart';
import 'package:project/core/errors/app_exception.dart';
import 'package:project/di/app_dependencies.dart';
import 'package:project/domain/enums/complaint_status.dart';
import 'package:project/domain/models/complaint_filter.dart';

void main() {
  test(
    'Super admin has global counts and read-only complaint access',
    () async {
      final dependencies = AppDependencies.create(
        const AppConfig(apiBaseUrl: '', useMock: true),
      );
      await dependencies.auth.login(
        email: 'super.admin@campus.com',
        password: 'Admin@1234',
      );
      final totals = await dependencies.dashboard.summary();
      final groups = await dependencies.dashboard.byDepartment();
      expect(groups, hasLength(4));
      expect(
        groups.fold<int>(0, (count, group) => count + group.count),
        totals.total,
      );
      final rows = await dependencies.complaints.list(
        filter: const ComplaintFilter(departmentId: 'library'),
      );
      expect(
        rows.total,
        groups.singleWhere((group) => group.department.id == 'library').count,
      );
      final complaint = await dependencies.complaints.detail('demo-1');
      expect(complaint.allowedTransitions, isEmpty);
      await expectLater(
        dependencies.complaints.updateStatus(
          id: complaint.summary.id,
          rowVersion: complaint.rowVersion,
          status: ComplaintStatus.inProgress,
        ),
        throwsA(isA<ForbiddenException>()),
      );
    },
  );
}
