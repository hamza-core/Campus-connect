import '../core/config/app_config.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/complaint_repository.dart';
import '../data/repositories/dashboard_repository.dart';

final class AppDependencies {
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
