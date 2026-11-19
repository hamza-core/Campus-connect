final class DashboardStats {
  factory DashboardStats.fromJson(Map<String, Object?> json) => DashboardStats(
    total: json['total'] as int,
    pending: json['pending'] as int,
    inProgress: json['inProgress'] as int,
    resolved: json['resolved'] as int,
    rejected: json['rejected'] as int,
    overdue: json['overdue'] as int,
  );

  Map<String, Object?> toJson() => {
    'total': total,
    'pending': pending,
    'inProgress': inProgress,
    'resolved': resolved,
    'rejected': rejected,
    'overdue': overdue,
  };

  DashboardStats copyWith({
    int? total,
    int? pending,
    int? inProgress,
    int? resolved,
    int? rejected,
    int? overdue,
  }) => DashboardStats(
    total: total ?? this.total,
    pending: pending ?? this.pending,
    inProgress: inProgress ?? this.inProgress,
    resolved: resolved ?? this.resolved,
    rejected: rejected ?? this.rejected,
    overdue: overdue ?? this.overdue,
  );

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
