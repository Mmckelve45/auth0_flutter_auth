import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

void main() {
  late Auth0HttpClient httpClient;
  late AuthApi api;

  Auth0HttpClient createHttpClient(MockClient mock) {
    return Auth0HttpClient(
      domain: 'test.auth0.com',
      clientId: 'test_client',
      httpClient: mock,
    );
  }

  group('AuthApi', () {
    test('loginWithPassword sends correct grant_type and params', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'],
            'http://auth0.com/oauth/grant-type/password-realm');
        expect(body['client_id'], 'test_client');
        expect(body['username'], 'user@example.com');
        expect(body['password'], 'secret');
        expect(body['realm'], 'Username-Password-Authentication');
        return http.Response(
          jsonEncode({
            'access_token': 'at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.loginWithPassword(
        usernameOrEmail: 'user@example.com',
        password: 'secret',
        realm: 'Username-Password-Authentication',
      );
      expect(creds.accessToken, 'at');
    });

    test('exchangeCode sends authorization_code grant', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'], 'authorization_code');
        expect(body['code'], 'auth_code');
        expect(body['code_verifier'], 'verifier');
        expect(body['redirect_uri'], 'myapp://callback');
        return http.Response(
          jsonEncode({
            'access_token': 'at',
            'token_type': 'Bearer',
            'id_token': 'idt',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.exchangeCode(
        code: 'auth_code',
        codeVerifier: 'verifier',
        redirectUrl: 'myapp://callback',
      );
      expect(creds.idToken, 'idt');
    });

    test('renewTokens sends refresh_token grant', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'], 'refresh_token');
        expect(body['refresh_token'], 'rt123');
        return http.Response(
          jsonEncode({
            'access_token': 'new_at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.renewTokens(refreshToken: 'rt123');
      expect(creds.accessToken, 'new_at');
    });

    test('verifyMfaOtp sends mfa-otp grant', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'],
            'http://auth0.com/oauth/grant-type/mfa-otp');
        expect(body['mfa_token'], 'mfa_tok');
        expect(body['otp'], '123456');
        return http.Response(
          jsonEncode({
            'access_token': 'at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.verifyMfaOtp(
        mfaToken: 'mfa_tok',
        otp: '123456',
      );
      expect(creds.accessToken, 'at');
    });

    test('getMfaChallenge returns Challenge', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.url.path, '/mfa/challenge');
        expect(body['mfa_token'], 'mfa_tok');
        return http.Response(
          jsonEncode({
            'challenge_type': 'oob',
            'oob_code': 'oob123',
            'binding_method': 'prompt',
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final challenge = await api.getMfaChallenge(mfaToken: 'mfa_tok');
      expect(challenge.challengeType, 'oob');
      expect(challenge.oobCode, 'oob123');
    });

    test('startPasswordlessEmail sends to /passwordless/start', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.url.path, '/passwordless/start');
        expect(body['connection'], 'email');
        expect(body['email'], 'user@example.com');
        expect(body['send'], 'code');
        return http.Response(jsonEncode({}), 200);
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      await api.startPasswordlessEmail(email: 'user@example.com');
    });

    test('startPasswordlessSms sends to /passwordless/start', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['connection'], 'sms');
        expect(body['phone_number'], '+1234567890');
        return http.Response(jsonEncode({}), 200);
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      await api.startPasswordlessSms(phoneNumber: '+1234567890');
    });

    test('loginWithEmailCode sends passwordless/otp with email realm',
        () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'],
            'http://auth0.com/oauth/grant-type/passwordless/otp');
        expect(body['realm'], 'email');
        expect(body['username'], 'user@example.com');
        expect(body['otp'], '1234');
        return http.Response(
          jsonEncode({
            'access_token': 'at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.loginWithEmailCode(
        email: 'user@example.com',
        code: '1234',
      );
      expect(creds.accessToken, 'at');
    });

    test('loginWithSmsCode sends passwordless/otp with sms realm', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['realm'], 'sms');
        expect(body['username'], '+1234567890');
        return http.Response(
          jsonEncode({
            'access_token': 'at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.loginWithSmsCode(
        phoneNumber: '+1234567890',
        code: '5678',
      );
      expect(creds.accessToken, 'at');
    });

    test('signup posts to /dbconnections/signup', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/dbconnections/signup');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'new@example.com');
        expect(body['password'], 'P@ssw0rd');
        expect(body['connection'], 'Username-Password-Authentication');
        return http.Response(
          jsonEncode({
            '_id': 'abc123',
            'email': 'new@example.com',
            'email_verified': false,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final user = await api.signup(
        email: 'new@example.com',
        password: 'P@ssw0rd',
        connection: 'Username-Password-Authentication',
      );
      expect(user.email, 'new@example.com');
      expect(user.id, 'abc123');
    });

    test('getUserInfo calls GET /userinfo with Bearer token', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/userinfo');
        expect(request.headers['Authorization'], 'Bearer access_tok');
        return http.Response(
          jsonEncode({
            'sub': 'auth0|user1',
            'name': 'Test User',
            'email': 'test@example.com',
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final profile = await api.getUserInfo(accessToken: 'access_tok');
      expect(profile.sub, 'auth0|user1');
      expect(profile.name, 'Test User');
    });

    test('resetPassword posts to /dbconnections/change_password', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/dbconnections/change_password');
        return http.Response('', 200);
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      await api.resetPassword(
        email: 'user@example.com',
        connection: 'Username-Password-Authentication',
      );
    });

    test('customTokenExchange sends token-exchange grant', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'],
            'urn:ietf:params:oauth:grant-type:token-exchange');
        expect(body['subject_token'], 'sub_tok');
        expect(body['subject_token_type'], 'urn:ietf:params:oauth:token-type:jwt');
        return http.Response(
          jsonEncode({
            'access_token': 'exchanged_at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.customTokenExchange(
        subjectToken: 'sub_tok',
        subjectTokenType: 'urn:ietf:params:oauth:token-type:jwt',
      );
      expect(creds.accessToken, 'exchanged_at');
    });

    test('ssoExchange sends sso-exchange-refresh-token grant', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'],
            'http://auth0.com/oauth/grant-type/sso-exchange-refresh-token');
        expect(body['refresh_token'], 'sso_rt');
        return http.Response(
          jsonEncode({
            'access_token': 'sso_at',
            'token_type': 'Bearer',
            'expires_in': 7200,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.ssoExchange(refreshToken: 'sso_rt');
      expect(creds.accessToken, 'sso_at');
    });

    test('loginWithPassword includes optional audience and scopes', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['audience'], 'https://api.example.com');
        expect(body['scope'], 'openid profile');
        return http.Response(
          jsonEncode({
            'access_token': 'at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      await api.loginWithPassword(
        usernameOrEmail: 'user@example.com',
        password: 'secret',
        realm: 'Username-Password-Authentication',
        audience: 'https://api.example.com',
        scopes: {'openid', 'profile'},
      );
    });

    test('renewTokens includes extra parameters', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['custom_param'], 'value');
        return http.Response(
          jsonEncode({
            'access_token': 'at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      await api.renewTokens(
        refreshToken: 'rt',
        parameters: {'custom_param': 'value'},
      );
    });

    test('passkeyRegisterChallenge sends to /passkey/register', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/passkey/register');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['client_id'], 'test_client');
        expect(body['email'], 'user@example.com');
        expect(body['name'], 'Test User');
        return http.Response(
          jsonEncode({
            'authn_params_public_key': {
              'challenge': 'ch1',
              'rp': {'id': 'example.auth0.com'},
            },
            'auth_session': 'sess_register',
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final challenge = await api.passkeyRegisterChallenge(
        email: 'user@example.com',
        name: 'Test User',
      );
      expect(challenge.authSession, 'sess_register');
      expect(challenge.authnParamsPublicKey['challenge'], 'ch1');
    });

    test('passkeyLoginChallenge sends to /passkey/challenge', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/passkey/challenge');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['client_id'], 'test_client');
        return http.Response(
          jsonEncode({
            'authn_params_public_key': {
              'challenge': 'ch2',
              'rpId': 'example.auth0.com',
            },
            'auth_session': 'sess_login',
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final challenge = await api.passkeyLoginChallenge();
      expect(challenge.authSession, 'sess_login');
    });

    test('authenticateWithPasskey uses webauthn grant type', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'],
            'urn:okta:params:oauth:grant-type:webauthn');
        expect(body['client_id'], 'test_client');
        expect(body['auth_session'], 'sess1');
        expect(body['authn_response'], isA<Map>());
        return http.Response(
          jsonEncode({
            'access_token': 'passkey_at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.authenticateWithPasskey(
        authSession: 'sess1',
        authnResponse: {'id': 'cred1', 'type': 'public-key'},
      );
      expect(creds.accessToken, 'passkey_at');
    });

    test('passkeyEnrollmentChallenge sends Bearer token', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/me/v1/authentication-methods');
        expect(request.headers['Authorization'], 'Bearer my_token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['type'], 'public-key');
        return http.Response(
          jsonEncode({
            'authn_params_public_key': {'challenge': 'enroll_ch'},
            'auth_session': 'sess_enroll',
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final challenge =
          await api.passkeyEnrollmentChallenge(accessToken: 'my_token');
      expect(challenge.authSession, 'sess_enroll');
    });

    test('loginWithPassword throws ApiException on error', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Wrong credentials.',
          }),
          403,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      expect(
        () => api.loginWithPassword(
          usernameOrEmail: 'user@example.com',
          password: 'wrong',
          realm: 'Username-Password-Authentication',
        ),
        throwsA(isA<ApiException>().having(
          (e) => e.isInvalidCredentials,
          'isInvalidCredentials',
          true,
        )),
      );
    });
  });
}
