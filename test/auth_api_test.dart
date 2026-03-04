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

    test('verifyMfaOob sends mfa-oob grant', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'],
            'http://auth0.com/oauth/grant-type/mfa-oob');
        expect(body['client_id'], 'test_client');
        expect(body['mfa_token'], 'mfa_tok');
        expect(body['oob_code'], 'oob_123');
        expect(body.containsKey('binding_code'), false);
        return http.Response(
          jsonEncode({
            'access_token': 'oob_at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.verifyMfaOob(
        mfaToken: 'mfa_tok',
        oobCode: 'oob_123',
      );
      expect(creds.accessToken, 'oob_at');
    });

    test('verifyMfaOob includes optional bindingCode', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['oob_code'], 'oob_123');
        expect(body['binding_code'], '999888');
        return http.Response(
          jsonEncode({
            'access_token': 'oob_at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.verifyMfaOob(
        mfaToken: 'mfa_tok',
        oobCode: 'oob_123',
        bindingCode: '999888',
      );
      expect(creds.accessToken, 'oob_at');
    });

    test('verifyMfaRecoveryCode sends mfa-recovery-code grant', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'],
            'http://auth0.com/oauth/grant-type/mfa-recovery-code');
        expect(body['client_id'], 'test_client');
        expect(body['mfa_token'], 'mfa_tok');
        expect(body['recovery_code'], 'ABCD-EFGH-1234');
        return http.Response(
          jsonEncode({
            'access_token': 'recovery_at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.verifyMfaRecoveryCode(
        mfaToken: 'mfa_tok',
        recoveryCode: 'ABCD-EFGH-1234',
      );
      expect(creds.accessToken, 'recovery_at');
    });

    test('revokeToken posts to /oauth/revoke', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/oauth/revoke');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['client_id'], 'test_client');
        expect(body['token'], 'rt_to_revoke');
        return http.Response(jsonEncode({}), 200);
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      await api.revokeToken(refreshToken: 'rt_to_revoke');
    });

    test('loginWithAppleToken uses apple authz code subject token type',
        () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'],
            'urn:ietf:params:oauth:grant-type:token-exchange');
        expect(body['subject_token'], 'apple_auth_code');
        expect(body['subject_token_type'],
            'http://auth0.com/oauth/token-type/apple-authz-code');
        expect(body['audience'], 'https://api.example.com');
        return http.Response(
          jsonEncode({
            'access_token': 'apple_at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.loginWithAppleToken(
        authorizationCode: 'apple_auth_code',
        audience: 'https://api.example.com',
      );
      expect(creds.accessToken, 'apple_at');
    });

    test('loginWithFacebookToken uses facebook session access token type',
        () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'],
            'urn:ietf:params:oauth:grant-type:token-exchange');
        expect(body['subject_token'], 'fb_token');
        expect(body['subject_token_type'],
            'http://auth0.com/oauth/token-type/facebook-info-session-access-token');
        return http.Response(
          jsonEncode({
            'access_token': 'fb_at',
            'token_type': 'Bearer',
            'expires_in': 3600,
          }),
          200,
        );
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      final creds = await api.loginWithFacebookToken(
        accessToken: 'fb_token',
      );
      expect(creds.accessToken, 'fb_at');
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

    // -----------------------------------------------------------------------
    // Error handling per method
    // -----------------------------------------------------------------------

    test('verifyMfaOtp throws on invalid OTP', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_otp',
            'error_description': 'Invalid OTP code.',
          }),
          403,
        );
      });
      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      expect(
        () => api.verifyMfaOtp(mfaToken: 'mfa_tok', otp: 'wrong'),
        throwsA(isA<ApiException>().having(
          (e) => e.isMultifactorCodeInvalid,
          'isMultifactorCodeInvalid',
          true,
        )),
      );
    });

    test('verifyMfaOob throws on invalid OOB code', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_otp',
            'error_description': 'Invalid binding code.',
          }),
          403,
        );
      });
      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      expect(
        () => api.verifyMfaOob(mfaToken: 'mfa_tok', oobCode: 'bad'),
        throwsA(isA<ApiException>()),
      );
    });

    test('verifyMfaRecoveryCode throws on invalid recovery code', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Invalid recovery code.',
          }),
          403,
        );
      });
      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      expect(
        () => api.verifyMfaRecoveryCode(
          mfaToken: 'mfa_tok',
          recoveryCode: 'BAD-CODE',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('renewTokens throws on expired refresh token', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Refresh token has been revoked',
          }),
          403,
        );
      });
      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      await expectLater(
        () => api.renewTokens(refreshToken: 'expired_rt'),
        throwsA(isA<ApiException>().having(
          (e) => e.isRefreshTokenDeleted,
          'isRefreshTokenDeleted',
          true,
        )),
      );
    });

    test('exchangeCode throws on invalid code', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Invalid authorization code.',
          }),
          403,
        );
      });
      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      expect(
        () => api.exchangeCode(
          code: 'bad_code',
          codeVerifier: 'verifier',
          redirectUrl: 'myapp://callback',
        ),
        throwsA(isA<ApiException>().having(
          (e) => e.isInvalidCredentials,
          'isInvalidCredentials',
          true,
        )),
      );
    });

    test('revokeToken throws on server error', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'server_error',
            'error_description': 'Internal server error.',
          }),
          500,
        );
      });
      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      expect(
        () => api.revokeToken(refreshToken: 'rt'),
        throwsA(isA<ApiException>()),
      );
    });

    test('customTokenExchange throws on invalid subject token', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Invalid subject token.',
          }),
          403,
        );
      });
      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      expect(
        () => api.customTokenExchange(
          subjectToken: 'bad',
          subjectTokenType: 'urn:ietf:params:oauth:token-type:jwt',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('loginWithEmailCode throws on invalid code', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_otp',
            'error_description': 'Invalid verification code.',
          }),
          403,
        );
      });
      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      expect(
        () => api.loginWithEmailCode(
          email: 'user@example.com',
          code: 'wrong',
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('loginWithSmsCode throws on invalid code', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_otp',
            'error_description': 'Invalid verification code.',
          }),
          403,
        );
      });
      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      expect(
        () => api.loginWithSmsCode(phoneNumber: '+1234567890', code: 'wrong'),
        throwsA(isA<ApiException>()),
      );
    });

    test('signup throws on duplicate user', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'user_exists',
            'error_description': 'The user already exists.',
          }),
          409,
        );
      });
      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      expect(
        () => api.signup(
          email: 'existing@example.com',
          password: 'P@ssw0rd',
          connection: 'Username-Password-Authentication',
        ),
        throwsA(isA<ApiException>().having(
          (e) => e.isAlreadyExists,
          'isAlreadyExists',
          true,
        )),
      );
    });

    // -----------------------------------------------------------------------
    // MFA flow: login → mfa_required → extract mfaToken → challenge → verify
    // -----------------------------------------------------------------------

    test('loginWithPassword returns mfa_required with mfaToken', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'mfa_required',
            'error_description': 'Multifactor authentication required.',
            'mfa_token': 'mfa_tok_abc123',
          }),
          403,
        );
      });
      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      try {
        await api.loginWithPassword(
          usernameOrEmail: 'user@example.com',
          password: 'secret',
          realm: 'Username-Password-Authentication',
        );
        fail('Should have thrown');
      } on ApiException catch (e) {
        expect(e.isMultifactorRequired, true);
        expect(e.mfaToken, 'mfa_tok_abc123');
      }
    });

    test('full MFA OTP flow: login → mfa_required → challenge → verify',
        () async {
      var requestCount = 0;
      final mock = MockClient((request) async {
        requestCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        if (requestCount == 1) {
          // Step 1: loginWithPassword → mfa_required
          expect(body['grant_type'],
              'http://auth0.com/oauth/grant-type/password-realm');
          return http.Response(
            jsonEncode({
              'error': 'mfa_required',
              'error_description': 'Multifactor authentication required.',
              'mfa_token': 'mfa_tok_flow',
            }),
            403,
          );
        } else if (requestCount == 2) {
          // Step 2: getMfaChallenge
          expect(request.url.path, '/mfa/challenge');
          expect(body['mfa_token'], 'mfa_tok_flow');
          return http.Response(
            jsonEncode({
              'challenge_type': 'otp',
            }),
            200,
          );
        } else {
          // Step 3: verifyMfaOtp
          expect(body['grant_type'],
              'http://auth0.com/oauth/grant-type/mfa-otp');
          expect(body['mfa_token'], 'mfa_tok_flow');
          expect(body['otp'], '123456');
          return http.Response(
            jsonEncode({
              'access_token': 'final_at',
              'token_type': 'Bearer',
              'expires_in': 3600,
            }),
            200,
          );
        }
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      // Step 1: Login returns mfa_required
      String mfaToken;
      try {
        await api.loginWithPassword(
          usernameOrEmail: 'user@example.com',
          password: 'secret',
          realm: 'Username-Password-Authentication',
        );
        fail('Should have thrown');
      } on ApiException catch (e) {
        expect(e.isMultifactorRequired, true);
        mfaToken = e.mfaToken!;
      }

      // Step 2: Get challenge
      final challenge = await api.getMfaChallenge(mfaToken: mfaToken);
      expect(challenge.challengeType, 'otp');

      // Step 3: Verify OTP
      final creds = await api.verifyMfaOtp(
        mfaToken: mfaToken,
        otp: '123456',
      );
      expect(creds.accessToken, 'final_at');
      expect(requestCount, 3);
    });

    test('full MFA OOB flow: login → mfa_required → challenge → verify OOB',
        () async {
      var requestCount = 0;
      final mock = MockClient((request) async {
        requestCount++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;

        if (requestCount == 1) {
          return http.Response(
            jsonEncode({
              'error': 'mfa_required',
              'error_description': 'Multifactor authentication required.',
              'mfa_token': 'mfa_tok_oob',
            }),
            403,
          );
        } else if (requestCount == 2) {
          expect(request.url.path, '/mfa/challenge');
          return http.Response(
            jsonEncode({
              'challenge_type': 'oob',
              'oob_code': 'oob_code_123',
              'binding_method': 'prompt',
            }),
            200,
          );
        } else {
          expect(body['grant_type'],
              'http://auth0.com/oauth/grant-type/mfa-oob');
          expect(body['oob_code'], 'oob_code_123');
          expect(body['binding_code'], '999888');
          return http.Response(
            jsonEncode({
              'access_token': 'oob_final_at',
              'token_type': 'Bearer',
              'expires_in': 3600,
            }),
            200,
          );
        }
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      // Step 1
      String mfaToken;
      try {
        await api.loginWithPassword(
          usernameOrEmail: 'user@example.com',
          password: 'secret',
          realm: 'Username-Password-Authentication',
        );
        fail('Should have thrown');
      } on ApiException catch (e) {
        mfaToken = e.mfaToken!;
      }

      // Step 2
      final challenge = await api.getMfaChallenge(mfaToken: mfaToken);
      expect(challenge.challengeType, 'oob');
      expect(challenge.oobCode, 'oob_code_123');

      // Step 3
      final creds = await api.verifyMfaOob(
        mfaToken: mfaToken,
        oobCode: challenge.oobCode!,
        bindingCode: '999888',
      );
      expect(creds.accessToken, 'oob_final_at');
    });

    test('full MFA recovery flow: login → mfa_required → recovery code',
        () async {
      var requestCount = 0;
      final mock = MockClient((request) async {
        requestCount++;

        if (requestCount == 1) {
          return http.Response(
            jsonEncode({
              'error': 'mfa_required',
              'error_description': 'Multifactor authentication required.',
              'mfa_token': 'mfa_tok_recovery',
            }),
            403,
          );
        } else {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['grant_type'],
              'http://auth0.com/oauth/grant-type/mfa-recovery-code');
          expect(body['recovery_code'], 'ABCD-1234-EFGH');
          return http.Response(
            jsonEncode({
              'access_token': 'recovery_final_at',
              'token_type': 'Bearer',
              'expires_in': 3600,
            }),
            200,
          );
        }
      });

      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      String mfaToken;
      try {
        await api.loginWithPassword(
          usernameOrEmail: 'user@example.com',
          password: 'secret',
          realm: 'Username-Password-Authentication',
        );
        fail('Should have thrown');
      } on ApiException catch (e) {
        mfaToken = e.mfaToken!;
      }

      final creds = await api.verifyMfaRecoveryCode(
        mfaToken: mfaToken,
        recoveryCode: 'ABCD-1234-EFGH',
      );
      expect(creds.accessToken, 'recovery_final_at');
    });

    // -----------------------------------------------------------------------
    // Optional parameter coverage
    // -----------------------------------------------------------------------

    test('getMfaChallenge includes challengeType and authenticatorId',
        () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['challenge_type'], 'oob');
        expect(body['authenticator_id'], 'sms|dev_123');
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

      await api.getMfaChallenge(
        mfaToken: 'mfa_tok',
        challengeType: 'oob',
        authenticatorId: 'sms|dev_123',
      );
    });

    test('loginWithEmailCode includes audience and scopes', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['audience'], 'https://api.example.com');
        expect(body['scope'], contains('openid'));
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

      await api.loginWithEmailCode(
        email: 'user@example.com',
        code: '1234',
        audience: 'https://api.example.com',
        scopes: {'openid', 'profile'},
      );
    });

    test('customTokenExchange includes audience, scopes, organization',
        () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['audience'], 'https://api.example.com');
        expect(body['scope'], contains('openid'));
        expect(body['organization'], 'org_abc');
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

      await api.customTokenExchange(
        subjectToken: 'tok',
        subjectTokenType: 'urn:ietf:params:oauth:token-type:jwt',
        audience: 'https://api.example.com',
        scopes: {'openid'},
        organization: 'org_abc',
      );
    });

    test('signup includes username and userMetadata', () async {
      final mock = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['username'], 'johndoe');
        expect(body['user_metadata'], {'plan': 'premium'});
        return http.Response(
          jsonEncode({
            '_id': 'id1',
            'email': 'john@example.com',
            'email_verified': false,
          }),
          200,
        );
      });
      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      await api.signup(
        email: 'john@example.com',
        password: 'P@ssw0rd',
        connection: 'Username-Password-Authentication',
        username: 'johndoe',
        userMetadata: {'plan': 'premium'},
      );
    });

    test('getUserInfo with custom tokenType', () async {
      final mock = MockClient((request) async {
        expect(request.headers['Authorization'], 'DPoP access_tok');
        return http.Response(
          jsonEncode({
            'sub': 'auth0|user1',
            'name': 'Test',
          }),
          200,
        );
      });
      httpClient = createHttpClient(mock);
      api = AuthApi(client: httpClient, clientId: 'test_client');

      await api.getUserInfo(accessToken: 'access_tok', tokenType: 'DPoP');
    });
  });
}
