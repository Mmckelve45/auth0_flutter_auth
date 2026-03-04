import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

import '../config/test_config.dart';
import '../helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Auth0Client client;

  setUp(() {
    client = createTestClient();
  });

  tearDown(() {
    client.close();
  });

  group('loginWithPassword', () {
    testWidgets('with valid credentials returns Credentials',
        (tester) async {
      late Credentials creds;
      try {
        creds = await client.api.loginWithPassword(
          usernameOrEmail: TestConfig.testEmail,
          password: TestConfig.testPassword,
          realm: TestConfig.connection,
          scopes: {'openid', 'profile', 'email'},
        );
      } on ApiException catch (e) {
        fail(diagnoseApiError(e));
      }

      expect(creds.accessToken, isNotEmpty);
      expect(creds.idToken, isNotNull);
      expect(creds.idToken, isNotEmpty);
      expect(creds.tokenType, isNotEmpty);
      expect(creds.expiresAt.isAfter(DateTime.now()), isTrue);
    });

    testWidgets('with wrong password throws ApiException with invalid_grant',
        (tester) async {
      try {
        await client.api.loginWithPassword(
          usernameOrEmail: TestConfig.testEmail,
          password: 'WrongPassword123!',
          realm: TestConfig.connection,
        );
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        if (e.errorCode == 'unauthorized_client') {
          fail(diagnoseApiError(e));
        }
        expect(e.isInvalidCredentials, isTrue);
      }
    });

    testWidgets('with non-existent user throws ApiException',
        (tester) async {
      try {
        await client.api.loginWithPassword(
          usernameOrEmail: 'nonexistent-user-${DateTime.now().millisecondsSinceEpoch}@example.com',
          password: 'AnyPassword1!',
          realm: TestConfig.connection,
        );
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        if (e.errorCode == 'unauthorized_client') {
          fail(diagnoseApiError(e));
        }
        expect(e.isInvalidCredentials, isTrue);
      }
    });

    testWidgets('with audience returns scoped access token',
        (tester) async {
      late Credentials creds;
      try {
        creds = await client.api.loginWithPassword(
          usernameOrEmail: TestConfig.testEmail,
          password: TestConfig.testPassword,
          realm: TestConfig.connection,
          audience: 'https://${TestConfig.domain}/api/v2/',
          scopes: {'openid', 'profile'},
        );
      } on ApiException catch (e) {
        fail(diagnoseApiError(e));
      }

      expect(creds.accessToken, isNotEmpty);
      // An audience-scoped token is typically a JWT (three dot-separated parts)
      expect(creds.accessToken.split('.').length, 3);
    });

    testWidgets('with scopes returns matching scopes', (tester) async {
      final requestedScopes = {'openid', 'profile', 'email'};

      late Credentials creds;
      try {
        creds = await client.api.loginWithPassword(
          usernameOrEmail: TestConfig.testEmail,
          password: TestConfig.testPassword,
          realm: TestConfig.connection,
          scopes: requestedScopes,
        );
      } on ApiException catch (e) {
        fail(diagnoseApiError(e));
      }

      // Auth0 may return the requested scopes or a superset
      for (final scope in requestedScopes) {
        expect(creds.scopes, contains(scope));
      }
    });

    testWidgets('with empty password throws immediately', (tester) async {
      try {
        await client.api.loginWithPassword(
          usernameOrEmail: TestConfig.testEmail,
          password: '',
          realm: TestConfig.connection,
        );
        fail('Should have thrown');
      } on ApiException catch (e) {
        if (e.errorCode == 'unauthorized_client') {
          fail(diagnoseApiError(e));
        }
        // Expected — Auth0 rejects empty passwords
      }
    });
  });
}
