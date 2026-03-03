import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';
import 'package:auth0_flutter_auth/src/api/http_client.dart';
import 'package:auth0_flutter_auth/src/web_auth/web_auth.dart';
import 'package:auth0_flutter_auth/src/web_auth/browser_platform.dart';

/// Mock browser that captures the launched URL and returns a configurable callback.
class _MockBrowserPlatform extends BrowserPlatform {
  String? lastLaunchedUrl;
  String? callbackUrl;
  bool shouldCancel = false;
  bool cancelCalled = false;

  @override
  Future<String> launchAuth({
    required String url,
    required String callbackScheme,
    bool preferEphemeral = false,
  }) async {
    lastLaunchedUrl = url;
    if (shouldCancel) {
      throw WebAuthException.cancelled();
    }
    if (callbackUrl != null) {
      return callbackUrl!;
    }
    throw WebAuthException.noCallbackUrl();
  }

  @override
  Future<void> cancel() async {
    cancelCalled = true;
  }
}

void main() {
  late _MockBrowserPlatform mockBrowser;
  late Auth0HttpClient httpClient;
  late AuthApi api;

  /// Helper to create a WebAuth with a mock HTTP backend.
  /// The [onTokenExchange] callback receives the request body and returns
  /// the token response JSON.
  WebAuth _createWebAuth({
    required Map<String, dynamic> Function(Map<String, dynamic> body) onTokenExchange,
  }) {
    final mock = MockClient((request) async {
      if (request.url.path == '/oauth/token') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final response = onTokenExchange(body);
        return http.Response(jsonEncode(response), 200);
      }
      return http.Response('Not found', 404);
    });

    httpClient = Auth0HttpClient(
      domain: 'test.auth0.com',
      clientId: 'test_client',
      httpClient: mock,
    );
    api = AuthApi(client: httpClient, clientId: 'test_client');

    return WebAuth(
      domain: 'test.auth0.com',
      clientId: 'test_client',
      api: api,
      browser: mockBrowser,
    );
  }

  setUp(() {
    mockBrowser = _MockBrowserPlatform();
  });

  group('WebAuth.login()', () {
    test('performs PKCE flow: builds URL, launches browser, exchanges code', () async {
      String? capturedVerifier;

      final mock = MockClient((request) async {
        if (request.url.path == '/oauth/token') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          capturedVerifier = body['code_verifier'] as String?;
          return http.Response(jsonEncode({
            'access_token': 'at_from_exchange',
            'token_type': 'Bearer',
            'expires_in': 3600,
            'scope': 'openid profile',
          }), 200);
        }
        return http.Response('Not found', 404);
      });

      httpClient = Auth0HttpClient(domain: 'test.auth0.com', clientId: 'test_client', httpClient: mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final browser = _StatefulMockBrowser(code: 'auth_code_123');
      final webAuth = WebAuth(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        api: api,
        browser: browser,
      );

      final creds = await webAuth.login(scopes: {'openid', 'profile'});
      expect(creds.accessToken, 'at_from_exchange');
      expect(capturedVerifier, isNotNull);
      expect(capturedVerifier!.length, greaterThanOrEqualTo(43));
    });

    test('throws WebAuthException.cancelled when user cancels', () async {
      mockBrowser.shouldCancel = true;

      final webAuth = _createWebAuth(onTokenExchange: (_) => {});

      expect(
        () => webAuth.login(),
        throwsA(isA<WebAuthException>().having(
          (e) => e.isCancelled,
          'isCancelled',
          true,
        )),
      );
    });

    test('throws when callback contains error parameter', () async {
      final browser = _ErrorCallbackBrowser(
        error: 'access_denied',
        description: 'User denied access',
      );

      final mock = MockClient((request) async {
        return http.Response(jsonEncode({
          'access_token': 'at',
          'token_type': 'Bearer',
          'expires_in': 3600,
        }), 200);
      });

      httpClient = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        httpClient: mock,
      );
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final webAuth = WebAuth(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        api: api,
        browser: browser,
      );

      // This will fail at state check first since error browser doesn't match state.
      // That's actually correct — the real browser would include the state.
      expect(
        () => webAuth.login(),
        throwsA(isA<WebAuthException>()),
      );
    });

    test('includes audience and scopes in authorize URL', () async {
      final browser = _StatefulMockBrowser(code: 'code123');

      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'access_token': 'at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        httpClient: mock,
      );
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final webAuth = WebAuth(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        api: api,
        browser: browser,
      );

      await webAuth.login(
        audience: 'https://api.example.com',
        scopes: {'openid', 'profile', 'read:data'},
      );

      final launchedUrl = browser.lastLaunchedUrl!;
      expect(launchedUrl, contains('audience='));
      expect(launchedUrl, contains('scope='));
    });
  });

  group('WebAuth.logout()', () {
    test('builds logout URL and launches browser', () async {
      final browser = _StatefulMockBrowser(code: '');
      final webAuth = WebAuth(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        api: AuthApi(
          client: Auth0HttpClient(
            domain: 'test.auth0.com',
            clientId: 'test_client',
            httpClient: MockClient((_) async => http.Response('', 200)),
          ),
          clientId: 'test_client',
        ),
        browser: browser,
      );

      // Logout might throw cancelled (which is ignored internally)
      await webAuth.logout(returnTo: 'myapp://home');

      final url = browser.lastLaunchedUrl!;
      expect(url, contains('/v2/logout'));
      expect(url, contains('client_id=test_client'));
    });
  });

  group('WebAuth.buildAuthorizeUrl() + handleCallback()', () {
    test('redirect flow works end-to-end', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'access_token': 'redirect_at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        httpClient: mock,
      );
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final webAuth = WebAuth(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        api: api,
        browser: mockBrowser,
      );

      final authorizeUrl = webAuth.buildAuthorizeUrl(
        redirectUrl: 'https://myapp.com/callback',
        audience: 'https://api.example.com',
      );

      expect(authorizeUrl.host, 'test.auth0.com');
      expect(authorizeUrl.path, '/authorize');
      expect(authorizeUrl.queryParameters['response_type'], 'code');
      expect(authorizeUrl.queryParameters['code_challenge_method'], 'S256');

      // Extract state from the URL to build a matching callback
      final state = authorizeUrl.queryParameters['state']!;

      final callbackUri = Uri.parse(
        'https://myapp.com/callback?code=redirect_code&state=$state',
      );

      final creds = await webAuth.handleCallback(callbackUri);
      expect(creds.accessToken, 'redirect_at');
    });

    test('handleCallback throws stateMismatch on wrong state', () async {
      final mock = MockClient((_) async => http.Response('{}', 200));
      httpClient = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        httpClient: mock,
      );
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final webAuth = WebAuth(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        api: api,
        browser: mockBrowser,
      );

      webAuth.buildAuthorizeUrl(redirectUrl: 'https://myapp.com/callback');

      final callbackUri = Uri.parse(
        'https://myapp.com/callback?code=code&state=wrong_state',
      );

      expect(
        () => webAuth.handleCallback(callbackUri),
        throwsA(isA<WebAuthException>().having(
          (e) => e.isStateMismatch,
          'isStateMismatch',
          true,
        )),
      );
    });

    test('handleCallback throws when no pending auth', () async {
      final webAuth = WebAuth(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        api: AuthApi(
          client: Auth0HttpClient(
            domain: 'test.auth0.com',
            clientId: 'test_client',
            httpClient: MockClient((_) async => http.Response('{}', 200)),
          ),
          clientId: 'test_client',
        ),
        browser: mockBrowser,
      );

      expect(
        () => webAuth.handleCallback(Uri.parse('https://app.com/callback?code=c&state=s')),
        throwsA(isA<WebAuthException>()),
      );
    });
  });
}

/// A mock browser that extracts the state param from the launched URL
/// and returns a callback URL with that state + a given code.
class _StatefulMockBrowser extends BrowserPlatform {
  final String code;
  String? lastLaunchedUrl;

  _StatefulMockBrowser({required this.code});

  @override
  Future<String> launchAuth({
    required String url,
    required String callbackScheme,
    bool preferEphemeral = false,
  }) async {
    lastLaunchedUrl = url;
    final uri = Uri.parse(url);
    final state = uri.queryParameters['state'] ?? '';
    return '$callbackScheme://callback?code=$code&state=$state';
  }

  @override
  Future<void> cancel() async {}
}

/// A mock browser that returns an error callback.
class _ErrorCallbackBrowser extends BrowserPlatform {
  final String error;
  final String description;

  _ErrorCallbackBrowser({required this.error, required this.description});

  @override
  Future<String> launchAuth({
    required String url,
    required String callbackScheme,
    bool preferEphemeral = false,
  }) async {
    final uri = Uri.parse(url);
    final state = uri.queryParameters['state'] ?? '';
    return '$callbackScheme://callback?error=$error&error_description=$description&state=$state';
  }

  @override
  Future<void> cancel() async {}
}
