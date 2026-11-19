import '../enums/complaint_status.dart';
import '../enums/user_role.dart';

final class TimelineEntry {
  factory TimelineEntry.fromJson(Map<String, Object?> json) => TimelineEntry(
    id: json['id'] as String,
    type: json['type'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    actorName: (json['actor'] as Map<String, Object?>?)?['name'] as String?,
    actorRole: (json['actor'] as Map<String, Object?>?)?['role'] == null
        ? null
        : UserRole.fromApiValue(
            (json['actor'] as Map<String, Object?>?)?['role'] as String,
          ),
    fromStatus: json['fromStatus'] == null
        ? null
        : ComplaintStatus.fromApiValue(json['fromStatus'] as String),
    toStatus: json['toStatus'] == null
        ? null
        : ComplaintStatus.fromApiValue(json['toStatus'] as String),
    body: json['body'] as String?,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'fromStatus': fromStatus?.apiValue,
    'toStatus': toStatus?.apiValue,
    'body': body,
    if (actorName != null && actorRole != null)
      'actor': {'name': actorName, 'role': actorRole?.apiValue},
  };

  TimelineEntry copyWith({
    String? id,
    String? type,
    DateTime? createdAt,
    String? Function()? actorName,
    UserRole? Function()? actorRole,
    ComplaintStatus? Function()? fromStatus,
    ComplaintStatus? Function()? toStatus,
    String? Function()? body,
  }) => TimelineEntry(
    id: id ?? this.id,
    type: type ?? this.type,
    createdAt: createdAt ?? this.createdAt,
    actorName: actorName == null ? this.actorName : actorName(),
    actorRole: actorRole == null ? this.actorRole : actorRole(),
    fromStatus: fromStatus == null ? this.fromStatus : fromStatus(),
    toStatus: toStatus == null ? this.toStatus : toStatus(),
    body: body == null ? this.body : body(),
  );

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
