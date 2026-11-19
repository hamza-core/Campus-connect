import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project/core/errors/app_exception.dart';
import 'package:project/core/network/api_client.dart';
import 'package:project/core/network/api_endpoints.dart';
import 'package:project/core/network/token_store.dart';

void main() {
  final baseUrl = Uri.parse('https://example.test/api/v1');

  test(
    'Preserves the API prefix, query parameters and auth boundaries',
    () async {
      final tokens = TokenStore()..replace('token');
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/complaints');
        expect(request.url.queryParameters['q'], 'Lab & IT');
        expect(request.headers['Authorization'], 'Bearer token');
        return http.Response(
          '{"data":[],"page":1,"pageSize":20,"total":0}',
          200,
        );
      });
      final api = ApiClient(baseUrl: baseUrl, client: client, tokens: tokens);
      final result = await api.request(
        'GET',
        ApiEndpoints.complaints,
        query: {'q': 'Lab & IT'},
      );
      expect(result['data'], isEmpty);
      await expectLater(
        api.request('GET', 'https://example.org'),
        throwsArgumentError,
      );
    },
  );

  test('An old 401 cannot clear a newer access token', () async {
    final tokens = TokenStore()..replace('old');
    final response = Completer<http.Response>();
    final client = MockClient((request) => response.future);
    final api = ApiClient(baseUrl: baseUrl, client: client, tokens: tokens);
    final request = expectLater(
      api.request('GET', ApiEndpoints.me),
      throwsA(isA<UnauthorizedException>()),
    );
    tokens.replace('new');
    response.complete(http.Response('', 401));
    await request;
    expect(tokens.accessToken, 'new');

    await expectLater(
      api.request('GET', ApiEndpoints.me),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(tokens.accessToken, isNull);
  });

  test('A non-JSON 403 still becomes a typed forbidden error', () async {
    final client = MockClient(
      (request) async => http.Response('Forbidden', 403),
    );
    final api = ApiClient(
      baseUrl: baseUrl,
      client: client,
      tokens: TokenStore(),
    );
    await expectLater(
      api.request('GET', ApiEndpoints.complaints),
      throwsA(isA<ForbiddenException>()),
    );
  });
}
