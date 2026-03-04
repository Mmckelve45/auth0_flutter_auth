import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

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

  group('renewTokens', () {
    testWidgets('login with offline_access returns refresh token',
        (tester) async {
      final creds = await loginTestUser(client.api);

      expect(creds.refreshToken, isNotNull);
      expect(creds.refreshToken, isNotEmpty);
    });

    testWidgets('with valid refresh token returns new access token',
        (tester) async {
      final creds = await loginTestUser(client.api);

      final renewed = await client.api.renewTokens(
        refreshToken: creds.refreshToken!,
      );

      expect(renewed.accessToken, isNotEmpty);
      expect(renewed.expiresAt.isAfter(DateTime.now()), isTrue);
    });

    testWidgets('with revoked refresh token throws invalid_grant',
        (tester) async {
      final creds = await loginTestUser(client.api);
      final rt = creds.refreshToken!;

      // Revoke first
      await client.api.revokeToken(refreshToken: rt);

      // Now try to refresh — should fail
      try {
        await client.api.renewTokens(refreshToken: rt);
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        expect(e.isInvalidCredentials || e.errorCode == 'invalid_grant',
            isTrue);
      }
    });
  });
}
