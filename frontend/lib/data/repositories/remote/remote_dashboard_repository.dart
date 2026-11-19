import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../domain/models/dashboard_stats.dart';
import '../../../domain/models/department_stat.dart';
import '../dashboard_repository.dart';

final class RemoteDashboardRepository implements DashboardRepository {
  const RemoteDashboardRepository(this._api);
  final ApiClient _api;

  @override
  Future<DashboardStats> summary({String? departmentId}) async {
    final response = await _api.request(
      'GET',
      ApiEndpoints.analyticsSummary,
      query: departmentId == null ? null : {'departmentId': departmentId},
    );
    return DashboardStats.fromJson(response['data'] as Map<String, Object?>);
  }

  @override
  Future<List<DepartmentStat>> byDepartment() async {
    final response = await _api.request(
      'GET',
      ApiEndpoints.analyticsByDepartment,
    );
    return List.unmodifiable(
      (response['data'] as List).cast<Map<String, Object?>>().map(
        DepartmentStat.fromJson,
      ),
    );
  }
}
