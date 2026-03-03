import 'package:flutter_test/flutter_test.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

void main() {
  group('Auth0Client', () {
    test('creates with required parameters', () {
      final client = Auth0Client(
        domain: 'test.auth0.com',
        clientId: 'test_client',
      );

      expect(client.domain, 'test.auth0.com');
      expect(client.clientId, 'test_client');
      expect(client.api, isNotNull);
      expect(client.webAuth, isNotNull);
      expect(client.credentials, isNotNull);
      expect(client.dpop, isNull); // DPoP not enabled by default

      client.close();
    });

    test('creates with DPoP enabled', () {
      final client = Auth0Client(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        options: const Auth0ClientOptions(enableDPoP: true),
      );

      expect(client.dpop, isNotNull);
      client.close();
    });

    test('creates with custom options', () {
      final client = Auth0Client(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        options: Auth0ClientOptions(
          audience: 'https://api.example.com',
          scopes: {'openid', 'profile'},
          httpTimeout: const Duration(seconds: 30),
        ),
      );

      expect(client.api, isNotNull);
      client.close();
    });
  });
}
