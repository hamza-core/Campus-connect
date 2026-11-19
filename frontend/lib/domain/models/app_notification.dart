final class AppNotification {
  factory AppNotification.fromJson(Map<String, Object?> json) {
    Object? pick(String camel) =>
        json[camel] ?? json['${camel[0].toUpperCase()}${camel.substring(1)}'];
    return AppNotification(
      id: pick('id') as String,
      message: pick('message') as String,
      complaintId: pick('complaintId') as String,
      read: pick('read') as bool? ?? false,
      createdAt: DateTime.parse(pick('createdAt') as String),
    );
  }

  const AppNotification({
    required this.id,
    required this.message,
    required this.complaintId,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String message;
  final String complaintId;
  final bool read;
  final DateTime createdAt;

  AppNotification asRead() => AppNotification(
    id: id,
    message: message,
    complaintId: complaintId,
    read: true,
    createdAt: createdAt,
  );
}

final class NotificationPage {
  const NotificationPage({required this.items, required this.unreadCount});
  final List<AppNotification> items;
  final int unreadCount;
}
