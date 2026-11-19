import '../../domain/models/dashboard_stats.dart';
import '../../domain/models/department_stat.dart';
import '../../domain/models/status_stat.dart';
import '../../domain/models/trend_point.dart';

abstract interface class DashboardRepository {
  Future<DashboardStats> summary({String? departmentId});
  Future<List<DepartmentStat>> byDepartment();
  Future<List<StatusStat>> byStatus();
  Future<List<TrendPoint>> trend({int days = 14});
}
