import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project/core/network/api_client.dart';
import 'package:project/core/network/token_store.dart';
import 'package:project/data/repositories/remote/remote_auth_repository.dart';
import 'package:project/domain/enums/user_role.dart';

void main() {
  // The live API returns { token, user } at the top level (no `data` wrapper).
  const body =
      '{"token":"jwt-token","user":{"id":"user-student","name":"student",'
      '"email":"student@campusconnect.edu","role":"STUDENT",'
      '"studentId":null,"department":null}}';

  test('login accepts the real top-level { token, user } response', () async {
    final tokens = TokenStore();
    final api = ApiClient(
      baseUrl: Uri.parse('http://example.test/api/v1'),
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/login');
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response(body, 200);
      }),
      tokens: tokens,
    );
    final user = await RemoteAuthRepository(
      api,
      tokens,
    ).login(email: 'student@campusconnect.edu', password: 'Password1');
    expect(user.role, UserRole.student);
    expect(tokens.accessToken, 'jwt-token');
  });

  test('login still accepts a { data: { token, user } } envelope', () async {
    final tokens = TokenStore();
    final api = ApiClient(
      baseUrl: Uri.parse('http://example.test/api/v1'),
      client: MockClient((_) async => http.Response('{"data":$body}', 200)),
      tokens: tokens,
    );
    final user = await RemoteAuthRepository(
      api,
      tokens,
    ).login(email: 'student@campusconnect.edu', password: 'Password1');
    expect(user.email, 'student@campusconnect.edu');
    expect(tokens.accessToken, 'jwt-token');
  });
}
