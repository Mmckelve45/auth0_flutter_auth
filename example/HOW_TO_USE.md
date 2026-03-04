# How to Use — FAQ & Architecture Guide

This document covers the questions we get asked most often about the example app and the `auth0_flutter_auth` SDK: how auth state works, how to keep users logged in, the differences between web and mobile, which parts still need native code, and known limitations.

---

## Table of Contents

1. [Keeping Users Logged In](#keeping-users-logged-in)
2. [Auth State: How It Works](#auth-state-how-it-works)
3. [Web vs. Mobile: SPA vs. Native](#web-vs-mobile-spa-vs-native)
4. [Which Methods Use Native Interop (and Why)](#which-methods-use-native-interop-and-why)
5. [Known Shortcomings & Limitations](#known-shortcomings--limitations)
6. [Where to Look in the Example App](#where-to-look-in-the-example-app)

---

## Keeping Users Logged In

Credentials (access token, refresh token, ID token) are persisted to secure storage via `flutter_secure_storage`. On iOS this is the Keychain; on Android it's the Keystore; on web it falls back to browser localStorage.

When the app launches, the SDK reads from secure storage before rendering:

```
App starts
  └─ AuthState subscribes to auth0.authStateChanges()
       └─ Stream's first emission calls getCredentials()
            └─ Reads from FlutterSecureStorage
                 ├─ Credentials found → isAuthenticated = true → route to /dashboard
                 └─ No credentials    → isAuthenticated = false → route to /
```

There is no polling, no timers, and no network call at startup — just a single secure-storage read. The user stays logged in across app restarts as long as stored credentials exist and are not expired (or can be refreshed).

**Key methods:**

| Method | What it does |
|--------|-------------|
| `credentials.storeCredentials(c)` | Writes to secure storage and emits on the auth state stream |
| `credentials.clearCredentials()` | Deletes from secure storage and emits `null` on the stream |
| `credentials.getCredentials()` | Reads stored credentials; auto-refreshes if expired (requires a refresh token) |
| `credentials.hasValidCredentials()` | Boolean check — "do I have usable tokens?" — without returning them |
| `credentials.renewCredentials()` | Forces a refresh-token exchange, updates storage, and emits on the stream |

**Auto-refresh:** `getCredentials()` checks token expiry (and an optional `minTtl` parameter). If the access token is expired or about to expire and a refresh token is available, it automatically calls the `/oauth/token` endpoint to get a new one, updates secure storage, and returns the fresh credentials. Concurrent refresh calls are deduplicated so multiple widgets calling `getCredentials()` simultaneously won't cause multiple network requests.

> **Example app:** See `example/lib/main.dart` — the `AuthState` class (line 100) and `main()` (line 135).

---

## Auth State: How It Works

The SDK provides a single reactive primitive:

```dart
Stream<Credentials?> auth0.authStateChanges()
```

This stream:

1. **Emits immediately** with the current stored state (like Firebase's `authStateChanges()` or Supabase's `onAuthStateChange`).
2. **Emits on every change** — whenever `storeCredentials()` or `clearCredentials()` is called.
3. **Is framework-agnostic.** The example wraps it in a `ChangeNotifier` for GoRouter, but you can use it with any state management:

```dart
// GoRouter (this example)
class AuthState extends ChangeNotifier {
  late final StreamSubscription<Credentials?> _sub;
  AuthState() {
    _sub = auth0.authStateChanges().listen((creds) {
      _isAuthenticated = creds != null;
      notifyListeners();
    });
  }
}

// Riverpod
final authProvider = StreamProvider((_) => auth0.authStateChanges());

// StreamBuilder
StreamBuilder<Credentials?>(
  stream: auth0.authStateChanges(),
  builder: (context, snapshot) { ... },
);

// BLoC
auth0.authStateChanges().listen((creds) => add(AuthStateChanged(creds)));
```

**How login triggers navigation (no manual routing needed):**

```
User taps "Log In"
  └─ auth0.webAuth.login() → returns Credentials
       └─ auth0.credentials.storeCredentials(credentials)
            └─ Writes to secure storage
            └─ Emits Credentials on stream
                 └─ AuthState.notifyListeners()
                      └─ GoRouter re-evaluates redirect → routes to /dashboard
```

Logout is the mirror image:

```
User taps "Log Out"
  └─ auth0.webAuth.logout() → opens browser to /v2/logout
  └─ auth0.credentials.clearCredentials()
       └─ Deletes from secure storage
       └─ Emits null on stream
            └─ AuthState.notifyListeners()
                 └─ GoRouter re-evaluates redirect → routes to /
```

**One-shot (imperative) alternative:** If you don't need a reactive stream — for example, you're already using Firebase for routing and just need an Auth0 credential check at one point — use the imperative API:

```dart
final loggedIn = await auth0.credentials.hasValidCredentials();
final creds = await auth0.credentials.getCredentials(); // null if none
```

> **Example app:** See `example/lib/main.dart` lines 100–129 (`AuthState`) and lines 155–205 (GoRouter redirect logic). The splash screen (line 166) is shown while the first stream emission is pending, preventing a flash of the login page.

---

## Web vs. Mobile: SPA vs. Native

### The core difference

On **mobile** (iOS/Android/macOS), the SDK launches a system browser via platform channels and receives the callback through native OS mechanisms:

- **iOS/macOS:** `ASWebAuthenticationSession` — a secure, sandboxed browser sheet provided by Apple.
- **Android:** Chrome Custom Tabs with an intent-filter `CallbackActivity` to intercept the redirect.

On **web**, there is no "system browser" to launch — the app *is* the browser. The auth flow is a **redirect**: the entire page navigates to Auth0, and Auth0 redirects back to your app's `/callback` route with the authorization code in the URL.

### Flow comparison

| Step | Mobile (Native) | Web (SPA / Redirect) |
|------|-----------------|---------------------|
| **Initiate login** | `auth0.webAuth.login()` — one method, handles everything | `auth0.webAuth.buildAuthorizeUrl()` → manually redirect the browser |
| **Browser** | System browser sheet (ASWebAuth / Custom Tabs) | The page itself navigates to Auth0 |
| **Receive callback** | Native OS intercepts the custom-scheme URL and returns it to the app | GoRouter (or your router) matches the `/callback` route |
| **Exchange code** | Handled internally by `login()` | You call `auth0.webAuth.handleCallback(uri)` in your callback route |
| **Store credentials** | You call `storeCredentials()` after `login()` returns | Same — call `storeCredentials()` after `handleCallback()` returns |

### Mobile flow (one call):

```dart
final creds = await auth0.webAuth.login(
  redirectUrl: '$scheme:/callback',
  scopes: {'openid', 'profile', 'email', 'offline_access'},
);
await auth0.credentials.storeCredentials(creds);
```

### Web flow (two phases):

```dart
// Phase 1: Build URL and redirect
final url = auth0.webAuth.buildAuthorizeUrl(
  redirectUrl: 'http://localhost:5000/callback',
  scopes: {'openid', 'profile', 'email', 'offline_access'},
);
html.window.location.href = url.toString(); // full-page redirect

// Phase 2: Handle callback (in your /callback route)
final creds = await auth0.webAuth.handleCallback(callbackUri);
await auth0.credentials.storeCredentials(creds);
```

### Why the difference?

Mobile apps have custom URL schemes (`com.example.myapp:/callback`) that the OS can route to a specific app. Web apps don't — they use `http://` URLs that load in the browser. That means:

- On mobile, `login()` can open a browser, wait for the redirect, and return credentials all in one `await`.
- On web, the page navigates away entirely. When Auth0 redirects back, your app boots fresh. You must handle the callback as a separate route, and the PKCE state (`_pendingPkce`, `_pendingState`) must survive the redirect (the SDK stores it in memory, so you need to call `buildAuthorizeUrl` and `handleCallback` in the same session).

### Credential storage differences

| Platform | Storage backend | Security model |
|----------|----------------|----------------|
| iOS/macOS | Keychain | Hardware-backed, encrypted at rest, per-app sandboxed |
| Android | Keystore + EncryptedSharedPreferences | Hardware-backed on supported devices |
| Web | Browser localStorage | Same-origin policy only — no true "secure" storage |

On web, `flutter_secure_storage` maps to `localStorage`, which is readable by any JavaScript on the same origin. This is the same model that `auth0-spa-js` and every other browser-based auth library uses, but it's worth understanding that "secure storage" on web is not equivalent to the Keychain/Keystore.

> **Example apps:** See `example/lib/screens/home_screen.dart` (mobile flow) and `example_web/lib/main.dart` (web redirect flow).

---

## Which Methods Use Native Interop (and Why)

Most of the SDK is pure Dart — HTTP calls, JSON parsing, JWT decoding, PKCE generation, credential storage. Only two features require platform channels:

### 1. Browser Launch (`com.auth0.flutter_auth/browser`)

| Platform | Native implementation | Why native? |
|----------|----------------------|-------------|
| iOS/macOS | `ASWebAuthenticationSession` (Swift) | Apple requires this API for secure browser-based auth. It provides SSO, handles the callback URL scheme, and presents a system-level consent prompt. |
| Android | `CustomTabsIntent` + `CallbackActivity` (Kotlin) | Chrome Custom Tabs provide an in-app browser experience. The `CallbackActivity` receives the redirect via Android's intent-filter system. |
| Web | Not used | The browser is the app — no native launch needed. |

**Methods that use this channel:**
- `webAuth.login()` — launches browser, waits for callback, exchanges code
- `webAuth.logout()` — opens the `/v2/logout` URL in a browser
- `WebAuth.cancel()` — cancels an in-progress session (iOS only)

### 2. DPoP Signing (`com.auth0.flutter_auth/dpop`)

| Platform | Native implementation | Why native? |
|----------|----------------------|-------------|
| iOS/macOS | Security framework + Secure Enclave (Swift) | The private key is generated in the Secure Enclave (hardware) and never leaves it. Signing happens on the hardware chip. Dart has no access to this. |
| Android | Android Keystore + StrongBox (Kotlin) | Same concept — hardware-backed key storage with StrongBox on supported devices. The key material is never extractable. |
| Web | Not implemented | Would require Web Crypto API via `dart:js_interop`. Currently stubbed. |

**Methods that use this channel:**
- `dpop.initialize()` — generates an EC P-256 key pair in hardware
- `dpop.generateHeaders()` — signs a DPoP proof JWT using the hardware key
- `dpop.clear()` — deletes the key pair

**Everything else is pure Dart:**
- All Authentication API calls (`loginWithPassword`, `signup`, `resetPassword`, `startPasswordlessEmail`, `loginWithEmailCode`, `getUserInfo`, MFA methods, etc.)
- PKCE generation (`Pkce.generate()`)
- JWT decoding and validation
- Credential storage and retrieval (via `flutter_secure_storage` plugin, which has its own platform channels internally)
- Auth state stream
- URL building

> **Example app:** See `example/lib/tabs/api_explorer_tab.dart` — every method in the "Authentication API" section is pure Dart. The "Web Auth" and "DPoP" sections use platform channels.

---

## Known Shortcomings & Limitations

### Web platform support is partial

The SDK works on web for the core auth flow (redirect-based PKCE, token exchange, credential storage, API calls). However:

- **`Auth0SpaAdapter` is a stub.** The `auth0_flutter_auth_web.dart` export provides an adapter class intended to wrap the `auth0-spa-js` JavaScript library, but all methods currently throw `UnimplementedError`. If you want the full SPA experience (silent token renewal via hidden iframes, session management), you would need to implement the `dart:js_interop` bindings yourself or use the redirect-based flow that the SDK does support.

- **DPoP is not available on web.** The DPoP implementation depends on platform channels for hardware-backed key generation and signing. There is no Web Crypto API integration. `auth0.dpop` will be `null` on web.

- **Biometric auth is not available on web.** The `requireBiometrics` option in `CredentialStoreOptions` uses the `local_auth` plugin, which doesn't support web. If biometrics are unavailable, the SDK silently skips the check rather than throwing.

- **Credential storage on web uses localStorage.** This is standard for browser-based apps but is not hardware-backed or encrypted at rest like the Keychain/Keystore on mobile.

### JWT validation supports RS256 only

The `JwtValidator` only supports RS256 (RSA + SHA-256) for ID token signature verification. Tokens signed with HS256, ES256, or other algorithms will fail validation. RS256 is the Auth0 default, so this only matters if you've changed your application's signing algorithm.

### `cancel()` is iOS only

`WebAuth.cancel()` calls through to `ASWebAuthenticationSession.cancel()` on iOS/macOS. On Android the method is a no-op — there's no equivalent API for Chrome Custom Tabs. On web it's also a no-op.

### `preferEphemeral` only affects iOS/macOS

The `preferEphemeral` parameter on `webAuth.login()` controls whether `ASWebAuthenticationSession` uses a private (ephemeral) browser session, which avoids SSO cookies being shared with Safari. This parameter has no effect on Android (Custom Tabs always share cookies with Chrome) or web.

### Token refresh requires a refresh token

`getCredentials()` and `renewCredentials()` can only auto-refresh if the original login returned a refresh token. To get a refresh token, you must include `offline_access` in your scopes **and** enable Refresh Token Rotation in the Auth0 Dashboard (Settings > Advanced > Refresh Token Rotation). Without a refresh token, expired credentials cannot be silently renewed.

### Platform minimum versions

| Platform | Minimum version |
|----------|----------------|
| iOS | 14.0+ |
| macOS | 11.0+ |
| Android | API 23+ (minSdkVersion) |
| Web | Supported (with limitations above) |

---

## Where to Look in the Example App

| Question | File | What to look at |
|----------|------|----------------|
| How is Auth0Client initialized? | `example/lib/main.dart:139` | `Auth0Client(domain:, clientId:)` in `main()` |
| How does the auth state stream work? | `example/lib/main.dart:100` | `AuthState` class — wraps `authStateChanges()` in a `ChangeNotifier` |
| How does the router react to auth changes? | `example/lib/main.dart:155` | GoRouter `redirect` callback + `refreshListenable: authState` |
| How does the splash screen prevent a flash? | `example/lib/main.dart:165` | Redirect to `/splash` while `!authState.isInitialized` |
| How does login work (Universal Login)? | `example/lib/screens/home_screen.dart:172` | `_UniversalLoginTab._login()` — calls `webAuth.login()` then `storeCredentials()` |
| How does login work (password grant)? | `example/lib/screens/home_screen.dart:328` | `_PasswordLoginTab._login()` — calls `api.loginWithPassword()` |
| How does login work (email passwordless)? | `example/lib/screens/home_screen.dart:515` | Two-step: `startPasswordlessEmail()` then `loginWithEmailCode()` |
| How does MFA work? | `example/lib/screens/home_screen.dart:1011` | `_MfaDialog` — calls `getMfaChallenge()` then `verifyMfaOtp()` |
| How does login trigger navigation? | `example/lib/screens/home_screen.dart:73` | `_storeAndNavigate()` — just calls `storeCredentials()`, stream does the rest |
| How does logout work? | `example/lib/screens/dashboard_screen.dart:18` | `_logout()` — calls `webAuth.logout()` then `clearCredentials()` |
| How are credentials displayed? | `example/lib/tabs/profile_tab.dart` | Shows user card, token metadata, and raw tokens |
| How do API methods work? | `example/lib/tabs/api_explorer_tab.dart` | Every SDK method with a runnable tile |
| How does the web redirect flow work? | `example_web/lib/main.dart:71` | `buildAuthorizeUrl()` → redirect → `handleCallback()` on `/callback` route |
