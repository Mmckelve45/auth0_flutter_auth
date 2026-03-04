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

  group('getUserInfo', () {
    testWidgets('with valid access token returns UserProfile',
        (tester) async {
      // First login to get a real access token
      final creds = await loginTestUser(client.api);

      final profile = await client.api.getUserInfo(
        accessToken: creds.accessToken,
      );

      expect(profile.sub, isNotEmpty);
      expect(profile.email, TestConfig.testEmail);
    });

    testWidgets('with invalid token throws 401 ApiException',
        (tester) async {
      try {
        await client.api.getUserInfo(accessToken: 'invalid_token');
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
      }
    });
  });
}
