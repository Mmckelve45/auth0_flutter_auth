@JS()
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// ──────── Auth0 Client ────────

/// Wraps the auth0-spa-js `Auth0Client` class.
extension type Auth0ClientJS(JSObject _) implements JSObject {
  external JSPromise<JSAny?> loginWithRedirect(JSObject? options);
  external JSPromise<JSAny?> loginWithPopup(JSObject? options);
  external JSPromise<JSObject> handleRedirectCallback();
  external JSPromise<JSAny?> getTokenSilently(JSObject? options);
  external JSPromise<JSAny?> logout(JSObject? options);
  external JSPromise<JSBoolean> isAuthenticated();
  external JSPromise<JSAny?> getUser();
}

// ──────── Option Types ────────

/// Options passed to `createAuth0Client()`.
extension type Auth0ClientOptionsJS._(JSObject _) implements JSObject {
  external factory Auth0ClientOptionsJS({
    required JSString domain,
    required JSString clientId,
    JSObject? authorizationParams,
    JSString? cacheLocation,
    JSBoolean? useRefreshTokens,
    JSNumber? leeway,
  });
}

/// Options for `loginWithPopup()`.
extension type PopupLoginOptionsJS._(JSObject _) implements JSObject {
  external factory PopupLoginOptionsJS({
    JSObject? authorizationParams,
  });
}

/// Options for `loginWithRedirect()`.
extension type RedirectLoginOptionsJS._(JSObject _) implements JSObject {
  external factory RedirectLoginOptionsJS({
    JSObject? authorizationParams,
    JSAny? appState,
  });
}

/// Options for `getTokenSilently()`.
extension type GetTokenSilentlyOptionsJS._(JSObject _) implements JSObject {
  external factory GetTokenSilentlyOptionsJS({
    JSObject? authorizationParams,
    JSString? cacheMode,
    JSBoolean? detailedResponse,
  });
}

/// Options for `logout()`.
extension type LogoutOptionsJS._(JSObject _) implements JSObject {
  external factory LogoutOptionsJS({
    JSObject? logoutParams,
  });
}

/// Verbose response from `getTokenSilently({ detailedResponse: true })`.
extension type GetTokenSilentlyVerboseResponseJS(JSObject _)
    implements JSObject {
  @JS('access_token')
  external JSString get accessToken;
  @JS('id_token')
  external JSString get idToken;
  @JS('expires_in')
  external JSNumber get expiresIn;
  external JSString? get scope;
}

/// Result from `handleRedirectCallback()`.
extension type RedirectCallbackResultJS(JSObject _) implements JSObject {
  external JSAny? get appState;
}

// ──────── Top-Level Binding ────────

@JS('createAuth0Client')
external JSPromise<Auth0ClientJS> _createAuth0Client(
    Auth0ClientOptionsJS options);

/// Creates and initializes an auth0-spa-js `Auth0Client`.
///
/// Calls the global `createAuth0Client()` function that must be loaded via
/// a `<script>` tag in `index.html`.
Future<Auth0ClientJS> createAuth0Client(Auth0ClientOptionsJS options) =>
    _createAuth0Client(options).toDart;

// ──────── Helpers ────────

/// Checks whether the auth0-spa-js library is loaded on the page.
bool isSpaLibraryLoaded() {
  return globalContext.has('createAuth0Client');
}

/// Converts a Dart [Map] to a plain JS object, stripping null values.
JSObject jsifyOptions(Map<String, Object?> map) {
  final obj = JSObject();
  for (final entry in map.entries) {
    if (entry.value == null) continue;
    final value = entry.value;
    if (value is String) {
      obj[entry.key] = value.toJS;
    } else if (value is int) {
      obj[entry.key] = value.toJS;
    } else if (value is double) {
      obj[entry.key] = value.toJS;
    } else if (value is bool) {
      obj[entry.key] = value.toJS;
    } else if (value is Map<String, Object?>) {
      obj[entry.key] = jsifyOptions(value);
    } else {
      obj[entry.key] = (value as Object).jsify();
    }
  }
  return obj;
}
