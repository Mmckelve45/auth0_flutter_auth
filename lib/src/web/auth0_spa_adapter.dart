import '../models/credentials.dart';

/// Optional adapter for auth0-spa-js on Flutter Web.
///
/// To use this adapter, include `auth0-spa-js` in your `web/index.html`:
/// ```html
/// <script src="https://cdn.auth0.com/js/auth0-spa-js/2.1/auth0-spa-js.production.js"></script>
/// ```
///
/// Then import `package:auth0_flutter_auth/auth0_flutter_auth_web.dart`.
///
/// This is a stub implementation. A full implementation would use
/// dart:js_interop to call the auth0-spa-js library directly.
class Auth0SpaAdapter {
  final String domain;
  final String clientId;
  final String? audience;

  Auth0SpaAdapter({
    required this.domain,
    required this.clientId,
    this.audience,
  });

  /// Redirects to Auth0 Universal Login.
  Future<void> loginWithRedirect({
    String? redirectUri,
    Set<String> scopes = const {'openid', 'profile', 'email'},
  }) async {
    throw UnimplementedError(
      'Auth0SpaAdapter requires dart:js_interop and auth0-spa-js. '
      'This is a stub — implement with @JS annotations for web.',
    );
  }

  /// Handles the redirect callback after login.
  Future<Credentials> handleRedirectCallback() async {
    throw UnimplementedError(
      'Auth0SpaAdapter requires dart:js_interop and auth0-spa-js.',
    );
  }

  /// Gets cached credentials or refreshes silently.
  Future<Credentials?> getTokenSilently({
    String? audience,
    Set<String> scopes = const {},
  }) async {
    throw UnimplementedError(
      'Auth0SpaAdapter requires dart:js_interop and auth0-spa-js.',
    );
  }

  /// Logs the user out.
  Future<void> logout({String? returnTo}) async {
    throw UnimplementedError(
      'Auth0SpaAdapter requires dart:js_interop and auth0-spa-js.',
    );
  }

  /// Checks if the user is authenticated.
  Future<bool> isAuthenticated() async {
    throw UnimplementedError(
      'Auth0SpaAdapter requires dart:js_interop and auth0-spa-js.',
    );
  }
}
