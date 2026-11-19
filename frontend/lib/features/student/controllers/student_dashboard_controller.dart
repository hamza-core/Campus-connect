import '../../../core/controllers/base_controller.dart';
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

  Future<void> load() => run(
    () async {
      return Future.wait([
        _repository.list(pageSize: 3),
        for (final status in ComplaintStatus.values)
          _repository.list(
            pageSize: 1,
            filter: ComplaintFilter(status: status),
          ),
      ]);
    },
    onSuccess: (pages) {
      recent = pages.first.items;
      stats = DashboardStats(
        total: pages[0].total,
        pending: pages[1].total,
        inProgress: pages[2].total,
        resolved: pages[3].total,
        rejected: pages[4].total,
        overdue: 0,
      );
    },
  );
}
