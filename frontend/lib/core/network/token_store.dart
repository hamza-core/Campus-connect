final class TokenStore {
  String? _accessToken;

  String? get accessToken => _accessToken;

  void replace(String token) => _accessToken = token;

  void clear() => _accessToken = null;

  void clearIfCurrent(String token) {
    if (_accessToken == token) clear();
  }
}
