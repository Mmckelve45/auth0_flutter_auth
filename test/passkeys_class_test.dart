import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';
import 'package:auth0_flutter_auth/src/passkeys/passkeys_platform.dart';

// ---------------------------------------------------------------------------
// Mock PasskeysPlatform — returns WebAuthn-style JSON responses.
// ---------------------------------------------------------------------------
class _MockPasskeysPlatform extends PasskeysPlatform {
  bool registerCalled = false;
  bool authenticateCalled = false;
  bool isAvailableCalled = false;
  String? lastOptionsJson;
  bool available = true;

  /// If non-null, [register] will throw this instead of returning.
  PasskeyException? registerError;

  /// If non-null, [authenticate] will throw this instead of returning.
  PasskeyException? authenticateError;

  final Map<String, dynamic> _registerResponse = {
    'id': 'cred-id-abc',
    'rawId': 'cmF3SWQ',
    'type': 'public-key',
    'response': {
      'attestationObject': 'YXR0ZXN0',
      'clientDataJSON': 'Y2xpZW50',
    },
  };

  final Map<String, dynamic> _authenticateResponse = {
    'id': 'cred-id-abc',
    'rawId': 'cmF3SWQ',
    'type': 'public-key',
    'response': {
      'authenticatorData': 'YXV0aA',
      'clientDataJSON': 'Y2xpZW50',
      'signature': 'c2lnbg',
    },
  };

  @override
  Future<String> register(String optionsJson) async {
    registerCalled = true;
    lastOptionsJson = optionsJson;
    if (registerError != null) throw registerError!;
    return jsonEncode(_registerResponse);
  }

  @override
  Future<String> authenticate(String optionsJson) async {
    authenticateCalled = true;
    lastOptionsJson = optionsJson;
    if (authenticateError != null) throw authenticateError!;
    return jsonEncode(_authenticateResponse);
  }

  @override
  Future<bool> isAvailable() async {
    isAvailableCalled = true;
    return available;
  }
}

// ---------------------------------------------------------------------------
// Mock AuthApi — stubs passkey-related endpoints.
// ---------------------------------------------------------------------------
class _MockAuthApi extends AuthApi {
  _MockAuthApi()
      : super(
          client: Auth0HttpClient(
            domain: 'test.auth0.com',
            clientId: 'test_client_id',
          ),
          clientId: 'test_client_id',
        );

  PasskeyChallenge? registerChallengeResult;
  PasskeyChallenge? loginChallengeResult;
  PasskeyChallenge? enrollmentChallengeResult;
  Credentials? authenticateResult;
  bool verifyEnrollmentCalled = false;

  ApiException? registerChallengeError;
  ApiException? loginChallengeError;
  ApiException? authenticateError;
  ApiException? enrollmentChallengeError;
  ApiException? verifyEnrollmentError;

  String? lastAuthSession;
  Map<String, dynamic>? lastAuthnResponse;
  String? lastAudience;
  Set<String>? lastScopes;
  String? lastEmail;
  String? lastName;
  String? lastRealm;
  String? lastAccessToken;

  @override
  Future<PasskeyChallenge> passkeyRegisterChallenge({
    required String email,
    String? name,
    String? realm,
  }) async {
    lastEmail = email;
    lastName = name;
    lastRealm = realm;
    if (registerChallengeError != null) throw registerChallengeError!;
    return registerChallengeResult!;
  }

  @override
  Future<PasskeyChallenge> passkeyLoginChallenge({String? realm}) async {
    lastRealm = realm;
    if (loginChallengeError != null) throw loginChallengeError!;
    return loginChallengeResult!;
  }

  @override
  Future<Credentials> authenticateWithPasskey({
    required String authSession,
    required Map<String, dynamic> authnResponse,
    String? audience,
    Set<String> scopes = const {},
  }) async {
    lastAuthSession = authSession;
    lastAuthnResponse = authnResponse;
    lastAudience = audience;
    lastScopes = scopes;
    if (authenticateError != null) throw authenticateError!;
    return authenticateResult!;
  }

  @override
  Future<PasskeyChallenge> passkeyEnrollmentChallenge({
    required String accessToken,
  }) async {
    lastAccessToken = accessToken;
    if (enrollmentChallengeError != null) throw enrollmentChallengeError!;
    return enrollmentChallengeResult!;
  }

  @override
  Future<void> verifyPasskeyEnrollment({
    required String authSession,
    required Map<String, dynamic> authnResponse,
  }) async {
    verifyEnrollmentCalled = true;
    lastAuthSession = authSession;
    lastAuthnResponse = authnResponse;
    if (verifyEnrollmentError != null) throw verifyEnrollmentError!;
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

PasskeyChallenge _challenge({String session = 'test-session'}) {
  return PasskeyChallenge(
    authnParamsPublicKey: {
      'challenge': 'Y2hhbGxlbmdl',
      'rp': {'id': 'test.auth0.com', 'name': 'Test'},
      'user': {'id': 'dXNlcjE', 'name': 'user@test.com'},
      'timeout': 60000,
    },
    authSession: session,
  );
}

Credentials _credentials() {
  return Credentials(
    accessToken: 'passkey_at',
    tokenType: 'Bearer',
    idToken: 'passkey_idt',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    scopes: {'openid', 'profile'},
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockPasskeysPlatform mockPlatform;
  late _MockAuthApi mockApi;
  late Passkeys passkeys;

  setUp(() {
    mockPlatform = _MockPasskeysPlatform();
    mockApi = _MockAuthApi();
    passkeys = Passkeys(api: mockApi, platform: mockPlatform);
  });

  // -------------------------------------------------------------------------
  // isAvailable
  // -------------------------------------------------------------------------
  group('isAvailable', () {
    test('delegates to platform', () async {
      mockPlatform.available = true;
      expect(await passkeys.isAvailable(), isTrue);
      expect(mockPlatform.isAvailableCalled, isTrue);
    });

    test('returns false when platform says unavailable', () async {
      mockPlatform.available = false;
      expect(await passkeys.isAvailable(), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // signup
  // -------------------------------------------------------------------------
  group('signup', () {
    test('full flow: challenge → register → authenticate', () async {
      mockApi.registerChallengeResult = _challenge(session: 'signup-sess');
      mockApi.authenticateResult = _credentials();

      final creds = await passkeys.signup(
        email: 'new@user.com',
        name: 'New User',
        realm: 'Username-Password-Authentication',
        audience: 'https://api.example.com',
        scopes: {'openid', 'profile'},
      );

      // Verify API was called with correct params
      expect(mockApi.lastEmail, 'new@user.com');
      expect(mockApi.lastName, 'New User');
      expect(mockApi.lastRealm, 'Username-Password-Authentication');

      // Verify platform received the challenge options as JSON
      expect(mockPlatform.registerCalled, isTrue);
      final sentOptions = jsonDecode(mockPlatform.lastOptionsJson!)
          as Map<String, dynamic>;
      expect(sentOptions['challenge'], 'Y2hhbGxlbmdl');
      expect(sentOptions['rp']['id'], 'test.auth0.com');

      // Verify authenticate was called with auth session + platform response
      expect(mockApi.lastAuthSession, 'signup-sess');
      expect(mockApi.lastAuthnResponse, isNotNull);
      expect(mockApi.lastAuthnResponse!['type'], 'public-key');
      expect(mockApi.lastAudience, 'https://api.example.com');
      expect(mockApi.lastScopes, {'openid', 'profile'});

      // Verify we got credentials back
      expect(creds.accessToken, 'passkey_at');
    });

    test('passes through API exception from register challenge', () async {
      mockApi.registerChallengeError = ApiException(
        message: 'Passkeys not enabled',
        statusCode: 403,
        errorCode: 'access_denied',
      );

      expect(
        () => passkeys.signup(email: 'user@test.com'),
        throwsA(isA<ApiException>()),
      );
      expect(mockPlatform.registerCalled, isFalse);
    });

    test('passes through platform cancellation', () async {
      mockApi.registerChallengeResult = _challenge();
      mockPlatform.registerError = PasskeyException.cancelled();

      expect(
        () => passkeys.signup(email: 'user@test.com'),
        throwsA(isA<PasskeyException>().having(
          (e) => e.isCancelled,
          'isCancelled',
          isTrue,
        )),
      );
    });

    test('passes through platform registration failure', () async {
      mockApi.registerChallengeResult = _challenge();
      mockPlatform.registerError = PasskeyException.registrationFailed();

      expect(
        () => passkeys.signup(email: 'user@test.com'),
        throwsA(isA<PasskeyException>().having(
          (e) => e.isRegistrationFailed,
          'isRegistrationFailed',
          isTrue,
        )),
      );
    });

    test('passes through API exception from authenticate', () async {
      mockApi.registerChallengeResult = _challenge();
      mockApi.authenticateError = ApiException(
        message: 'Token exchange failed',
        statusCode: 400,
        errorCode: 'invalid_grant',
      );

      try {
        await passkeys.signup(email: 'user@test.com');
        fail('Should have thrown');
      } on ApiException {
        // Expected
      }
      // Platform register was called before the API authenticate error
      expect(mockPlatform.registerCalled, isTrue);
    });

    test('works with minimal parameters', () async {
      mockApi.registerChallengeResult = _challenge();
      mockApi.authenticateResult = _credentials();

      final creds = await passkeys.signup(email: 'minimal@test.com');

      expect(mockApi.lastEmail, 'minimal@test.com');
      expect(mockApi.lastName, isNull);
      expect(mockApi.lastRealm, isNull);
      expect(mockApi.lastAudience, isNull);
      expect(creds.accessToken, 'passkey_at');
    });
  });

  // -------------------------------------------------------------------------
  // login
  // -------------------------------------------------------------------------
  group('login', () {
    test('full flow: challenge → authenticate → credentials', () async {
      mockApi.loginChallengeResult = _challenge(session: 'login-sess');
      mockApi.authenticateResult = _credentials();

      final creds = await passkeys.login(
        realm: 'my-realm',
        audience: 'https://api.example.com',
        scopes: {'openid', 'email'},
      );

      expect(mockApi.lastRealm, 'my-realm');

      // Platform should have been called with authenticate (not register)
      expect(mockPlatform.authenticateCalled, isTrue);
      expect(mockPlatform.registerCalled, isFalse);

      // Auth session forwarded correctly
      expect(mockApi.lastAuthSession, 'login-sess');
      expect(mockApi.lastAudience, 'https://api.example.com');
      expect(mockApi.lastScopes, {'openid', 'email'});

      expect(creds.accessToken, 'passkey_at');
    });

    test('passes through API exception from login challenge', () async {
      mockApi.loginChallengeError = ApiException(
        message: 'No passkeys found',
        statusCode: 404,
        errorCode: 'not_found',
      );

      expect(
        () => passkeys.login(),
        throwsA(isA<ApiException>()),
      );
      expect(mockPlatform.authenticateCalled, isFalse);
    });

    test('passes through platform assertion failure', () async {
      mockApi.loginChallengeResult = _challenge();
      mockPlatform.authenticateError = PasskeyException.assertionFailed();

      expect(
        () => passkeys.login(),
        throwsA(isA<PasskeyException>().having(
          (e) => e.isAssertionFailed,
          'isAssertionFailed',
          isTrue,
        )),
      );
    });

    test('passes through platform cancellation', () async {
      mockApi.loginChallengeResult = _challenge();
      mockPlatform.authenticateError = PasskeyException.cancelled();

      expect(
        () => passkeys.login(),
        throwsA(isA<PasskeyException>().having(
          (e) => e.isCancelled,
          'isCancelled',
          isTrue,
        )),
      );
    });

    test('works with no parameters', () async {
      mockApi.loginChallengeResult = _challenge();
      mockApi.authenticateResult = _credentials();

      final creds = await passkeys.login();

      expect(mockApi.lastRealm, isNull);
      expect(mockApi.lastAudience, isNull);
      expect(creds.accessToken, 'passkey_at');
    });
  });

  // -------------------------------------------------------------------------
  // enroll
  // -------------------------------------------------------------------------
  group('enroll', () {
    test('full flow: enrollment challenge → register → verify', () async {
      mockApi.enrollmentChallengeResult = _challenge(session: 'enroll-sess');

      await passkeys.enroll(accessToken: 'user_access_token');

      // API was called with the access token
      expect(mockApi.lastAccessToken, 'user_access_token');

      // Platform register was called (not authenticate)
      expect(mockPlatform.registerCalled, isTrue);
      expect(mockPlatform.authenticateCalled, isFalse);

      // Verify enrollment was called with correct params
      expect(mockApi.verifyEnrollmentCalled, isTrue);
      expect(mockApi.lastAuthSession, 'enroll-sess');
      expect(mockApi.lastAuthnResponse, isNotNull);
      expect(mockApi.lastAuthnResponse!['type'], 'public-key');
    });

    test('passes through API exception from enrollment challenge', () async {
      mockApi.enrollmentChallengeError = ApiException(
        message: 'Unauthorized',
        statusCode: 401,
        errorCode: 'unauthorized',
      );

      expect(
        () => passkeys.enroll(accessToken: 'bad_token'),
        throwsA(isA<ApiException>()),
      );
      expect(mockPlatform.registerCalled, isFalse);
    });

    test('passes through platform cancellation during enroll', () async {
      mockApi.enrollmentChallengeResult = _challenge();
      mockPlatform.registerError = PasskeyException.cancelled();

      expect(
        () => passkeys.enroll(accessToken: 'token'),
        throwsA(isA<PasskeyException>().having(
          (e) => e.isCancelled,
          'isCancelled',
          isTrue,
        )),
      );
      expect(mockApi.verifyEnrollmentCalled, isFalse);
    });

    test('passes through API exception from verify enrollment', () async {
      mockApi.enrollmentChallengeResult = _challenge();
      mockApi.verifyEnrollmentError = ApiException(
        message: 'Verification failed',
        statusCode: 400,
        errorCode: 'invalid_request',
      );

      try {
        await passkeys.enroll(accessToken: 'token');
        fail('Should have thrown');
      } on ApiException {
        // Expected
      }
      // Platform register was called before the API verify error
      expect(mockPlatform.registerCalled, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // WebAuthn response forwarding
  // -------------------------------------------------------------------------
  group('WebAuthn response handling', () {
    test('signup forwards full registration response to API', () async {
      mockApi.registerChallengeResult = _challenge();
      mockApi.authenticateResult = _credentials();

      await passkeys.signup(email: 'user@test.com');

      final response = mockApi.lastAuthnResponse!;
      expect(response['id'], 'cred-id-abc');
      expect(response['rawId'], 'cmF3SWQ');
      expect(response['type'], 'public-key');
      expect(response['response']['attestationObject'], 'YXR0ZXN0');
      expect(response['response']['clientDataJSON'], 'Y2xpZW50');
    });

    test('login forwards full assertion response to API', () async {
      mockApi.loginChallengeResult = _challenge();
      mockApi.authenticateResult = _credentials();

      await passkeys.login();

      final response = mockApi.lastAuthnResponse!;
      expect(response['id'], 'cred-id-abc');
      expect(response['type'], 'public-key');
      expect(response['response']['authenticatorData'], 'YXV0aA');
      expect(response['response']['signature'], 'c2lnbg');
    });

    test('challenge options JSON is passed verbatim to platform', () async {
      final customChallenge = PasskeyChallenge(
        authnParamsPublicKey: {
          'challenge': 'custom_challenge_value',
          'rp': {'id': 'custom.domain.com'},
          'pubKeyCredParams': [
            {'type': 'public-key', 'alg': -7},
          ],
        },
        authSession: 'sess',
      );
      mockApi.registerChallengeResult = customChallenge;
      mockApi.authenticateResult = _credentials();

      await passkeys.signup(email: 'user@test.com');

      final sentOptions = jsonDecode(mockPlatform.lastOptionsJson!)
          as Map<String, dynamic>;
      expect(sentOptions['challenge'], 'custom_challenge_value');
      expect(sentOptions['rp']['id'], 'custom.domain.com');
      expect(sentOptions['pubKeyCredParams'], isList);
    });
  });
}
