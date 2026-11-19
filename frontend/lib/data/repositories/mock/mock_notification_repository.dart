import '../../../domain/models/app_notification.dart';
import '../notification_repository.dart';

final class MockNotificationRepository implements NotificationRepository {
  const MockNotificationRepository();

  @override
  Future<NotificationPage> list() async =>
      const NotificationPage(items: [], unreadCount: 0);

  @override
  Future<void> markAllRead() async {}
}
