import 'package:flutter_test/flutter_test.dart';
import 'package:project/core/config/app_config.dart';
import 'package:project/di/app_dependencies.dart';
import 'package:project/domain/enums/complaint_status.dart';
import 'package:project/features/shared/controllers/complaint_list_controller.dart';

void main() {
  test('Department tabs show only the relevant status group', () async {
    final dependencies = AppDependencies.create(
      const AppConfig(apiBaseUrl: '', useMock: true),
    );
    await dependencies.auth.login(
      email: 'labit.admin@campus.com',
      password: 'Admin@1234',
    );
    final controller = ComplaintListController(
      dependencies.complaints,
      department: true,
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.items, isNotEmpty);
    expect(
      controller.items.every(
        (item) =>
            item.status == ComplaintStatus.pending ||
            item.status == ComplaintStatus.inProgress,
      ),
      isTrue,
    );
    await controller.setDepartmentHistory(true);
    expect(
      controller.items.every(
        (item) =>
            item.status == ComplaintStatus.resolved ||
            item.status == ComplaintStatus.rejected,
      ),
      isTrue,
    );
  });

  test(
    'Posting a department remark updates the timeline and row version',
    () async {
      final dependencies = AppDependencies.create(
        const AppConfig(apiBaseUrl: '', useMock: true),
      );
      await dependencies.auth.login(
        email: 'library.admin@campus.com',
        password: 'Admin@1234',
      );
      final before = await dependencies.complaints.detail('demo-2');
      await dependencies.complaints.addRemark(
        'demo-2',
        'Library extended exam hours.',
      );
      final after = await dependencies.complaints.detail('demo-2');
      expect(after.timeline.last.body, 'Library extended exam hours.');
      expect(after.rowVersion, isNot(before.rowVersion));
    },
  );
}
