import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../domain/models/dashboard_stats.dart';
import '../../../domain/models/department_stat.dart';
import '../../../domain/models/recurring_issue.dart';
import '../../../domain/models/status_stat.dart';
import '../../../domain/models/trend_point.dart';
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

  @override
  Future<List<StatusStat>> byStatus() async {
    final response = await _api.request('GET', ApiEndpoints.analyticsByStatus);
    return List.unmodifiable(
      (response['data'] as List).cast<Map<String, Object?>>().map(
        StatusStat.fromJson,
      ),
    );
  }

  @override
  Future<List<TrendPoint>> trend({int days = 14}) async {
    final response = await _api.request(
      'GET',
      ApiEndpoints.analyticsTrend,
      query: {'days': '$days'},
    );
    return List.unmodifiable(
      (response['data'] as List).cast<Map<String, Object?>>().map(
        TrendPoint.fromJson,
      ),
    );
  }

  @override
  Future<List<RecurringIssue>> recurring() async {
    final response = await _api.request('GET', ApiEndpoints.analyticsRecurring);
    return List.unmodifiable(
      (response['data'] as List).cast<Map<String, Object?>>().map(
        RecurringIssue.fromJson,
      ),
    );
  }
}
