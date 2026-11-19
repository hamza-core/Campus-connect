final class TokenStore {
  String? _accessToken;
  void Function()? onExpired;

  String? get accessToken => _accessToken;

  void replace(String token) => _accessToken = token;

  void clear() => _accessToken = null;

  void clearIfCurrent(String token) {
    if (_accessToken == token) {
      clear();
      onExpired?.call();
    }
  }
}
