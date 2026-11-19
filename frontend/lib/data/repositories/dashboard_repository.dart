import '../../domain/models/dashboard_stats.dart';
import '../../domain/models/department_stat.dart';

abstract interface class DashboardRepository {
  Future<DashboardStats> summary({String? departmentId});
  Future<List<DepartmentStat>> byDepartment();
}
