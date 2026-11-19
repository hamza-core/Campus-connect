import 'package:flutter_test/flutter_test.dart';
import 'package:project/data/repositories/complaint_repository.dart';
import 'package:project/domain/enums/complaint_category.dart';
import 'package:project/domain/enums/complaint_status.dart';
import 'package:project/domain/enums/priority.dart';
import 'package:project/domain/models/complaint.dart';
import 'package:project/domain/models/complaint_filter.dart';
import 'package:project/domain/models/complaint_summary.dart';
import 'package:project/domain/models/department.dart';
import 'package:project/domain/models/paged_result.dart';
import 'package:project/features/shared/controllers/complaint_list_controller.dart';

ComplaintSummary _c(
  String id, [
  ComplaintStatus status = ComplaintStatus.pending,
]) => ComplaintSummary(
  id: id,
  ticket: 'CC-$id',
  title: 'Complaint $id',
  category: ComplaintCategory.library,
  department: const Department(id: 'd', name: 'Library', slug: 'library'),
  status: status,
  createdAt: DateTime.utc(2026, 11, 19),
);

final class _FakeRepository implements ComplaintRepository {
  List<ComplaintSummary> items = [_c('2'), _c('1')];
  bool fail = false;
  int calls = 0;

  @override
  Future<PagedResult<ComplaintSummary>> list({
    ComplaintFilter filter = const ComplaintFilter(),
    int page = 1,
    int pageSize = 20,
  }) async {
    calls++;
    if (fail) throw Exception('offline');
    return PagedResult(
      items: items,
      page: 1,
      pageSize: 20,
      total: items.length,
    );
  }

  @override
  Future<Complaint> detail(String id) => throw UnimplementedError();
  @override
  Future<void> addRemark(String id, String body) => throw UnimplementedError();
  @override
  Future<Complaint> submit({
    required ComplaintCategory category,
    required String title,
    required String description,
    String? subIssue,
    Priority priority = Priority.medium,
    String? location,
    bool anonymousToStaff = false,
  }) => throw UnimplementedError();
  @override
  Future<Complaint> submitFeedback({
    required String id,
    required int rating,
    String? comment,
  }) => throw UnimplementedError();
  @override
  Future<String> exportCsv({
    ComplaintFilter filter = const ComplaintFilter(),
  }) => throw UnimplementedError();
  @override
  Future<Complaint> updateStatus({
    required String id,
    required String rowVersion,
    required ComplaintStatus status,
    String? remark,
  }) => throw UnimplementedError();
}

void main() {
  test('A new complaint appears without a manual refresh', () async {
    final repository = _FakeRepository();
    final controller = ComplaintListController(repository);
    await controller.refresh();
    expect(controller.items.map((c) => c.id), ['2', '1']);

    repository.items = [_c('3'), _c('2'), _c('1')];
    var notified = 0;
    controller.addListener(() => notified++);
    await controller.silentRefresh();
    expect(controller.items.map((c) => c.id), ['3', '2', '1']);
    expect(notified, 1);
  });

  test('A status change shows up quietly', () async {
    final repository = _FakeRepository();
    final controller = ComplaintListController(repository);
    await controller.refresh();
    repository.items = [_c('2', ComplaintStatus.resolved), _c('1')];
    await controller.silentRefresh();
    expect(controller.items.first.status, ComplaintStatus.resolved);
  });

  test('No change means no rebuild and no loading state', () async {
    final repository = _FakeRepository();
    final controller = ComplaintListController(repository);
    await controller.refresh();
    var notified = 0;
    controller.addListener(() => notified++);
    await controller.silentRefresh();
    expect(notified, 0);
    expect(controller.items.length, 2);
  });

  test('A failed quiet refresh keeps the list and stays silent', () async {
    final repository = _FakeRepository();
    final controller = ComplaintListController(repository);
    await controller.refresh();
    repository.fail = true;
    await controller.silentRefresh();
    expect(controller.items.length, 2);
    expect(controller.errorMessage, isNull);
  });
}
