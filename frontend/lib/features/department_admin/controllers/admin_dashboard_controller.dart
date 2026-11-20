import '../../../core/controllers/base_controller.dart';
import '../../../core/utils/session_cache.dart';
import '../../../data/repositories/dashboard_repository.dart';
import '../../../domain/models/dashboard_stats.dart';

final class AdminDashboardController extends BaseController {
  AdminDashboardController(this._repository, [this._cache, this._scope = '']);
  final DashboardRepository _repository;
  final SessionCache? _cache;
  final String _scope;
  DashboardStats? stats;

  Object get _key => ('admin-stats', _scope);

  /// Refreshes the counts without flashing the loading placeholder.
  Future<void> refreshSilently() async {
    try {
      stats = await _repository.summary();
      _cache?.write(_key, stats);
      safeNotify();
    } on Object {
      // Keep showing the last known numbers.
    }
  }

  /// First load: last-known numbers at once, refreshed quietly.
  Future<void> open() {
    final cached = _cache?.read<DashboardStats>(_key);
    if (cached == null) return load();
    showCached(() => stats = cached);
    return refreshSilently();
  }

  Future<void> load() => run(
    _repository.summary,
    onSuccess: (value) {
      stats = value;
      _cache?.write(_key, value);
    },
  );
}
