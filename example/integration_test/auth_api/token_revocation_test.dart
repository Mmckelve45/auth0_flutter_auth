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

  group('revokeToken', () {
    testWidgets('with valid refresh token succeeds', (tester) async {
      final creds = await loginTestUser(client.api);

      // Should complete without error
      await client.api.revokeToken(refreshToken: creds.refreshToken!);
    });

    testWidgets('revoked token cannot be used to refresh', (tester) async {
      final creds = await loginTestUser(client.api);
      final rt = creds.refreshToken!;

      await client.api.revokeToken(refreshToken: rt);

      try {
        await client.api.renewTokens(refreshToken: rt);
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        expect(e.isInvalidCredentials || e.errorCode == 'invalid_grant',
            isTrue);
      }
    });

    testWidgets('revoking already-revoked token is idempotent',
        (tester) async {
      final creds = await loginTestUser(client.api);
      final rt = creds.refreshToken!;

      await client.api.revokeToken(refreshToken: rt);
      // Second revocation should not throw
      await client.api.revokeToken(refreshToken: rt);
    });
  });
}
