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

  tearDown(() async {
    await client.credentials.clearCredentials();
    client.close();
  });

  group('Full E2E flow', () {
    testWidgets(
        'login → store → userinfo → refresh → revoke → clear → verify empty',
        (tester) async {
      // 1. Login with password (real Auth0 call)
      final creds = await client.api.loginWithPassword(
        usernameOrEmail: TestConfig.testEmail,
        password: TestConfig.testPassword,
        realm: TestConfig.connection,
        scopes: {'openid', 'profile', 'email', 'offline_access'},
      );

      expect(creds.accessToken, isNotEmpty);
      expect(creds.refreshToken, isNotNull);
      expect(creds.refreshToken, isNotEmpty);

      // 2. Store credentials
      await client.credentials.storeCredentials(creds);
      expect(await client.credentials.hasValidCredentials(), isTrue);

      // 3. Get user info (with the real access token)
      final profile = await client.api.getUserInfo(
        accessToken: creds.accessToken,
      );
      expect(profile.sub, isNotEmpty);
      expect(profile.email, TestConfig.testEmail);

      // 4. Refresh token
      final renewed = await client.api.renewTokens(
        refreshToken: creds.refreshToken!,
      );
      expect(renewed.accessToken, isNotEmpty);
      expect(renewed.expiresAt.isAfter(DateTime.now()), isTrue);

      // 5. Revoke token (use the original refresh token)
      await client.api.revokeToken(refreshToken: creds.refreshToken!);

      // 6. Clear credentials
      await client.credentials.clearCredentials();

      // 7. Verify storage is empty
      expect(await client.credentials.hasValidCredentials(), isFalse);
      final stored = await client.credentials.getCredentials();
      expect(stored, isNull);
    });
  });
}
