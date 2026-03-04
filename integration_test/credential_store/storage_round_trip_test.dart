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

  group('Credential storage round-trip', () {
    testWidgets('store → get → returns same values', (tester) async {
      final creds = Credentials(
        accessToken: 'rt_test_at',
        tokenType: 'Bearer',
        idToken: buildFakeIdToken(sub: 'auth0|roundtrip'),
        refreshToken: 'rt_test_refresh',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scopes: {'openid', 'profile'},
      );

      await client.credentials.storeCredentials(creds);

      final stored = await client.credentials.getCredentials();
      expect(stored, isNotNull);
      expect(stored!.accessToken, 'rt_test_at');
      expect(stored.refreshToken, 'rt_test_refresh');
      expect(stored.scopes, contains('openid'));
      expect(stored.scopes, contains('profile'));
    });

    testWidgets('clearCredentials → getCredentials returns null',
        (tester) async {
      final creds = Credentials(
        accessToken: 'to_clear',
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await client.credentials.storeCredentials(creds);
      expect(await client.credentials.hasValidCredentials(), isTrue);

      await client.credentials.clearCredentials();

      final result = await client.credentials.getCredentials();
      expect(result, isNull);
      expect(await client.credentials.hasValidCredentials(), isFalse);
    });

    testWidgets('getCredentials returns null when nothing stored',
        (tester) async {
      await client.credentials.clearCredentials();
      final result = await client.credentials.getCredentials();
      expect(result, isNull);
    });

    testWidgets('user() extracts profile from stored ID token',
        (tester) async {
      final idToken = buildFakeIdToken(
        sub: 'auth0|user-test',
        email: 'user@test.com',
        name: 'Test User',
      );

      final creds = Credentials(
        accessToken: 'at',
        tokenType: 'Bearer',
        idToken: idToken,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await client.credentials.storeCredentials(creds);

      final user = await client.credentials.user();
      expect(user, isNotNull);
      expect(user!.sub, 'auth0|user-test');
      expect(user.email, 'user@test.com');
      expect(user.name, 'Test User');
    });
  });
}
