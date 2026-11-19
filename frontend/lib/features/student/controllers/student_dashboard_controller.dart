import '../../../core/controllers/base_controller.dart';
import '../../../domain/models/paged_result.dart';
import '../../../data/repositories/complaint_repository.dart';
import '../../../domain/enums/complaint_status.dart';
import '../../../domain/models/complaint_filter.dart';
import '../../../domain/models/complaint_summary.dart';
import '../../../domain/models/dashboard_stats.dart';

final class StudentDashboardController extends BaseController {
  StudentDashboardController(this._repository);
  final ComplaintRepository _repository;
  DashboardStats? stats;
  List<ComplaintSummary> recent = const [];

  /// Refreshes the numbers and recent list without a loading placeholder.
  Future<void> refreshSilently() async {
    try {
      final pages = await _fetch();
      _apply(pages);
      safeNotify();
    } on Object {
      // Keep showing the last known data.
    }
  }

  Future<List<PagedResult<ComplaintSummary>>> _fetch() => Future.wait([
    _repository.list(pageSize: 3),
    for (final status in ComplaintStatus.values)
      _repository.list(pageSize: 1, filter: ComplaintFilter(status: status)),
  ]);

  void _apply(List<PagedResult<ComplaintSummary>> pages) {
    recent = pages.first.items;
    stats = DashboardStats(
      total: pages[0].total,
      pending: pages[1].total,
      inProgress: pages[2].total,
      resolved: pages[3].total,
      rejected: pages[4].total,
      overdue: 0,
    );
  }

  Future<void> load() => run(_fetch, onSuccess: _apply);
}
