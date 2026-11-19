import '../enums/complaint_status.dart';
import '../enums/user_role.dart';

final class TimelineEntry {
  const TimelineEntry({
    required this.id,
    required this.type,
    required this.createdAt,
    this.actorName,
    this.actorRole,
    this.fromStatus,
    this.toStatus,
    this.body,
  });

  final String id;
  final String type;
  final DateTime createdAt;
  final String? actorName;
  final UserRole? actorRole;
  final ComplaintStatus? fromStatus;
  final ComplaintStatus? toStatus;
  final String? body;
}
