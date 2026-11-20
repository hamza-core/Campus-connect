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
    Duration? timeout,
  }) async {
    final response = await _send(
      method,
      endpoint,
      query: query,
      body: body,
      authenticated: authenticated,
      timeout: timeout,
    );
    final status = response.statusCode;
    if (status == 204) return const {};
    final payload = _decode(response.bodyBytes);
    if (status >= 200 && status < 300) {
      if (payload == null) {
        throw const ServerException('The server returned an invalid response.');
      }
      return payload;
    }
    throw _errorFor(status, payload);
  }

  /// Authenticated download of a binary API resource, e.g. `/api/v1/uploads/<id>`.
  Future<List<int>> download(String apiPath) async {
    final prefix = _baseUrl.path.endsWith('/')
        ? _baseUrl.path
        : '${_baseUrl.path}/';
    if (!apiPath.startsWith(prefix) || apiPath.contains('..')) {
      throw const ValidationException('Unsupported photo address.');
    }
    final token = _tokens.accessToken;
    final request = http.Request(
      'GET',
      _baseUrl.resolve(apiPath.substring(prefix.length)),
    )..followRedirects = false;
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
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
    if (response.statusCode == 401 && token != null) {
      _tokens.clearIfCurrent(token);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw _errorFor(response.statusCode, _decode(response.bodyBytes));
  }

  /// Multipart upload of one file as form field `file`.
  Future<Map<String, Object?>> upload(
    String endpoint,
    List<int> bytes,
    String filename,
  ) async {
    final token = _tokens.accessToken;
    final request = http.MultipartRequest('POST', _baseUrl.resolve(endpoint))
      ..headers['Accept'] = 'application/json'
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final http.Response response;
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 60));
    } on http.ClientException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('The upload timed out. Try again.');
    }
    if (response.statusCode == 401 && token != null) {
      _tokens.clearIfCurrent(token);
    }
    final payload = _decode(response.bodyBytes);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        payload != null) {
      return payload;
    }
    throw _errorFor(response.statusCode, payload);
  }

  /// Like [request] but returns the raw text body (used for the CSV export).
  Future<String> requestText(
    String method,
    String endpoint, {
    Map<String, String>? query,
  }) async {
    final response = await _send(method, endpoint, query: query);
    final status = response.statusCode;
    if (status >= 200 && status < 300) return utf8.decode(response.bodyBytes);
    throw _errorFor(status, _decode(response.bodyBytes));
  }

  Future<http.Response> _send(
    String method,
    String endpoint, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    bool authenticated = true,
    Duration? timeout,
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
          .timeout(timeout ?? this.timeout);
    } on http.ClientException {
      throw const NetworkException();
    } on TimeoutException {
      throw const NetworkException('The request timed out. Try again.');
    }
    if (response.statusCode == 401 && token != null) {
      _tokens.clearIfCurrent(token);
    }
    return response;
  }

  AppException _errorFor(int status, Map<String, Object?>? payload) {
    final error = payload?['error'];
    final message = error is Map<String, Object?> ? error['message'] : null;
    final detail = message is String && message.trim().isNotEmpty
        ? message
        : null;
    return switch (status) {
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
