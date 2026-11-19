import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import '../../domain/models/app_notification.dart';
import 'notification_realtime.dart';

/// SignalR client for the API's /hubs/notifications hub. The access token is
/// sent as the `access_token` query value on the WebSocket (the API reads it).
final class SignalRNotificationRealtime implements NotificationRealtime {
  SignalRNotificationRealtime({
    required this.hubUrl,
    required this._accessToken,
  });

  final Uri hubUrl;
  final String? Function() _accessToken;
  final _events = StreamController<AppNotification>.broadcast();
  HubConnection? _connection;

  @override
  Stream<AppNotification> get events => _events.stream;

  @override
  Future<void> start() async {
    if (_connection != null) return;
    final connection = HubConnectionBuilder()
        .withUrl(
          hubUrl.toString(),
          options: HttpConnectionOptions(
            accessTokenFactory: () async => _accessToken() ?? '',
            transport: HttpTransportType.WebSockets,
          ),
        )
        .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 20000])
        .build();
    connection.on('notification', (arguments) {
      final payload = arguments?.firstOrNull;
      if (payload is Map) {
        try {
          _events.add(
            AppNotification.fromJson(Map<String, Object?>.from(payload)),
          );
        } on Object {
          // Ignore a malformed live event; the REST list will catch up.
        }
      }
    });
    try {
      await connection.start();
      _connection = connection;
    } on Object {
      await connection.stop();
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    final connection = _connection;
    _connection = null;
    await connection?.stop();
  }
}
