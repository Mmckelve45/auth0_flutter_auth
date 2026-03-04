import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../api/auth_api.dart';
import '../jwt/jwt_validator.dart';
import '../models/credentials.dart';
import '../exceptions/web_auth_exception.dart';
import 'authorize_url_builder.dart';
import 'browser_platform.dart';
import 'pkce.dart';

class WebAuth {
  final String _domain;
  final String _clientId;
  final AuthApi _api;
  final JwtValidator? _jwtValidator;
  final BrowserPlatform _browser;
  final AuthorizeUrlBuilder _urlBuilder;

  // Stored PKCE state for web redirect flow
  Pkce? _pendingPkce;
  String? _pendingState;
  String? _pendingNonce;
  String? _pendingRedirectUrl;

  WebAuth({
    required String domain,
    required String clientId,
    required AuthApi api,
    JwtValidator? jwtValidator,
    BrowserPlatform? browser,
  })  : _domain = domain,
        _clientId = clientId,
        _api = api,
        _jwtValidator = jwtValidator,
        _browser = browser ?? BrowserPlatform(),
        _urlBuilder = AuthorizeUrlBuilder(domain: domain, clientId: clientId);

  /// Performs browser-based login with PKCE.
  Future<Credentials> login({
    String? redirectUrl,
    String? audience,
    Set<String> scopes = const {'openid', 'profile', 'email'},
    String? organizationId,
    String? invitationUrl,
    bool preferEphemeral = false,
    int? maxAge,
    Map<String, String>? parameters,
  }) async {
    final effectiveRedirectUrl = redirectUrl ?? _defaultRedirectUrl;
    final pkce = Pkce.generate();
    final state = _generateState();
    final nonce = _generateNonce();

    final authorizeUrl = _urlBuilder.buildAuthorizeUrl(
      redirectUrl: effectiveRedirectUrl,
      state: state,
      codeChallenge: pkce.codeChallenge,
      audience: audience,
      scopes: scopes,
      organizationId: organizationId,
      invitationUrl: invitationUrl,
      maxAge: maxAge,
      nonce: nonce,
      parameters: parameters,
    );

    final callbackScheme = Uri.parse(effectiveRedirectUrl).scheme;

    final callbackUrlString = await _browser.launchAuth(
      url: authorizeUrl.toString(),
      callbackScheme: callbackScheme,
      preferEphemeral: preferEphemeral,
    );

    final callbackUri = Uri.parse(callbackUrlString);

    // Verify state
    final returnedState = callbackUri.queryParameters['state'];
    if (returnedState != state) {
      throw WebAuthException.stateMismatch();
    }

    // Check for error
    final error = callbackUri.queryParameters['error'];
    if (error != null) {
      final description = callbackUri.queryParameters['error_description'] ?? error;
      throw WebAuthException(
        message: description,
        code: 'a0.$error',
      );
    }

    // Extract code
    final code = callbackUri.queryParameters['code'];
    if (code == null) {
      throw WebAuthException.noCallbackUrl();
    }

    // Exchange code for tokens
    final credentials = await _api.exchangeCode(
      code: code,
      codeVerifier: pkce.codeVerifier,
      redirectUrl: effectiveRedirectUrl,
      nonce: nonce,
    );

    // Validate ID token if present and validator is configured
    if (credentials.idToken != null && _jwtValidator != null) {
      try {
        await _jwtValidator.validate(
          credentials.idToken!,
          nonce: nonce,
          organization: organizationId,
          maxAge: maxAge,
        );
      } catch (e) {
        throw WebAuthException.idTokenValidation(e.toString());
      }
    }

    return credentials;
  }

  /// Performs browser-based logout.
  Future<void> logout({
    String? returnTo,
    bool federated = false,
  }) async {
    final logoutUrl = _urlBuilder.buildLogoutUrl(
      returnTo: returnTo,
      federated: federated,
    );

    final callbackScheme = returnTo != null
        ? Uri.parse(returnTo).scheme
        : _defaultCallbackScheme;

    try {
      await _browser.launchAuth(
        url: logoutUrl.toString(),
        callbackScheme: callbackScheme,
        preferEphemeral: true,
      );
    } on WebAuthException catch (e) {
      // Ignore cancellation on logout — user may close the browser
      if (!e.isCancelled) rethrow;
    }
  }

  /// Cancels any in-progress authentication (iOS only).
  static Future<void> cancel() async {
    await BrowserPlatform().cancel();
  }

  /// Builds an authorize URL for manual redirect-based flows (e.g., web).
  Uri buildAuthorizeUrl({
    required String redirectUrl,
    String? audience,
    Set<String> scopes = const {'openid', 'profile', 'email'},
    String? organizationId,
    int? maxAge,
    Map<String, String>? parameters,
  }) {
    _pendingPkce = Pkce.generate();
    _pendingState = _generateState();
    _pendingNonce = _generateNonce();
    _pendingRedirectUrl = redirectUrl;

    return _urlBuilder.buildAuthorizeUrl(
      redirectUrl: redirectUrl,
      state: _pendingState!,
      codeChallenge: _pendingPkce!.codeChallenge,
      audience: audience,
      scopes: scopes,
      organizationId: organizationId,
      maxAge: maxAge,
      nonce: _pendingNonce,
      parameters: parameters,
    );
  }

  /// Handles the callback URI from a redirect-based flow.
  Future<Credentials> handleCallback(Uri callbackUri) async {
    if (_pendingPkce == null || _pendingState == null) {
      throw WebAuthException(
        message: 'No pending authorization. Call buildAuthorizeUrl first.',
        code: 'a0.no_pending_auth',
      );
    }

    final returnedState = callbackUri.queryParameters['state'];
    if (returnedState != _pendingState) {
      throw WebAuthException.stateMismatch();
    }

    final error = callbackUri.queryParameters['error'];
    if (error != null) {
      final description = callbackUri.queryParameters['error_description'] ?? error;
      _clearPending();
      throw WebAuthException(
        message: description,
        code: 'a0.$error',
      );
    }

    final code = callbackUri.queryParameters['code'];
    if (code == null) {
      _clearPending();
      throw WebAuthException.noCallbackUrl();
    }

    final credentials = await _api.exchangeCode(
      code: code,
      codeVerifier: _pendingPkce!.codeVerifier,
      redirectUrl: _pendingRedirectUrl!,
      nonce: _pendingNonce,
    );

    if (credentials.idToken != null && _jwtValidator != null) {
      try {
        await _jwtValidator.validate(
          credentials.idToken!,
          nonce: _pendingNonce,
        );
      } catch (e) {
        _clearPending();
        throw WebAuthException.idTokenValidation(e.toString());
      }
    }

    _clearPending();
    return credentials;
  }

  void _clearPending() {
    _pendingPkce = null;
    _pendingState = null;
    _pendingNonce = null;
    _pendingRedirectUrl = null;
  }

  String get _defaultRedirectUrl => '$_defaultCallbackScheme:/callback';

  String get _defaultCallbackScheme =>
      _domain.replaceAll('.', '-').replaceAll(':', '-');

  static String _generateState() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
