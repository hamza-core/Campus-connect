import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/app_notification.dart';
import 'background_alerts.dart';

const _updatesChannel = AndroidNotificationChannel(
  'cc_updates',
  'Complaint updates',
  description: 'Status changes and replies on your complaints.',
  importance: Importance.high,
);

/// Android implementation: local notifications + a foreground service.
final class AndroidBackgroundAlerts implements BackgroundAlerts {
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> init({
    required void Function(String complaintId) onOpenComplaint,
  }) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) onOpenComplaint(id);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_updatesChannel);
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'cc_service',
        channelName: 'Background connection',
        channelDescription:
            'Keeps CampusConnect listening for complaint updates.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  @override
  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  @override
  Future<void> startKeepAlive() async {
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'CampusConnect',
      notificationText: 'Listening for complaint updates',
      callback: startKeepAliveCallback,
    );
  }

  @override
  Future<void> stopKeepAlive() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  @override
  Future<void> show(AppNotification notification) => _plugin.show(
    id: notification.id.hashCode & 0x7fffffff,
    title: 'CampusConnect',
    body: notification.message,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'cc_updates',
        'Complaint updates',
        channelDescription: 'Status changes and replies on your complaints.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    payload: notification.complaintId,
  );

  @override
  Future<String?> launchedFromComplaint() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }
}

/// The service only keeps the process alive; the live connection itself runs
/// in the app's main isolate.
@pragma('vm:entry-point')
void startKeepAliveCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

final class _KeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
