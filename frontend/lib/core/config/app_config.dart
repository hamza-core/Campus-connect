final class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.useMock});

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL'),
    useMock: bool.fromEnvironment('USE_MOCK'),
  );

  final String apiBaseUrl;
  final bool useMock;
}
