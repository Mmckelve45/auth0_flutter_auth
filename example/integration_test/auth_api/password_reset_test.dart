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

  group('resetPassword', () {
    testWidgets('with valid email succeeds', (tester) async {
      // Should complete without error (triggers email send)
      await client.api.resetPassword(
        email: TestConfig.testEmail,
        connection: TestConfig.connection,
      );
    });

    testWidgets('with non-existent email still succeeds', (tester) async {
      // Auth0 does not reveal user existence — returns 200 regardless
      await client.api.resetPassword(
        email: 'nonexistent-${DateTime.now().millisecondsSinceEpoch}@example.com',
        connection: TestConfig.connection,
      );
    });
  });
}
