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

  group('Auto-refresh on getCredentials', () {
    testWidgets(
        'expired token with valid refresh token auto-refreshes against Auth0',
        (tester) async {
      // First, get a real refresh token
      final realCreds = await loginTestUser(client.api);
      expect(realCreds.refreshToken, isNotNull);

      // Store credentials with an expired access token but real refresh token
      final expiredCreds = Credentials(
        accessToken: 'expired_access_token',
        tokenType: 'Bearer',
        refreshToken: realCreds.refreshToken,
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
        scopes: realCreds.scopes,
      );

      await client.credentials.storeCredentials(expiredCreds);

      // getCredentials should auto-refresh using the real refresh token
      final refreshed = await client.credentials.getCredentials();

      expect(refreshed, isNotNull);
      expect(refreshed!.accessToken, isNot('expired_access_token'));
      expect(refreshed.accessToken, isNotEmpty);
      expect(refreshed.expiresAt.isAfter(DateTime.now()), isTrue);
    });
  });
}
