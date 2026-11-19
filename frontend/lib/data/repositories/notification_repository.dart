import '../../domain/models/app_notification.dart';

abstract interface class NotificationRepository {
  Future<NotificationPage> list();
  Future<void> markAllRead();
}
