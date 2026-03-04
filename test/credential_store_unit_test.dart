import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/types/auth_messages.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

// ---------------------------------------------------------------------------
// Fake FlutterSecureStorage — in-memory storage for unit tests
// ---------------------------------------------------------------------------
class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }
}

// ---------------------------------------------------------------------------
// Fake LocalAuthentication
// ---------------------------------------------------------------------------
class _FakeLocalAuth extends Fake implements LocalAuthentication {
  bool canCheckBiometricsResult = true;
  bool authenticateResult = true;
  int authenticateCallCount = 0;

  @override
  Future<bool> get canCheckBiometrics =>
      Future.value(canCheckBiometricsResult);

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    authenticateCallCount++;
    return authenticateResult;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Credentials _validCredentials({String? refreshToken = 'rt'}) => Credentials(
      accessToken: 'at',
      tokenType: 'Bearer',
      idToken: 'idt',
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      scopes: {'openid', 'profile'},
    );

Credentials _expiredCredentials({String? refreshToken = 'rt'}) => Credentials(
      accessToken: 'old_at',
      tokenType: 'Bearer',
      refreshToken: refreshToken,
      expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      scopes: {'openid'},
    );

Credentials _soonExpiringCredentials({int secondsLeft = 30}) => Credentials(
      accessToken: 'soon_at',
      tokenType: 'Bearer',
      refreshToken: 'rt',
      expiresAt: DateTime.now().add(Duration(seconds: secondsLeft)),
      scopes: {'openid'},
    );

AuthApi _buildApi({
  Map<String, dynamic> Function(http.Request)? onRequest,
}) {
  final mock = MockClient((request) async {
    if (onRequest != null) {
      final response = onRequest(request);
      return http.Response(jsonEncode(response), 200);
    }
    // Default: return refreshed credentials
    return http.Response(
      jsonEncode({
        'access_token': 'refreshed_at',
        'token_type': 'Bearer',
        'refresh_token': 'new_rt',
        'expires_in': 3600,
        'scope': 'openid profile',
      }),
      200,
    );
  });
  final httpClient = Auth0HttpClient(
    domain: 'test.auth0.com',
    clientId: 'test',
    httpClient: mock,
  );
  return AuthApi(client: httpClient, clientId: 'test');
}

void main() {
  late _FakeSecureStorage storage;
  late _FakeLocalAuth localAuth;

  setUp(() {
    storage = _FakeSecureStorage();
    localAuth = _FakeLocalAuth();
  });

  // -------------------------------------------------------------------------
  // storeCredentials + getCredentials
  // -------------------------------------------------------------------------

  group('CredentialStore — store and get', () {
    test('storeCredentials + getCredentials round-trips', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      final creds = _validCredentials();
      await store.storeCredentials(creds);

      final retrieved = await store.getCredentials();
      expect(retrieved, isNotNull);
      expect(retrieved!.accessToken, creds.accessToken);
      expect(retrieved.refreshToken, creds.refreshToken);
      expect(retrieved.scopes, creds.scopes);
    });

    test('getCredentials returns null when empty', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      final result = await store.getCredentials();
      expect(result, isNull);
    });

    test('getCredentials returns stored credentials when valid', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());
      final result = await store.getCredentials();
      expect(result, isNotNull);
      expect(result!.accessToken, 'at');
    });
  });

  // -------------------------------------------------------------------------
  // Auto-refresh
  // -------------------------------------------------------------------------

  group('CredentialStore — auto-refresh', () {
    test('getCredentials refreshes expired credentials with refresh token',
        () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_expiredCredentials());
      final result = await store.getCredentials();
      expect(result, isNotNull);
      expect(result!.accessToken, 'refreshed_at');
    });

    test('getCredentials throws when expired and no refresh token', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_expiredCredentials(refreshToken: null));

      expect(
        () => store.getCredentials(),
        throwsA(isA<CredentialStoreException>().having(
          (e) => e.isNoRefreshToken,
          'isNoRefreshToken',
          true,
        )),
      );
    });

    test('getCredentials refreshes when scopes do not match', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());

      // Request a scope not in stored credentials
      final result = await store.getCredentials(scopes: {'openid', 'email'});
      expect(result, isNotNull);
      expect(result!.accessToken, 'refreshed_at');
    });

    test('getCredentials refreshes when minTtl exceeds remaining lifetime',
        () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      // Token expires in 30 seconds
      await store.storeCredentials(_soonExpiringCredentials(secondsLeft: 30));

      // Request with minTtl of 60 seconds — should trigger refresh
      final result = await store.getCredentials(minTtl: 60);
      expect(result, isNotNull);
      expect(result!.accessToken, 'refreshed_at');
    });

    test('getCredentials does not refresh when minTtl is within lifetime',
        () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());

      // minTtl is within the 1-hour lifetime
      final result = await store.getCredentials(minTtl: 10);
      expect(result, isNotNull);
      expect(result!.accessToken, 'at'); // Original, not refreshed
    });
  });

  // -------------------------------------------------------------------------
  // clearCredentials
  // -------------------------------------------------------------------------

  group('CredentialStore — clear', () {
    test('clearCredentials removes data', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());
      expect(await store.getCredentials(), isNotNull);

      await store.clearCredentials();
      expect(await store.getCredentials(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // revokeAndClearCredentials
  // -------------------------------------------------------------------------

  group('CredentialStore — revokeAndClearCredentials', () {
    test('calls revokeToken then clears', () async {
      var revokeCalled = false;
      final mock = MockClient((request) async {
        if (request.url.path == '/oauth/revoke') {
          revokeCalled = true;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['token'], 'rt');
        }
        return http.Response(jsonEncode({}), 200);
      });
      final httpClient = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'test',
        httpClient: mock,
      );
      final api = AuthApi(client: httpClient, clientId: 'test');

      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());
      await store.revokeAndClearCredentials();

      expect(revokeCalled, true);
      expect(await store.getCredentials(), isNull);
    });

    test('clears even when no refresh token exists', () async {
      var revokeCalled = false;
      final mock = MockClient((request) async {
        if (request.url.path == '/oauth/revoke') {
          revokeCalled = true;
        }
        return http.Response(jsonEncode({}), 200);
      });
      final httpClient = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'test',
        httpClient: mock,
      );
      final api = AuthApi(client: httpClient, clientId: 'test');

      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials(refreshToken: null));
      await store.revokeAndClearCredentials();

      expect(revokeCalled, false);
      expect(await store.getCredentials(), isNull);
    });

    test('clears even when no credentials stored', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      // Should not throw
      await store.revokeAndClearCredentials();
      expect(await store.getCredentials(), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // hasValidCredentials
  // -------------------------------------------------------------------------

  group('CredentialStore — hasValidCredentials', () {
    test('returns true when valid and not expired', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());
      expect(await store.hasValidCredentials(), true);
    });

    test('returns false when empty', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      expect(await store.hasValidCredentials(), false);
    });

    test('returns true when expired but refresh token exists', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_expiredCredentials());
      expect(await store.hasValidCredentials(), true);
    });

    test('returns false when expired and no refresh token', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_expiredCredentials(refreshToken: null));
      expect(await store.hasValidCredentials(), false);
    });

    test('returns true when minTtl is within lifetime', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());
      expect(await store.hasValidCredentials(minTtl: 10), true);
    });

    test('returns true when minTtl exceeds lifetime but has refresh token',
        () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_soonExpiringCredentials(secondsLeft: 30));
      expect(await store.hasValidCredentials(minTtl: 60), true);
    });
  });

  // -------------------------------------------------------------------------
  // renewCredentials
  // -------------------------------------------------------------------------

  group('CredentialStore — renewCredentials', () {
    test('throws when no credentials stored', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      expect(
        () => store.renewCredentials(),
        throwsA(isA<CredentialStoreException>().having(
          (e) => e.isNoCredentials,
          'isNoCredentials',
          true,
        )),
      );
    });

    test('throws when no refresh token', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials(refreshToken: null));

      expect(
        () => store.renewCredentials(),
        throwsA(isA<CredentialStoreException>().having(
          (e) => e.isNoRefreshToken,
          'isNoRefreshToken',
          true,
        )),
      );
    });

    test('returns refreshed credentials and stores them', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());
      final result = await store.renewCredentials();
      expect(result.accessToken, 'refreshed_at');

      // Verify stored
      final stored = await store.getCredentials();
      expect(stored!.accessToken, 'refreshed_at');
    });
  });

  // -------------------------------------------------------------------------
  // onCredentialsChanged stream
  // -------------------------------------------------------------------------

  group('CredentialStore — onCredentialsChanged', () {
    test('emits credentials on store', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      final events = <Credentials?>[];
      store.onCredentialsChanged.listen(events.add);

      await store.storeCredentials(_validCredentials());
      await Future<void>.delayed(Duration.zero); // Let stream deliver

      expect(events.length, 1);
      expect(events.first!.accessToken, 'at');
    });

    test('emits null on clear', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      final events = <Credentials?>[];
      store.onCredentialsChanged.listen(events.add);

      await store.storeCredentials(_validCredentials());
      await store.clearCredentials();
      await Future<void>.delayed(Duration.zero);

      expect(events.length, 2);
      expect(events[0]!.accessToken, 'at');
      expect(events[1], isNull);
    });
  });

  // -------------------------------------------------------------------------
  // user()
  // -------------------------------------------------------------------------

  group('CredentialStore — user()', () {
    test('returns null when no credentials stored', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      expect(await store.user(), isNull);
    });

    test('returns null when no idToken', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(Credentials(
        accessToken: 'at',
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));

      expect(await store.user(), isNull);
    });

    test('extracts user profile from valid idToken', () async {
      // Build a minimal JWT with sub claim
      final header = base64Url.encode(utf8.encode('{"alg":"RS256","typ":"JWT"}'));
      final payload = base64Url.encode(utf8.encode(jsonEncode({
        'sub': 'auth0|user123',
        'name': 'Test User',
        'email': 'test@example.com',
      })));
      final fakeSig = base64Url.encode(utf8.encode('not-a-real-sig'));
      final idToken = '$header.$payload.$fakeSig';

      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(Credentials(
        accessToken: 'at',
        tokenType: 'Bearer',
        idToken: idToken,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ));

      final user = await store.user();
      expect(user, isNotNull);
      expect(user!.sub, 'auth0|user123');
      expect(user.name, 'Test User');
    });
  });

  // -------------------------------------------------------------------------
  // Biometric policies
  // -------------------------------------------------------------------------

  group('CredentialStore — biometric policies', () {
    test('BiometricPolicy.disabled does not prompt', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        options: const CredentialStoreOptions(
          biometricPolicy: BiometricPolicy.disabled,
        ),
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());
      await store.getCredentials();

      expect(localAuth.authenticateCallCount, 0);
    });

    test('BiometricPolicy.always prompts every time', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        options: const CredentialStoreOptions(
          biometricPolicy: BiometricPolicy.always,
        ),
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());
      await store.getCredentials();
      await store.getCredentials();
      await store.getCredentials();

      expect(localAuth.authenticateCallCount, 3);
    });

    test('BiometricPolicy.appLifecycle prompts once then skips', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        options: const CredentialStoreOptions(
          biometricPolicy: BiometricPolicy.appLifecycle,
        ),
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());
      await store.getCredentials();
      await store.getCredentials();
      await store.getCredentials();

      expect(localAuth.authenticateCallCount, 1);
    });

    test('BiometricPolicy.appLifecycle re-prompts after resetBiometricSession',
        () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        options: const CredentialStoreOptions(
          biometricPolicy: BiometricPolicy.appLifecycle,
        ),
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());
      await store.getCredentials(); // prompts (1)
      await store.getCredentials(); // skips

      store.resetBiometricSession();

      await store.getCredentials(); // prompts again (2)

      expect(localAuth.authenticateCallCount, 2);
    });

    test('BiometricPolicy.session skips within timeout', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        options: const CredentialStoreOptions(
          biometricPolicy: BiometricPolicy.session,
          biometricSessionTimeout: 300, // 5 minutes
        ),
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());
      await store.getCredentials(); // prompts (1)
      await store.getCredentials(); // skips — within timeout

      expect(localAuth.authenticateCallCount, 1);
    });

    test('legacy requireBiometrics: true still triggers prompt', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        options: const CredentialStoreOptions(
          requireBiometrics: true,
        ),
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());
      await store.getCredentials();
      await store.getCredentials();

      // Legacy mode: prompts every time (like always)
      expect(localAuth.authenticateCallCount, 2);
    });

    test('biometric failure throws CredentialStoreException', () async {
      localAuth.authenticateResult = false;
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        options: const CredentialStoreOptions(
          biometricPolicy: BiometricPolicy.always,
        ),
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());

      expect(
        () => store.getCredentials(),
        throwsA(isA<CredentialStoreException>().having(
          (e) => e.isBiometricFailed,
          'isBiometricFailed',
          true,
        )),
      );
    });

    test('biometrics skipped when hardware unavailable', () async {
      localAuth.canCheckBiometricsResult = false;
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        options: const CredentialStoreOptions(
          biometricPolicy: BiometricPolicy.always,
        ),
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials());
      final result = await store.getCredentials();

      // Should succeed without prompting since biometrics unavailable
      expect(result, isNotNull);
      expect(localAuth.authenticateCallCount, 0);
    });
  });

  // -------------------------------------------------------------------------
  // ssoCredentials
  // -------------------------------------------------------------------------

  group('CredentialStore — ssoCredentials', () {
    test('throws when no credentials stored', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      expect(
        () => store.ssoCredentials(),
        throwsA(isA<CredentialStoreException>().having(
          (e) => e.isNoCredentials,
          'isNoCredentials',
          true,
        )),
      );
    });

    test('throws when no refresh token', () async {
      final api = _buildApi();
      final store = CredentialStore(
        api: api,
        storage: storage,
        localAuth: localAuth,
      );

      await store.storeCredentials(_validCredentials(refreshToken: null));

      expect(
        () => store.ssoCredentials(),
        throwsA(isA<CredentialStoreException>().having(
          (e) => e.isNoRefreshToken,
          'isNoRefreshToken',
          true,
        )),
      );
    });
  });
}
