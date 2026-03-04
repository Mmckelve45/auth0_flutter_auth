import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

/// Integration tests for auth0_flutter_auth.
///
/// These tests run on a real device or simulator. They test:
/// 1. Auth0Client construction and component wiring
/// 2. API error handling with a real HTTP stack (hitting a fake domain)
/// 3. Credential storage round-trips (flutter_secure_storage)
/// 4. WebAuth URL building
///
/// To run:
///   flutter test integration_test/auth_flow_test.dart
///
/// Note: Tests that require a real Auth0 tenant (login, token exchange)
/// are marked with `skip` and require configuring REAL_AUTH0_DOMAIN etc.
/// The automated tests use a fake domain and verify error handling.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Auth0Client client;

  setUp(() {
    client = Auth0Client(
      domain: 'test-domain.auth0.com',
      clientId: 'test_client_id',
    );
  });

  tearDown(() {
    client.close();
  });

  group('Auth0Client initialization', () {
    testWidgets('creates all components', (tester) async {
      expect(client.api, isNotNull);
      expect(client.webAuth, isNotNull);
      expect(client.credentials, isNotNull);
      expect(client.dpop, isNull); // Not enabled
    });

    testWidgets('creates DPoP when enabled', (tester) async {
      final dpopClient = Auth0Client(
        domain: 'test.auth0.com',
        clientId: 'test',
        options: const Auth0ClientOptions(enableDPoP: true),
      );
      expect(dpopClient.dpop, isNotNull);
      dpopClient.close();
    });
  });

  group('API error handling — real HTTP', () {
    testWidgets('loginWithPassword to fake domain returns network error',
        (tester) async {
      // Hitting a non-existent domain should throw a network error
      try {
        await client.api.loginWithPassword(
          usernameOrEmail: 'test@example.com',
          password: 'password',
          realm: 'Username-Password-Authentication',
        );
        fail('Should have thrown');
      } on ApiException catch (e) {
        expect(e.isNetworkError, true);
      }
    });

    testWidgets('getUserInfo to fake domain returns network error',
        (tester) async {
      try {
        await client.api.getUserInfo(accessToken: 'fake_token');
        fail('Should have thrown');
      } on ApiException catch (e) {
        expect(e.isNetworkError, true);
      }
    });

    testWidgets('signup to fake domain returns network error',
        (tester) async {
      try {
        await client.api.signup(
          email: 'test@example.com',
          password: 'P@ssw0rd123',
          connection: 'Username-Password-Authentication',
        );
        fail('Should have thrown');
      } on ApiException catch (e) {
        expect(e.isNetworkError, true);
      }
    });
  });

  group('CredentialStore — device storage', () {
    testWidgets('storeCredentials + getCredentials round-trips',
        (tester) async {
      final creds = Credentials(
        accessToken: 'integration_test_at',
        tokenType: 'Bearer',
        idToken: 'integration_test_idt',
        refreshToken: 'integration_test_rt',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scopes: {'openid', 'profile'},
      );

      await client.credentials.storeCredentials(creds);

      final stored = await client.credentials.getCredentials();
      expect(stored, isNotNull);
      expect(stored!.accessToken, 'integration_test_at');
      expect(stored.refreshToken, 'integration_test_rt');
      expect(stored.scopes, {'openid', 'profile'});

      // Clean up
      await client.credentials.clearCredentials();
    });

    testWidgets('hasValidCredentials returns true after store',
        (tester) async {
      final creds = Credentials(
        accessToken: 'at',
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await client.credentials.storeCredentials(creds);
      expect(await client.credentials.hasValidCredentials(), true);

      await client.credentials.clearCredentials();
      expect(await client.credentials.hasValidCredentials(), false);
    });

    testWidgets('getCredentials returns null when empty', (tester) async {
      await client.credentials.clearCredentials();
      final result = await client.credentials.getCredentials();
      expect(result, isNull);
    });

    testWidgets('hasValidCredentials with expired token but refresh token',
        (tester) async {
      final creds = Credentials(
        accessToken: 'expired_at',
        tokenType: 'Bearer',
        refreshToken: 'rt_for_refresh',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await client.credentials.storeCredentials(creds);

      // Has valid credentials because refresh token exists
      expect(await client.credentials.hasValidCredentials(), true);

      await client.credentials.clearCredentials();
    });

    testWidgets('user() extracts profile from ID token', (tester) async {
      // Build a fake ID token with standard claims
      // header.payload.signature — we only need the payload to be valid JSON
      final header = _base64UrlEncode('{"alg":"RS256","typ":"JWT"}');
      final payload = _base64UrlEncode(
        '{"sub":"auth0|integration","name":"Integration Test",'
        '"email":"integration@test.com","email_verified":true}',
      );
      final sig = _base64UrlEncode('fakesignature');
      final idToken = '$header.$payload.$sig';

      final creds = Credentials(
        accessToken: 'at',
        tokenType: 'Bearer',
        idToken: idToken,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await client.credentials.storeCredentials(creds);

      final user = await client.credentials.user();
      expect(user, isNotNull);
      expect(user!.sub, 'auth0|integration');
      expect(user.name, 'Integration Test');
      expect(user.email, 'integration@test.com');

      await client.credentials.clearCredentials();
    });
  });

  group('WebAuth URL building', () {
    testWidgets('buildAuthorizeUrl generates valid URL', (tester) async {
      final url = client.webAuth.buildAuthorizeUrl(
        redirectUrl: 'myapp://callback',
        audience: 'https://api.example.com',
        scopes: {'openid', 'profile', 'email'},
      );

      expect(url.scheme, 'https');
      expect(url.host, 'test-domain.auth0.com');
      expect(url.path, '/authorize');
      expect(url.queryParameters['response_type'], 'code');
      expect(url.queryParameters['client_id'], 'test_client_id');
      expect(url.queryParameters['redirect_uri'], 'myapp://callback');
      expect(url.queryParameters['code_challenge_method'], 'S256');
      expect(url.queryParameters['state'], isNotNull);
      expect(url.queryParameters['code_challenge'], isNotNull);
      expect(url.queryParameters['audience'], 'https://api.example.com');
    });

    testWidgets('handleCallback rejects wrong state', (tester) async {
      client.webAuth.buildAuthorizeUrl(redirectUrl: 'myapp://callback');

      try {
        await client.webAuth.handleCallback(
          Uri.parse('myapp://callback?code=abc&state=wrong'),
        );
        fail('Should have thrown');
      } on WebAuthException catch (e) {
        expect(e.isStateMismatch, true);
      }
    });
  });
}

String _base64UrlEncode(String input) {
  return base64Url.encode(utf8.encode(input)).replaceAll('=', '');
}
