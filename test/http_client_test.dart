import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

void main() {
  group('Auth0HttpClient', () {
    test('post sends correct headers and body', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.host, 'test.auth0.com');
        expect(request.url.path, '/oauth/token');
        expect(request.headers['Content-Type'], 'application/json');
        expect(request.headers.containsKey('Auth0-Client'), true);

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'], 'authorization_code');

        return http.Response(
          jsonEncode({
            'access_token': 'at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      final client = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'client123',
        httpClient: mockClient,
      );

      final result = await client.post('/oauth/token', {
        'grant_type': 'authorization_code',
      });

      expect(result['access_token'], 'at');
      client.close();
    });

    test('get sends Authorization header when provided', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer mytoken');
        return http.Response(
          jsonEncode({'sub': 'auth0|123'}),
          200,
        );
      });

      final client = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'client123',
        httpClient: mockClient,
      );

      final result = await client.get(
        '/userinfo',
        extraHeaders: {'Authorization': 'Bearer mytoken'},
      );

      expect(result['sub'], 'auth0|123');
      client.close();
    });

    test('throws ApiException on 401', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Bad credentials',
          }),
          401,
        );
      });

      final client = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'client123',
        httpClient: mockClient,
      );

      expect(
        () => client.post('/oauth/token', {'grant_type': 'password'}),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          401,
        )),
      );
      client.close();
    });

    test('returns empty map on 200 with non-JSON body', () async {
      // Auth0 endpoints like /dbconnections/change_password return plain text
      // on success. The HTTP client treats non-JSON 2xx as empty success.
      final mockClient = MockClient((request) async {
        return http.Response('We just sent you an email.', 200);
      });

      final client = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'client123',
        httpClient: mockClient,
      );

      final result = await client.post('/dbconnections/change_password', {});
      expect(result, isEmpty);
      client.close();
    });

    test('throws ApiException on non-JSON error response', () async {
      final mockClient = MockClient((request) async {
        return http.Response('not json', 500);
      });

      final client = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'client123',
        httpClient: mockClient,
      );

      expect(
        () => client.post('/oauth/token', {}),
        throwsA(isA<ApiException>()),
      );
      client.close();
    });

    test('throws ApiException.networkError on connection failure', () async {
      final mockClient = MockClient((request) async {
        throw Exception('connection refused');
      });

      final client = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'client123',
        httpClient: mockClient,
      );

      expect(
        () => client.post('/oauth/token', {}),
        throwsA(isA<ApiException>().having(
          (e) => e.isNetworkError,
          'isNetworkError',
          true,
        )),
      );
      client.close();
    });

    test('returns empty map on 200 with empty body', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 200);
      });

      final client = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'client123',
        httpClient: mockClient,
      );

      final result = await client.post('/dbconnections/change_password', {});
      expect(result, isEmpty);
      client.close();
    });

    test('throws on non-200 empty body', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 500);
      });

      final client = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'client123',
        httpClient: mockClient,
      );

      expect(
        () => client.post('/oauth/token', {}),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          500,
        )),
      );
      client.close();
    });
  });
}
