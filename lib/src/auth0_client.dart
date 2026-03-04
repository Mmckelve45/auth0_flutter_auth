import 'package:http/http.dart' as http;
import 'api/auth_api.dart';
import 'api/http_client.dart';
import 'auth0_client_options.dart';
import 'credentials/credential_store.dart';
import 'credentials/credential_store_options.dart';
import 'dpop/dpop.dart';
import 'passkeys/passkeys.dart';
import 'passkeys/passkeys_platform.dart';
import 'jwt/jwks_client.dart';
import 'jwt/jwt_validator.dart';
import 'models/credentials.dart';
import 'web_auth/web_auth.dart';

class Auth0Client {
  final String domain;
  final String clientId;
  final Auth0ClientOptions _options;

  late final Auth0HttpClient _httpClient;
  late final AuthApi _api;
  late final WebAuth _webAuth;
  late final CredentialStore _credentials;
  late final DPoP? _dpop;
  late final Passkeys? _passkeys;
  late final JwksClient _jwksClient;

  Auth0Client({
    required this.domain,
    required this.clientId,
    Auth0ClientOptions? options,
    http.Client? httpClient,
  }) : _options = options ?? const Auth0ClientOptions() {
    _httpClient = Auth0HttpClient(
      domain: domain,
      clientId: clientId,
      httpClient: httpClient,
      timeout: _options.httpTimeout,
    );

    _api = AuthApi(client: _httpClient, clientId: clientId);

    _jwksClient = JwksClient(domain: domain);

    final jwtValidator = JwtValidator(
      issuer: 'https://$domain/',
      audience: clientId,
      jwksClient: _jwksClient,
      leeway: _options.jwtLeeway ?? const Duration(seconds: 60),
    );

    _webAuth = WebAuth(
      domain: domain,
      clientId: clientId,
      api: _api,
      jwtValidator: jwtValidator,
    );

    _credentials = CredentialStore(
      api: _api,
      options: _options.credentialStoreOptions ?? const CredentialStoreOptions(),
    );

    _dpop = _options.enableDPoP ? DPoP() : null;

    _passkeys = _options.enablePasskeys
        ? Passkeys(api: _api, platform: PasskeysPlatform())
        : null;
  }

  AuthApi get api => _api;
  WebAuth get webAuth => _webAuth;
  CredentialStore get credentials => _credentials;
  DPoP? get dpop => _dpop;
  Passkeys? get passkeys => _passkeys;

  /// Stream that emits the current auth state immediately, then on every
  /// credential change.
  ///
  /// Emits [Credentials] when the user is authenticated, or `null` when not.
  /// The first emission reflects the current stored state (checking secure
  /// storage), so listeners always get an initial value — similar to
  /// Firebase's `authStateChanges()` or Supabase's `onAuthStateChange`.
  ///
  /// Works with any framework:
  /// ```dart
  /// // GoRouter — wrap in a ChangeNotifier / GoRouterRefreshStream
  /// // StreamBuilder — use directly
  /// // Riverpod — StreamProvider((_) => auth0.authStateChanges())
  /// // BLoC — emit states from the stream
  /// // Plain Navigator — listen and push/pop routes
  /// ```
  Stream<Credentials?> authStateChanges() async* {
    // Emit current state immediately (like a BehaviorSubject).
    Credentials? current;
    try {
      current = await _credentials.getCredentials();
    } catch (_) {
      current = null;
    }
    yield current;

    // Then forward all future changes from the credential store.
    yield* _credentials.onCredentialsChanged;
  }

  void close() {
    _credentials.dispose();
    _httpClient.close();
    _jwksClient.close();
  }
}
