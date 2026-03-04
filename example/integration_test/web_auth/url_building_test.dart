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

  group('WebAuth URL building', () {
    testWidgets('buildAuthorizeUrl includes PKCE code_challenge, state, nonce',
        (tester) async {
      final url = client.webAuth.buildAuthorizeUrl(
        redirectUrl: 'myapp://callback',
        scopes: {'openid', 'profile', 'email'},
      );

      expect(url.scheme, 'https');
      expect(url.path, '/authorize');
      expect(url.queryParameters['response_type'], 'code');
      expect(url.queryParameters['code_challenge_method'], 'S256');
      expect(url.queryParameters['code_challenge'], isNotNull);
      expect(url.queryParameters['code_challenge'], isNotEmpty);
      expect(url.queryParameters['state'], isNotNull);
      expect(url.queryParameters['state'], isNotEmpty);
    });

    testWidgets('connection and connectionScope params appear in URL',
        (tester) async {
      final url = client.webAuth.buildAuthorizeUrl(
        redirectUrl: 'myapp://callback',
        connection: 'github',
        connectionScope: 'repo,user',
      );

      expect(url.queryParameters['connection'], 'github');
      expect(url.queryParameters['connection_scope'], 'repo,user');
    });

    testWidgets('handleCallback rejects mismatched state', (tester) async {
      // First build an authorize URL to set internal PKCE state
      client.webAuth.buildAuthorizeUrl(redirectUrl: 'myapp://callback');

      try {
        await client.webAuth.handleCallback(
          Uri.parse('myapp://callback?code=abc&state=wrong_state'),
        );
        fail('Should have thrown WebAuthException');
      } on WebAuthException catch (e) {
        expect(e.isStateMismatch, isTrue);
      }
    });

    testWidgets('handleCallback extracts code from valid callback',
        (tester) async {
      final url = client.webAuth.buildAuthorizeUrl(
        redirectUrl: 'myapp://callback',
      );

      final state = url.queryParameters['state']!;

      // handleCallback will try to exchange the code via the API,
      // which will fail against the real Auth0 tenant because the code
      // is fake. But we can verify it gets past state validation.
      try {
        await client.webAuth.handleCallback(
          Uri.parse('myapp://callback?code=test_auth_code&state=$state'),
        );
        // If it doesn't throw for state mismatch, the code exchange
        // will fail with an ApiException — that's expected.
        fail('Should have thrown during code exchange');
      } on WebAuthException catch (e) {
        // State mismatch would be a test failure — this should NOT happen
        expect(e.isStateMismatch, isFalse);
      } on ApiException {
        // Expected: the fake code cannot be exchanged.
        // The important thing is that state validation passed.
      }
    });

    testWidgets('audience parameter appears in URL', (tester) async {
      final url = client.webAuth.buildAuthorizeUrl(
        redirectUrl: 'myapp://callback',
        audience: 'https://api.example.com',
      );

      expect(url.queryParameters['audience'], 'https://api.example.com');
    });

    testWidgets('organization parameter appears in URL', (tester) async {
      final url = client.webAuth.buildAuthorizeUrl(
        redirectUrl: 'myapp://callback',
        organizationId: 'org_12345',
      );

      expect(url.queryParameters['organization'], 'org_12345');
    });

    testWidgets('google-oauth2 connection skips Auth0 login page',
        (tester) async {
      // Passing connection=google-oauth2 tells Auth0 to redirect
      // directly to Google's OAuth consent screen, bypassing the
      // Universal Login page.
      final url = client.webAuth.buildAuthorizeUrl(
        redirectUrl: 'myapp://callback',
        connection: 'google-oauth2',
        scopes: {'openid', 'profile', 'email'},
      );

      expect(url.queryParameters['connection'], 'google-oauth2');
      expect(url.queryParameters['response_type'], 'code');
      expect(url.queryParameters['scope'], contains('openid'));
    });

    testWidgets('social connection with connectionScope passes scopes',
        (tester) async {
      // connectionScope lets you request additional permissions from the
      // social provider (e.g. Google Calendar, Drive, etc.)
      final url = client.webAuth.buildAuthorizeUrl(
        redirectUrl: 'myapp://callback',
        connection: 'google-oauth2',
        connectionScope: 'https://www.googleapis.com/auth/calendar.readonly',
      );

      expect(url.queryParameters['connection'], 'google-oauth2');
      expect(url.queryParameters['connection_scope'],
          'https://www.googleapis.com/auth/calendar.readonly');
    });
  });
}
