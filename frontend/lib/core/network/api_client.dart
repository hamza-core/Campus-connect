import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/app_exception.dart';
import 'token_store.dart';

final class ApiClient {
  ApiClient({
    required Uri baseUrl,
    required this._client,
    required this._tokens,
    this.timeout = const Duration(seconds: 15),
  }) : _baseUrl = _normalizeBaseUrl(baseUrl);

  final Uri _baseUrl;
  final http.Client _client;
  final TokenStore _tokens;
  final Duration timeout;

  static Uri _normalizeBaseUrl(Uri baseUrl) {
    if (!baseUrl.hasAuthority ||
        !const {'http', 'https'}.contains(baseUrl.scheme) ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'Expected an HTTP(S) API base URL.',
      );
    }
    final path = baseUrl.path.endsWith('/') ? baseUrl.path : '${baseUrl.path}/';
    return baseUrl.replace(path: path);
  }

  Future<Map<String, Object?>> request(
    String method,
    String endpoint, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    bool authenticated = true,
  }) async {
    final relative = Uri.parse(endpoint);
    if (relative.hasScheme ||
        relative.hasAuthority ||
        relative.hasQuery ||
        relative.hasFragment ||
        endpoint.startsWith('/') ||
        relative.pathSegments.any(
          (segment) => segment == '..' || segment == '.',
        )) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'Expected a relative API path.',
      );
    }
    final target = _baseUrl
        .resolveUri(relative)
        .replace(queryParameters: query);
    final token = authenticated ? _tokens.accessToken : null;
    final request = http.Request(method, target)
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
    } on http.ClientException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('The request timed out. Try again.');
    }

    final status = response.statusCode;
    if (status == 401 && token != null) _tokens.clearIfCurrent(token);
    if (status == 204) return const {};
    final payload = _decode(response.bodyBytes);
    if (status >= 200 && status < 300) {
      if (payload == null) {
        throw const ServerException('The server returned an invalid response.');
      }
      return payload;
    }
    final error = payload?['error'];
    final message = error is Map<String, Object?> ? error['message'] : null;
    final detail = message is String && message.trim().isNotEmpty
        ? message
        : null;
    throw switch (status) {
      401 => UnauthorizedException(detail ?? 'Please sign in again.'),
      403 => const ForbiddenException(),
      404 => const NotFoundException(),
      409 => ConflictException(
        detail ?? 'The complaint changed. Reload and try again.',
      ),
      400 ||
      422 => ValidationException(detail ?? 'Check the submitted values.'),
      429 => const RateLimitException(),
      _ => const ServerException(),
    };
  }

  Map<String, Object?>? _decode(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
