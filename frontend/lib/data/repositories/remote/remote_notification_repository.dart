import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../domain/models/app_notification.dart';
import '../notification_repository.dart';

final class RemoteNotificationRepository implements NotificationRepository {
  const RemoteNotificationRepository(this._api);
  final ApiClient _api;

  @override
  Future<NotificationPage> list() async {
    final response = await _api.request('GET', ApiEndpoints.notifications);
    return NotificationPage(
      items: List.unmodifiable(
        (response['data'] as List).cast<Map<String, Object?>>().map(
          AppNotification.fromJson,
        ),
      ),
      unreadCount: response['unreadCount'] as int? ?? 0,
    );
  }

  @override
  Future<void> markAllRead() async {
    await _api.request('POST', ApiEndpoints.notificationsReadAll);
  }
}
