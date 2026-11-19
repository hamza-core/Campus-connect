import '../../../core/controllers/base_controller.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../domain/models/dashboard_stats.dart';

final class AdminDashboardController extends BaseController {
  AdminDashboardController(this._repository);
  final DashboardRepository _repository;
  DashboardStats? stats;

  /// Refreshes the counts without flashing the loading placeholder.
  Future<void> refreshSilently() async {
    try {
      stats = await _repository.summary();
      safeNotify();
    } on Object {
      // Keep showing the last known numbers.
    }
  }

  Future<void> load() =>
      run(_repository.summary, onSuccess: (value) => stats = value);
}
