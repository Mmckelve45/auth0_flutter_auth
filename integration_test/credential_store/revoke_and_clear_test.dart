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

  tearDown(() async {
    await client.credentials.clearCredentials();
    client.close();
  });

  group('revokeAndClearCredentials', () {
    testWidgets('revokes refresh token server-side and clears storage',
        (tester) async {
      // Login to get real credentials with a refresh token
      final creds = await loginTestUser(client.api);
      expect(creds.refreshToken, isNotNull);

      await client.credentials.storeCredentials(creds);
      expect(await client.credentials.hasValidCredentials(), isTrue);

      // Revoke and clear
      await client.credentials.revokeAndClearCredentials();

      // Storage should be empty
      expect(await client.credentials.hasValidCredentials(), isFalse);
      final stored = await client.credentials.getCredentials();
      expect(stored, isNull);

      // The refresh token should be revoked server-side
      try {
        await client.api.renewTokens(refreshToken: creds.refreshToken!);
        fail('Should have thrown — refresh token was revoked');
      } on ApiException catch (e) {
        expect(e.isInvalidCredentials || e.errorCode == 'invalid_grant',
            isTrue);
      }
    });
  });
}
