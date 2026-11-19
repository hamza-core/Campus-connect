import '../../../core/controllers/base_controller.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../domain/models/dashboard_stats.dart';

final class AdminDashboardController extends BaseController {
  AdminDashboardController(this._repository);
  final DashboardRepository _repository;
  DashboardStats? stats;

  Future<void> load() =>
      run(_repository.summary, onSuccess: (value) => stats = value);
}
