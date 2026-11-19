import '../enums/complaint_status.dart';

final class StatusStat {
  factory StatusStat.fromJson(Map<String, Object?> json) => StatusStat(
    status: ComplaintStatus.fromApiValue(json['status'] as String),
    count: json['count'] as int,
  );

  const StatusStat({required this.status, required this.count});

  final ComplaintStatus status;
  final int count;
}
