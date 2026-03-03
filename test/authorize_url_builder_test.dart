import 'package:flutter_test/flutter_test.dart';
import 'package:auth0_flutter_auth/src/web_auth/authorize_url_builder.dart';

void main() {
  late AuthorizeUrlBuilder builder;

  setUp(() {
    builder = AuthorizeUrlBuilder(
      domain: 'test.auth0.com',
      clientId: 'test_client',
    );
  });

  group('AuthorizeUrlBuilder', () {
    test('buildAuthorizeUrl includes required parameters', () {
      final url = builder.buildAuthorizeUrl(
        redirectUrl: 'myapp://callback',
        state: 'state123',
        codeChallenge: 'challenge123',
      );

      expect(url.host, 'test.auth0.com');
      expect(url.path, '/authorize');
      expect(url.queryParameters['response_type'], 'code');
      expect(url.queryParameters['client_id'], 'test_client');
      expect(url.queryParameters['redirect_uri'], 'myapp://callback');
      expect(url.queryParameters['state'], 'state123');
      expect(url.queryParameters['code_challenge'], 'challenge123');
      expect(url.queryParameters['code_challenge_method'], 'S256');
    });

    test('buildAuthorizeUrl includes optional parameters', () {
      final url = builder.buildAuthorizeUrl(
        redirectUrl: 'myapp://callback',
        state: 'state123',
        codeChallenge: 'challenge123',
        audience: 'https://api.example.com',
        scopes: {'openid', 'profile'},
        organizationId: 'org_abc',
        nonce: 'nonce123',
        maxAge: 3600,
      );

      expect(url.queryParameters['audience'], 'https://api.example.com');
      expect(url.queryParameters['scope'], contains('openid'));
      expect(url.queryParameters['organization'], 'org_abc');
      expect(url.queryParameters['nonce'], 'nonce123');
      expect(url.queryParameters['max_age'], '3600');
    });

    test('buildAuthorizeUrl includes custom parameters', () {
      final url = builder.buildAuthorizeUrl(
        redirectUrl: 'myapp://callback',
        state: 'state123',
        codeChallenge: 'challenge123',
        parameters: {'screen_hint': 'signup', 'login_hint': 'user@example.com'},
      );

      expect(url.queryParameters['screen_hint'], 'signup');
      expect(url.queryParameters['login_hint'], 'user@example.com');
    });

    test('buildLogoutUrl includes client_id', () {
      final url = builder.buildLogoutUrl();

      expect(url.host, 'test.auth0.com');
      expect(url.path, '/v2/logout');
      expect(url.queryParameters['client_id'], 'test_client');
    });

    test('buildLogoutUrl includes returnTo and federated', () {
      final url = builder.buildLogoutUrl(
        returnTo: 'myapp://home',
        federated: true,
      );

      expect(url.queryParameters['returnTo'], 'myapp://home');
      expect(url.queryParameters.containsKey('federated'), true);
    });

    test('buildAuthorizeUrl omits empty scopes', () {
      final url = builder.buildAuthorizeUrl(
        redirectUrl: 'myapp://callback',
        state: 'state123',
        codeChallenge: 'challenge123',
        scopes: {},
      );

      expect(url.queryParameters.containsKey('scope'), false);
    });

    test('buildAuthorizeUrl includes invitation URL', () {
      final url = builder.buildAuthorizeUrl(
        redirectUrl: 'myapp://callback',
        state: 'state123',
        codeChallenge: 'challenge123',
        invitationUrl: 'https://test.auth0.com/invitation/abc',
      );

      expect(url.queryParameters['invitation'],
          'https://test.auth0.com/invitation/abc');
    });
  });
}
