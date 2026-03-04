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

  group('onCredentialsChanged stream', () {
    testWidgets('emits on storeCredentials', (tester) async {
      final emissions = <Credentials?>[];
      final sub = client.credentials.onCredentialsChanged.listen(
        (creds) => emissions.add(creds),
      );

      final creds = Credentials(
        accessToken: 'stream_test_at',
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      await client.credentials.storeCredentials(creds);

      // Allow async stream delivery
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(emissions, isNotEmpty);
      expect(emissions.last, isNotNull);
      expect(emissions.last!.accessToken, 'stream_test_at');

      await sub.cancel();
    });

    testWidgets('emits null on clearCredentials', (tester) async {
      // Store first
      final creds = Credentials(
        accessToken: 'to_clear',
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await client.credentials.storeCredentials(creds);

      final emissions = <Credentials?>[];
      final sub = client.credentials.onCredentialsChanged.listen(
        (creds) => emissions.add(creds),
      );

      await client.credentials.clearCredentials();

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(emissions, contains(isNull));

      await sub.cancel();
    });
  });
}
