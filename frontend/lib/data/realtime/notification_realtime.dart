import '../../domain/models/app_notification.dart';

/// Live delivery of new notifications (the REST list stays authoritative).
abstract interface class NotificationRealtime {
  Stream<AppNotification> get events;
  Future<void> start();
  Future<void> stop();
}

final class NoopNotificationRealtime implements NotificationRealtime {
  const NoopNotificationRealtime();

  @override
  Stream<AppNotification> get events => const Stream.empty();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
