import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/token_store.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/complaint_repository.dart';
import '../data/repositories/dashboard_repository.dart';
import '../data/repositories/mock/mock_auth_repository.dart';
import '../data/repositories/mock/mock_complaint_repository.dart';
import '../data/repositories/mock/mock_dashboard_repository.dart';
import '../data/repositories/remote/remote_auth_repository.dart';
import '../data/repositories/remote/remote_complaint_repository.dart';
import '../data/repositories/remote/remote_dashboard_repository.dart';

final class AppDependencies {
  factory AppDependencies.create(AppConfig config, {http.Client? client}) {
    if (config.useMock) {
      final auth = MockAuthRepository();
      final complaints = MockComplaintRepository(auth);
      return AppDependencies(
        config: config,
        auth: auth,
        complaints: complaints,
        dashboard: MockDashboardRepository(auth, complaints),
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
        auth: RemoteAuthRepository(api, tokens),
        complaints: RemoteComplaintRepository(api),
        dashboard: RemoteDashboardRepository(api),
      );
    } on ArgumentError {
      if (client == null) transport.close();
      rethrow;
    }
  }

  const AppDependencies({
    required this.config,
    required this.auth,
    required this.complaints,
    required this.dashboard,
  });

  final AppConfig config;
  final AuthRepository auth;
  final ComplaintRepository complaints;
  final DashboardRepository dashboard;
}
