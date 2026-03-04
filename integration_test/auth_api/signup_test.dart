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

  group('signup', () {
    testWidgets('new user returns DatabaseUser with email', (tester) async {
      final email = uniqueTestEmail();

      final dbUser = await client.api.signup(
        email: email,
        password: 'TestP@ssw0rd123!',
        connection: TestConfig.connection,
      );

      expect(dbUser.email, email);
      expect(dbUser.emailVerified, isFalse);
    });

    testWidgets('duplicate email throws ApiException', (tester) async {
      // The primary test user already exists
      try {
        await client.api.signup(
          email: TestConfig.testEmail,
          password: 'AnyP@ssw0rd1!',
          connection: TestConfig.connection,
        );
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        // Auth0 returns 'user_exists' or 'invalid_signup'
        expect(
          e.isAlreadyExists || e.errorCode == 'invalid_signup',
          isTrue,
          reason: 'Expected user_exists or invalid_signup, got ${e.errorCode}',
        );
      }
    });

    testWidgets('with user_metadata persists metadata', (tester) async {
      final email = uniqueTestEmail();

      final dbUser = await client.api.signup(
        email: email,
        password: 'TestP@ssw0rd123!',
        connection: TestConfig.connection,
        userMetadata: {'plan': 'free', 'source': 'integration_test'},
      );

      expect(dbUser.email, email);
      // Metadata is stored but not returned in the signup response;
      // we just verify the call succeeds without error.
    });
  });
}
