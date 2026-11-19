import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class SecureTokenStorage {
  const SecureTokenStorage({this._storage = const FlutterSecureStorage()});

  static const _key = 'campusconnect.refresh_token';
  final FlutterSecureStorage _storage;

  Future<String?> readRefreshToken() => _storage.read(key: _key);
  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _key, value: token);
  Future<void> clearRefreshToken() => _storage.delete(key: _key);
}
