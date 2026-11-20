import '../../../core/controllers/base_controller.dart';
import '../../../core/utils/session_cache.dart';
import '../../../domain/models/paged_result.dart';
import '../../../data/repositories/complaint_repository.dart';
import '../../../domain/enums/complaint_status.dart';
import '../../../domain/models/complaint_filter.dart';
import '../../../domain/models/complaint_summary.dart';
import '../../../domain/models/dashboard_stats.dart';

final class StudentDashboardController extends BaseController {
  StudentDashboardController(this._repository, [this._cache]);
  final ComplaintRepository _repository;
  final SessionCache? _cache;
  static const _key = 'student-dashboard';
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
    _cache?.write(_key, (stats!, recent));
  }

  /// First load of the screen: shows the last-known numbers at once (if any)
  /// and refreshes them quietly; only a first-ever visit shows a placeholder.
  Future<void> open() {
    final cached = _cache?.read<(DashboardStats, List<ComplaintSummary>)>(_key);
    if (cached == null) return load();
    showCached(() {
      stats = cached.$1;
      recent = cached.$2;
    });
    return refreshSilently();
  }

  Future<void> load() => run(_fetch, onSuccess: _apply);
}
