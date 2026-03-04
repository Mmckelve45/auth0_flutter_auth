import 'dart:js_interop';

import '../exceptions/web_auth_exception.dart';
import '../models/credentials.dart';
import 'js_interop.dart';
import 'web_models.dart';

// ──────── Window / Location helpers ────────

@JS('window.location.search')
external JSString get _locationSearch;

@JS('window.location.origin')
external JSString get _locationOrigin;

@JS('window.location.pathname')
external JSString get _locationPathname;

@JS('window.history.replaceState')
external void _historyReplaceState(JSAny? data, JSString title, JSString url);

/// Optional adapter for auth0-spa-js on Flutter Web.
///
/// Provides popup login, silent token renewal, and session management by
/// wrapping the auth0-spa-js v2.1 JavaScript library via `dart:js_interop`.
///
/// To use this adapter, include `auth0-spa-js` in your `web/index.html`:
/// ```html
/// <script src="https://cdn.auth0.com/js/auth0-spa-js/2.1/auth0-spa-js.production.js"></script>
/// ```
///
/// Then import `package:auth0_flutter_auth/auth0_flutter_auth_web.dart`.
class Auth0SpaAdapter {
  Auth0ClientJS? _client;
  Object? _appState;

  /// Create and initialize the SPA client.
  ///
  /// Call once at app startup. If the current URL contains `code` and `state`
  /// query parameters (i.e. a redirect callback), they are exchanged for
  /// credentials automatically and the URL is cleaned up.
  ///
  /// Returns [Credentials] if a redirect callback was processed or if valid
  /// cached tokens exist; `null` otherwise.
  Future<Credentials?> onLoad({
    required String domain,
    required String clientId,
    String? redirectUri,
    String? audience,
    Set<String> scopes = const {'openid', 'profile', 'email'},
    CacheLocation cacheLocation = CacheLocation.memory,
    bool useRefreshTokens = false,
    int? leeway,
  }) async {
    _checkLibraryLoaded();

    final authParams = <String, Object?>{
      if (audience != null) 'audience': audience,
      'scope': scopes.join(' '),
      if (redirectUri != null) 'redirect_uri': redirectUri,
    };

    final options = Auth0ClientOptionsJS(
      domain: domain.toJS,
      clientId: clientId.toJS,
      authorizationParams:
          authParams.isNotEmpty ? jsifyOptions(authParams) : null,
      cacheLocation: _cacheLoc(cacheLocation)?.toJS,
      useRefreshTokens: useRefreshTokens ? true.toJS : null,
      leeway: leeway?.toJS,
    );

    _client = await createAuth0Client(options);

    // Check if URL has authorization code callback params.
    final search = _locationSearch.toDart;
    final uri = Uri(query: search.startsWith('?') ? search.substring(1) : search);
    if (uri.queryParameters.containsKey('code') &&
        uri.queryParameters.containsKey('state')) {
      final result = await _client!.handleRedirectCallback().toDart;
      final callbackResult = RedirectCallbackResultJS(result);
      _appState = callbackResult.appState?.dartify();

      // Clean up the URL to remove code/state params.
      final cleanUrl =
          '${_locationOrigin.toDart}${_locationPathname.toDart}';
      _historyReplaceState(null, ''.toJS, cleanUrl.toJS);

      return _getDetailedCredentials();
    }

    // No redirect — try to restore from cache.
    try {
      return await _getDetailedCredentials(cacheMode: CacheMode.cacheOnly);
    } catch (_) {
      return null;
    }
  }

  /// Redirect the browser to Auth0 Universal Login.
  Future<void> loginWithRedirect({
    String? audience,
    String? redirectUri,
    String? organizationId,
    String? invitationUrl,
    int? maxAge,
    Set<String>? scopes,
    Object? appState,
    Map<String, String> parameters = const {},
  }) async {
    _ensureClient();

    final authParams = <String, Object?>{
      if (audience != null) 'audience': audience,
      if (scopes != null) 'scope': scopes.join(' '),
      if (redirectUri != null) 'redirect_uri': redirectUri,
      if (organizationId != null) 'organization': organizationId,
      if (invitationUrl != null) 'invitation': invitationUrl,
      if (maxAge != null) 'max_age': maxAge,
      ...parameters,
    };

    final options = RedirectLoginOptionsJS(
      authorizationParams:
          authParams.isNotEmpty ? jsifyOptions(authParams) : null,
      appState: appState?.jsify(),
    );

    await _client!.loginWithRedirect(options).toDart;
  }

  /// Open a popup for login and return credentials directly.
  Future<Credentials> loginWithPopup({
    String? audience,
    String? organizationId,
    int? maxAge,
    Set<String>? scopes,
    Map<String, String> parameters = const {},
  }) async {
    _ensureClient();

    final authParams = <String, Object?>{
      if (audience != null) 'audience': audience,
      if (scopes != null) 'scope': scopes.join(' '),
      if (organizationId != null) 'organization': organizationId,
      if (maxAge != null) 'max_age': maxAge,
      ...parameters,
    };

    final options = PopupLoginOptionsJS(
      authorizationParams:
          authParams.isNotEmpty ? jsifyOptions(authParams) : null,
    );

    try {
      await _client!.loginWithPopup(options).toDart;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('popup') || errorStr.contains('Popup')) {
        throw WebAuthException.popupBlocked();
      }
      throw WebAuthException.unknown(cause: e);
    }

    // After popup closes, fetch tokens with a detailed response.
    return _getDetailedCredentials();
  }

  /// Get cached credentials or refresh silently.
  Future<Credentials> credentials({
    String? audience,
    Set<String>? scopes,
    CacheMode cacheMode = CacheMode.on,
  }) async {
    _ensureClient();
    return _getDetailedCredentials(
      audience: audience,
      scopes: scopes,
      cacheMode: cacheMode,
    );
  }

  /// Check if authenticated (has cached tokens).
  Future<bool> hasValidCredentials() async {
    _ensureClient();
    final result = await _client!.isAuthenticated().toDart;
    return result.toDart;
  }

  /// Log out. Optionally redirect to [returnToUrl].
  Future<void> logout({String? returnToUrl, bool federated = false}) async {
    _ensureClient();

    final logoutParams = <String, Object?>{
      if (returnToUrl != null) 'returnTo': returnToUrl,
      if (federated) 'federated': true,
    };

    final options = LogoutOptionsJS(
      logoutParams: logoutParams.isNotEmpty ? jsifyOptions(logoutParams) : null,
    );

    await _client!.logout(options).toDart;
  }

  /// App state from the redirect callback processed by [onLoad].
  Object? get appState => _appState;

  // ──────── Private helpers ────────

  void _ensureClient() {
    if (_client == null) throw WebAuthException.spaNotInitialized();
  }

  void _checkLibraryLoaded() {
    if (!isSpaLibraryLoaded()) throw WebAuthException.spaLibraryMissing();
  }

  Future<Credentials> _getDetailedCredentials({
    String? audience,
    Set<String>? scopes,
    CacheMode cacheMode = CacheMode.on,
  }) async {
    final authParams = <String, Object?>{
      if (audience != null) 'audience': audience,
      if (scopes != null) 'scope': scopes.join(' '),
    };

    final jsCacheMode = switch (cacheMode) {
      CacheMode.on => null,
      CacheMode.off => 'off',
      CacheMode.cacheOnly => 'cache-only',
    };

    final options = GetTokenSilentlyOptionsJS(
      authorizationParams:
          authParams.isNotEmpty ? jsifyOptions(authParams) : null,
      cacheMode: jsCacheMode?.toJS,
      detailedResponse: true.toJS,
    );

    final JSAny? result;
    try {
      result = await _client!.getTokenSilently(options).toDart;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('login_required') ||
          errorStr.contains('Login required')) {
        throw WebAuthException.loginRequired();
      }
      throw WebAuthException.unknown(cause: e);
    }

    if (result == null) {
      throw WebAuthException.loginRequired();
    }

    final verbose = GetTokenSilentlyVerboseResponseJS(result as JSObject);
    final expiresIn = verbose.expiresIn.toDartInt;
    final scopeStr = verbose.scope?.toDart ?? '';
    final scopeSet = scopeStr.isEmpty
        ? <String>{}
        : scopeStr.split(' ').where((s) => s.isNotEmpty).toSet();

    return Credentials(
      accessToken: verbose.accessToken.toDart,
      tokenType: 'Bearer',
      idToken: verbose.idToken.toDart,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      scopes: scopeSet,
    );
  }

  static String? _cacheLoc(CacheLocation loc) => switch (loc) {
        CacheLocation.memory => 'memory',
        CacheLocation.localStorage => 'localstorage',
      };
}
