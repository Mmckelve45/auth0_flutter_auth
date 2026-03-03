// Placeholder for dart:js_interop bindings to auth0-spa-js.
// Users who opt into the web adapter must include auth0-spa-js in their index.html.
//
// This file is intentionally minimal — it provides the type declarations
// needed by auth0_spa_adapter.dart. A full implementation would use
// @staticInterop and @JS annotations with dart:js_interop.

class Auth0SpaClientOptions {
  final String domain;
  final String clientId;
  final String? audience;
  final String? redirectUri;

  Auth0SpaClientOptions({
    required this.domain,
    required this.clientId,
    this.audience,
    this.redirectUri,
  });
}
