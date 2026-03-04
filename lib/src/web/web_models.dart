/// Cache location for auth0-spa-js token storage.
enum CacheLocation {
  /// In-memory cache (default). Tokens are lost on page refresh.
  memory,

  /// Browser localStorage. Tokens persist across page refreshes.
  localStorage,
}

/// Controls how [Auth0SpaAdapter.credentials] interacts with the token cache.
enum CacheMode {
  /// Use cached tokens if available; refresh silently if expired.
  on,

  /// Skip the cache and always fetch a new token.
  off,

  /// Only return cached tokens; never make a network request.
  cacheOnly,
}

/// Configuration for the auth0-spa-js client created by [Auth0SpaAdapter.onLoad].
class SpaClientOptions {
  /// Auth0 tenant domain (e.g. `example.us.auth0.com`).
  final String domain;

  /// Application client ID from the Auth0 dashboard.
  final String clientId;

  /// Default redirect URI after login. Falls back to `window.location.origin`.
  final String? redirectUri;

  /// API audience for access-token scoping.
  final String? audience;

  /// OAuth scopes to request.
  final Set<String> scopes;

  /// Where auth0-spa-js stores tokens.
  final CacheLocation cacheLocation;

  /// Whether to use refresh tokens instead of silent iframe renewal.
  final bool useRefreshTokens;

  /// Clock tolerance in seconds for token expiration checks.
  final int? leeway;

  const SpaClientOptions({
    required this.domain,
    required this.clientId,
    this.redirectUri,
    this.audience,
    this.scopes = const {'openid', 'profile', 'email'},
    this.cacheLocation = CacheLocation.memory,
    this.useRefreshTokens = false,
    this.leeway,
  });
}
