import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

import '../config/test_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Auth0Client client;

  setUp(() {
    client = Auth0Client(
      domain: TestConfig.isConfigured ? TestConfig.domain : 'test.auth0.com',
      clientId: TestConfig.isConfigured ? TestConfig.clientId : 'test_id',
      options: const Auth0ClientOptions(enableDPoP: true),
    );
  });

  tearDown(() async {
    if (client.dpop != null) {
      await client.dpop!.clear();
    }
    client.close();
  });

  group('DPoP key operations', () {
    testWidgets('initialize generates key pair on device', (tester) async {
      expect(client.dpop, isNotNull);
      expect(client.dpop!.isInitialized, isFalse);

      await client.dpop!.initialize();

      expect(client.dpop!.isInitialized, isTrue);
    });

    testWidgets('generateHeaders returns DPoP proof header', (tester) async {
      await client.dpop!.initialize();

      final headers = await client.dpop!.generateHeaders(
        url: 'https://test.auth0.com/oauth/token',
        method: 'POST',
      );

      expect(headers, contains('DPoP'));
      expect(headers['DPoP'], isNotEmpty);
      // DPoP proof is a JWT (three dot-separated parts)
      expect(headers['DPoP']!.split('.').length, 3);
    });

    testWidgets('generateHeaders with accessToken includes ath claim',
        (tester) async {
      await client.dpop!.initialize();

      final headers = await client.dpop!.generateHeaders(
        url: 'https://test.auth0.com/api/v2/users',
        method: 'GET',
        accessToken: 'test_access_token',
      );

      expect(headers, contains('DPoP'));
      expect(headers['DPoP'], isNotEmpty);
    });

    testWidgets('clear resets initialization state', (tester) async {
      await client.dpop!.initialize();
      expect(client.dpop!.isInitialized, isTrue);

      await client.dpop!.clear();
      expect(client.dpop!.isInitialized, isFalse);
    });

    testWidgets('generateHeaders before initialize throws DPoPException',
        (tester) async {
      try {
        await client.dpop!.generateHeaders(
          url: 'https://test.auth0.com/oauth/token',
          method: 'POST',
        );
        fail('Should have thrown DPoPException');
      } on DPoPException catch (e) {
        expect(e.isNotInitialized, isTrue);
      }
    });
  });
}
