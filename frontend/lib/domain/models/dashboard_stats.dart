final class DashboardStats {
  const DashboardStats({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.resolved,
    required this.rejected,
    required this.overdue,
  });

  final int total;
  final int pending;
  final int inProgress;
  final int resolved;
  final int rejected;
  final int overdue;
}
