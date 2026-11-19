import '../../../core/errors/app_exception.dart';
import '../../../domain/enums/complaint_status.dart';
import '../../../domain/enums/user_role.dart';
import '../../../domain/models/app_user.dart';
import '../../../domain/models/dashboard_stats.dart';
import '../../../domain/models/department_stat.dart';
import '../../../domain/models/status_stat.dart';
import '../../../domain/models/trend_point.dart';
import '../../mock_data/mock_seed.dart';
import '../dashboard_repository.dart';
import 'mock_auth_repository.dart';
import 'mock_complaint_repository.dart';

final class MockDashboardRepository implements DashboardRepository {
  const MockDashboardRepository(this._auth, this._complaints);
  final MockAuthRepository _auth;
  final MockComplaintRepository _complaints;

  AppUser get _admin {
    final user = _auth.requiredUser;
    if (user.role == UserRole.student) throw const ForbiddenException();
    return user;
  }

  @override
  Future<DashboardStats> summary({String? departmentId}) async {
    final items = _complaints
        .visibleTo(_admin, departmentId: departmentId)
        .toList();
    int count(ComplaintStatus status) =>
        items.where((item) => item.summary.status == status).length;
    return DashboardStats(
      total: items.length,
      pending: count(ComplaintStatus.pending),
      inProgress: count(ComplaintStatus.inProgress),
      resolved: count(ComplaintStatus.resolved),
      rejected: count(ComplaintStatus.rejected),
      overdue: items.where((item) => item.isOverdue).length,
    );
  }

  @override
  Future<List<StatusStat>> byStatus() async {
    final items = _complaints.visibleTo(_admin).toList();
    return [
      for (final status in ComplaintStatus.values)
        StatusStat(
          status: status,
          count: items.where((item) => item.summary.status == status).length,
        ),
    ];
  }

  @override
  Future<List<TrendPoint>> trend({int days = 14}) async {
    final items = _complaints.visibleTo(_admin).toList();
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: days - 1));
    return [
      for (var i = 0; i < days; i++)
        TrendPoint(
          date: start.add(Duration(days: i)),
          count: items.where((item) {
            final created = item.summary.createdAt.toLocal();
            final day = start.add(Duration(days: i));
            return created.year == day.year &&
                created.month == day.month &&
                created.day == day.day;
          }).length,
        ),
    ];
  }

  @override
  Future<List<DepartmentStat>> byDepartment() async {
    final user = _admin;
    final items = _complaints.visibleTo(user).toList();
    return [
      for (final department in MockSeed.departments.values)
        if (user.role == UserRole.superAdmin ||
            user.department?.id == department.id)
          DepartmentStat(
            department: department,
            count: items
                .where((item) => item.summary.department.id == department.id)
                .length,
          ),
    ];
  }
}
