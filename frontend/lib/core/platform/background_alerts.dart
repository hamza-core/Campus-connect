import '../../domain/models/app_notification.dart';

/// System-level alerts that work while the app is minimized: a foreground
/// service keeps the live connection alive, and local notifications pop up.
abstract interface class BackgroundAlerts {
  /// [onOpenComplaint] is called when the user taps a notification.
  Future<void> init({
    required void Function(String complaintId) onOpenComplaint,
  });

  /// Asks for the notification permission (Android 13+). Safe to repeat.
  Future<void> requestPermissions();

  Future<void> startKeepAlive();
  Future<void> stopKeepAlive();

  /// Shows a heads-up system notification for [notification].
  Future<void> show(AppNotification notification);

  /// The complaint id of the notification that launched the app, if any.
  Future<String?> launchedFromComplaint();
}

final class NoopBackgroundAlerts implements BackgroundAlerts {
  const NoopBackgroundAlerts();

  @override
  Future<void> init({
    required void Function(String complaintId) onOpenComplaint,
  }) async {}

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> startKeepAlive() async {}

  @override
  Future<void> stopKeepAlive() async {}

  @override
  Future<void> show(AppNotification notification) async {}

  @override
  Future<String?> launchedFromComplaint() async => null;
}
