import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/utils/session_cache.dart';
import '../core/network/token_store.dart';
import '../core/storage/secure_token_storage.dart';
import '../data/repositories/assist_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/mock/mock_chat_repository.dart';
import '../data/repositories/remote/remote_chat_repository.dart';
import '../data/repositories/mock/mock_assist_repository.dart';
import '../data/repositories/remote/remote_assist_repository.dart';
import '../data/repositories/complaint_repository.dart';
import '../data/realtime/notification_realtime.dart';
import '../data/realtime/signalr_notification_realtime.dart';
import '../data/repositories/dashboard_repository.dart';
import '../data/repositories/mock/mock_auth_repository.dart';
import '../data/repositories/mock/mock_complaint_repository.dart';
import '../data/repositories/mock/mock_dashboard_repository.dart';
import '../data/repositories/mock/mock_notification_repository.dart';
import '../data/repositories/remote/remote_auth_repository.dart';
import '../data/repositories/remote/remote_complaint_repository.dart';
import '../data/repositories/remote/remote_dashboard_repository.dart';
import '../data/repositories/remote/remote_notification_repository.dart';
import '../features/notifications/controllers/notification_controller.dart';

final class AppDependencies {
  factory AppDependencies.create(AppConfig config, {http.Client? client}) {
    if (config.useMock) {
      final auth = MockAuthRepository();
      final complaints = MockComplaintRepository(auth);
      return AppDependencies(
        config: config,
        cache: SessionCache(),
        auth: auth,
        complaints: complaints,
        dashboard: MockDashboardRepository(auth, complaints),
        assist: const MockAssistRepository(),
        chat: const MockChatRepository(),
        notifications: NotificationController(
          const MockNotificationRepository(),
          const NoopNotificationRealtime(),
        ),
      );
    }
    final baseUrl = Uri.parse(config.apiBaseUrl);
    final transport = client ?? http.Client();
    final tokens = TokenStore();
    try {
      final api = ApiClient(
        baseUrl: baseUrl,
        client: transport,
        tokens: tokens,
      );
      return AppDependencies(
        config: config,
        cache: SessionCache(),
        auth: RemoteAuthRepository(api, tokens, const SecureTokenStorage()),
        complaints: RemoteComplaintRepository(api),
        dashboard: RemoteDashboardRepository(api),
        assist: RemoteAssistRepository(api),
        chat: RemoteChatRepository(api),
        notifications: NotificationController(
          RemoteNotificationRepository(api),
          SignalRNotificationRealtime(
            hubUrl: Uri(
              scheme: baseUrl.scheme,
              host: baseUrl.host,
              port: baseUrl.hasPort ? baseUrl.port : null,
              path: '/hubs/notifications',
            ),
            accessToken: () => tokens.accessToken,
          ),
        ),
        tokens: tokens,
      );
    } on ArgumentError {
      if (client == null) transport.close();
      rethrow;
    }
  }

  const AppDependencies({
    required this.config,
    required this.cache,
    required this.auth,
    required this.complaints,
    required this.dashboard,
    required this.assist,
    required this.chat,
    required this.notifications,
    this.tokens,
  });

  final AppConfig config;
  final AuthRepository auth;
  final SessionCache cache;
  final ComplaintRepository complaints;
  final DashboardRepository dashboard;
  final AssistRepository assist;
  final ChatRepository chat;
  final NotificationController notifications;
  final TokenStore? tokens;
}
