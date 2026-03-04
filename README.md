# Auth0 SDK for Flutter

[![pub package](https://img.shields.io/pub/v/auth0_flutter_auth.svg)](https://pub.dev/packages/auth0_flutter_auth)
[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A minimal, pure Dart Auth0 SDK for Flutter with native bridges only for secure browser launches and hardware-backed DPoP keys. This package implements OAuth 2.0 + OpenID Connect with PKCE, MFA, passwordless, biometrics, and more — all with a compact ~640 lines of native code.

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [API Reference](#api-reference)
  - [AuthApi Module](#authapi-module)
  - [WebAuth Module](#webauth-module)
  - [CredentialStore Module](#credentialstore-module)
  - [DPoP Module](#dpop-module)
- [Platform Setup](#platform-setup)
  - [iOS](#ios)
  - [macOS](#macos)
  - [Android](#android)
  - [Web](#web)
- [Usage Examples](#usage-examples)
  - [Basic Login](#basic-login)
  - [Password-Based Login](#password-based-login)
  - [Passwordless Login](#passwordless-login)
  - [MFA](#mfa)
  - [User Profile](#user-profile)
  - [Token Refresh](#token-refresh)
  - [Biometric Authentication](#biometric-authentication)
  - [DPoP](#dpop)
- [Error Handling](#error-handling)
- [Testing](#testing)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [License](#license)

## Installation

Add `auth0_flutter_auth` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  auth0_flutter_auth: ^0.1.0
```

Then run:

```bash
flutter pub get
```

### Platform Requirements

- **iOS**: 14.0+
- **macOS**: 11.0+
- **Android**: API 23+ (minSdkVersion)
- **Web**: Via optional auth0-spa-js adapter

## Quick Start

Initialize the `Auth0Client` with your Auth0 domain and Client ID:

```dart
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

final auth0 = Auth0Client(
  domain: 'your-tenant.auth0.com',
  clientId: 'your_client_id',
);

// Perform browser-based login with PKCE
try {
  final credentials = await auth0.webAuth.login();
  print('Access token: ${credentials.accessToken}');

  // Store credentials securely
  await auth0.credentials.storeCredentials(credentials);
} catch (e) {
  print('Login failed: $e');
}
```

## Configuration

### Auth0 Dashboard Setup

1. **Create an Application**:
   - Go to [Auth0 Dashboard](https://manage.auth0.com)
   - Select "Applications" → "Create Application"
   - Choose "Native"
   - Fill in your application name

2. **Configure Callback URLs**:
   - Add your app's callback schemes:
     - iOS/macOS: `com.example.app://your-tenant.auth0.com/ios/com.example.app/callback`
     - Android: `com.example.app://your-tenant.auth0.com/android/com.example.app/callback`
   - For development, you may also add `http://localhost:3000/callback` (Web)

3. **Configure Allowed Origins** (CORS):
   - Add your app's domain or localhost for web platform

4. **Grant Types**:
   - Ensure "Authorization Code" grant is enabled
   - For password flows: enable "Resource Owner Password"

## API Reference

### Auth0Client

The main entry point for all Auth0 functionality. Initialize with domain and Client ID:

```dart
final auth0 = Auth0Client(
  domain: 'your-tenant.auth0.com',
  clientId: 'your_client_id',
  options: Auth0ClientOptions(
    enableDPoP: false,  // Optional: enable DPoP
    httpTimeout: Duration(seconds: 30),
  ),
);
```

Provides access to four main modules:

```dart
auth0.api          // AuthApi — pure Dart HTTP endpoints
auth0.webAuth      // WebAuth — browser-based OAuth flow
auth0.credentials  // CredentialStore — secure token storage
auth0.dpop         // DPoP — (if enabled) hardware-backed key proofs
```

Clean up resources when done:

```dart
auth0.close();  // Closes HTTP client and JWKS cache
```

### AuthApi Module

Thirteen pure Dart HTTP endpoints for direct API calls:

#### loginWithPassword
Username/password login using the Resource Owner Password flow:

```dart
try {
  final credentials = await auth0.api.loginWithPassword(
    usernameOrEmail: 'user@example.com',
    password: 'password',
    realm: 'Username-Password-Authentication',
    audience: 'https://api.example.com',
    scopes: {'openid', 'profile', 'email'},
  );
  print('Successfully logged in');
} on ApiException catch (e) {
  if (e.isInvalidCredentials) {
    print('Invalid username or password');
  } else if (e.isMultifactorRequired) {
    print('MFA required: ${e.mfaToken}');
  }
}
```

#### exchangeCode
Exchange authorization code for tokens (PKCE flow):

```dart
final credentials = await auth0.api.exchangeCode(
  code: authorizationCode,
  codeVerifier: pkceCodeVerifier,
  redirectUrl: 'com.example.app://your-tenant.auth0.com/ios/com.example.app/callback',
);
```

#### renewTokens
Refresh access and ID tokens:

```dart
final newCredentials = await auth0.api.renewTokens(
  refreshToken: credentials.refreshToken!,
  scopes: {'openid', 'profile', 'email'},
);
```

#### verifyMfaOtp
Verify a one-time password for MFA:

```dart
final credentials = await auth0.api.verifyMfaOtp(
  mfaToken: e.mfaToken!,
  otp: userEnteredOtp,
);
```

#### getMfaChallenge
Get an MFA challenge (e.g., for push notifications):

```dart
final challenge = await auth0.api.getMfaChallenge(
  mfaToken: mfaToken,
  challengeType: 'otp',  // or 'sms', 'push', etc.
);
```

#### startPasswordlessEmail
Initiate passwordless email login:

```dart
await auth0.api.startPasswordlessEmail(
  email: 'user@example.com',
  type: 'code',  // 'code' or 'link'
);
```

#### startPasswordlessSms
Initiate passwordless SMS login:

```dart
await auth0.api.startPasswordlessSms(
  phoneNumber: '+1234567890',
  type: 'code',  // 'code' or 'link'
);
```

#### loginWithEmailCode
Complete passwordless email login:

```dart
final credentials = await auth0.api.loginWithEmailCode(
  email: 'user@example.com',
  code: userEnteredCode,
  audience: 'https://api.example.com',
  scopes: {'openid', 'profile', 'email'},
);
```

#### loginWithSmsCode
Complete passwordless SMS login:

```dart
final credentials = await auth0.api.loginWithSmsCode(
  phoneNumber: '+1234567890',
  code: userEnteredCode,
  audience: 'https://api.example.com',
);
```

#### signup
Sign up a new user in a database connection:

```dart
try {
  final newUser = await auth0.api.signup(
    email: 'newuser@example.com',
    password: 'SecurePassword123!',
    connection: 'Username-Password-Authentication',
    username: 'newuser',
    userMetadata: {
      'plan': 'premium',
      'company': 'Acme Inc',
    },
  );
  print('User created: ${newUser.userId}');
} on ApiException catch (e) {
  if (e.isPasswordNotStrongEnough) {
    print('Password does not meet strength requirements');
  } else if (e.isAlreadyExists) {
    print('User already exists');
  }
}
```

#### getUserInfo
Fetch authenticated user's profile:

```dart
final userProfile = await auth0.api.getUserInfo(accessToken: accessToken);
print('User: ${userProfile.name}');
print('Email: ${userProfile.email}');
```

#### resetPassword
Request a password reset for a user:

```dart
await auth0.api.resetPassword(
  email: 'user@example.com',
  connection: 'Username-Password-Authentication',
);
```

#### customTokenExchange
Exchange a custom token (e.g., from another provider):

```dart
final credentials = await auth0.api.customTokenExchange(
  subjectToken: externalJwt,
  subjectTokenType: 'urn:ietf:params:oauth:token-type:jwt',
  audience: 'https://api.example.com',
  organization: 'org_123',
);
```

#### ssoExchange
Exchange a refresh token for a new set of tokens (useful for SSO scenarios):

```dart
final ssoCredentials = await auth0.api.ssoExchange(
  refreshToken: credentials.refreshToken!,
);
```

### WebAuth Module

Browser-based OAuth 2.0 + OpenID Connect flows with PKCE:

#### login
Perform a browser-based login with automatic callback handling:

```dart
try {
  final credentials = await auth0.webAuth.login(
    redirectUrl: 'com.example.app://your-tenant.auth0.com/ios/com.example.app/callback',
    audience: 'https://api.example.com',
    scopes: {'openid', 'profile', 'email'},
    organizationId: 'org_123',  // Optional: specify organization
    invitationUrl: inviteLink,   // Optional: for invitations
    maxAge: 3600,                // Optional: force recent authentication
    preferEphemeral: true,       // iOS: prefer ephemeral browser session
    parameters: {
      'custom_param': 'value',
    },
  );

  await auth0.credentials.storeCredentials(credentials);
} on WebAuthException catch (e) {
  if (e.isCancelled) {
    print('User cancelled login');
  } else if (e.isIdTokenValidationFailed) {
    print('ID token validation failed');
  }
}
```

#### logout
Clear sessions and redirect to Auth0 logout endpoint:

```dart
await auth0.webAuth.logout(
  returnToUrl: 'com.example.app://logout',
);
```

#### buildAuthorizeUrl
Build an authorization URL for custom handling (e.g., web redirect flow):

```dart
final uri = auth0.webAuth.buildAuthorizeUrl(
  redirectUrl: 'http://localhost:3000/callback',
  audience: 'https://api.example.com',
  scopes: {'openid', 'profile', 'email'},
);
print('Send user to: $uri');
```

#### handleCallback
Process a callback URL (for manual redirect flow handling):

```dart
final credentials = await auth0.webAuth.handleCallback(
  callbackUrl: 'com.example.app://your-tenant.auth0.com/ios/com.example.app/callback?code=...',
);
```

### CredentialStore Module

Secure token storage with flutter_secure_storage, auto-refresh, and optional biometrics:

#### storeCredentials
Store credentials securely:

```dart
await auth0.credentials.storeCredentials(credentials);
```

#### getCredentials
Retrieve valid credentials, auto-refreshing if needed:

```dart
try {
  final credentials = await auth0.credentials.getCredentials(
    minTtl: 60,  // Refresh if TTL < 60 seconds
    scopes: {'openid', 'profile', 'email'},
  );

  if (credentials != null) {
    print('Using token: ${credentials.accessToken}');
  } else {
    print('No credentials stored');
  }
} on CredentialStoreException catch (e) {
  if (e.isBiometricsAvailableButNotSet) {
    print('Biometrics available but not configured');
  } else if (e.isBiometricsUnavailable) {
    print('Device does not support biometrics');
  }
}
```

#### renewCredentials
Force a token refresh:

```dart
final newCredentials = await auth0.credentials.renewCredentials(
  scopes: {'openid', 'profile', 'email'},
);
```

#### clearCredentials
Remove stored credentials:

```dart
await auth0.credentials.clearCredentials();
```

#### hasCredentials
Check if credentials are stored:

```dart
final hasCredentials = await auth0.credentials.hasCredentials();
print('Logged in: $hasCredentials');
```

#### getUserProfile
Get the stored user's profile (decoded from ID token):

```dart
final profile = await auth0.credentials.getUserProfile();
if (profile != null) {
  print('User: ${profile.name}');
}
```

#### enableBiometrics / disableBiometrics
Enable or disable biometric authentication for credential access:

```dart
// Enable biometric requirement
await auth0.credentials.enableBiometrics();

// Now getCredentials will require biometric authentication
final credentials = await auth0.credentials.getCredentials();

// Disable biometric requirement
await auth0.credentials.disableBiometrics();
```

### DPoP Module

Hardware-backed key proofs for OAuth 2.0 Demonstration of Proof-of-Possession (optional):

```dart
// Enable DPoP in options
final auth0 = Auth0Client(
  domain: 'your-tenant.auth0.com',
  clientId: 'your_client_id',
  options: Auth0ClientOptions(enableDPoP: true),
);

// Initialize DPoP (generates ES256 key pair)
await auth0.dpop!.initialize();

// Generate DPoP headers for API calls
final headers = await auth0.dpop!.generateHeaders(
  url: 'https://your-api.example.com/resource',
  method: 'GET',
  accessToken: credentials.accessToken,
);

// Use headers in HTTP requests
final response = await http.get(
  Uri.parse('https://your-api.example.com/resource'),
  headers: {...headers, 'Authorization': 'DPoP ${credentials.accessToken}'},
);
```

## Platform Setup

### iOS

1. **Add URL Scheme** in `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.example.app</string>
    </array>
  </dict>
</array>
```

2. **Associated Domains** (for Universal Links, optional):

```xml
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:your-tenant.auth0.com</string>
</array>
```

3. For DPoP support, ensure the app has access to Secure Enclave. No additional setup required.

### macOS

1. **Add URL Scheme** in `macos/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.example.app</string>
    </array>
  </dict>
</array>
```

### Android

1. **Add Callback Activity** in `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
  android:name="com.auth0.flutter_auth.Auth0FlutterAuthCallbackActivity"
  android:exported="true">
  <intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
      android:scheme="com.example.app"
      android:host="your-tenant.auth0.com"
      android:path="/android/com.example.app/callback" />
  </intent-filter>
</activity>
```

2. Replace `com.example.app` with your app's package name and `your-tenant.auth0.com` with your Auth0 tenant.

3. For DPoP support, ensure your `minSdkVersion` is 23 or higher. Hardware-backed keys use Android Keystore.

### Web

For web platform support, use the optional `auth0-spa-js` adapter:

```dart
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

// Initialize Auth0SpaAdapter (must be called once on app startup)
Auth0SpaAdapter.initialize(
  domain: 'your-tenant.auth0.com',
  clientId: 'your_client_id',
);

// Use Auth0Client as normal — it will delegate to auth0-spa-js on web
final auth0 = Auth0Client(
  domain: 'your-tenant.auth0.com',
  clientId: 'your_client_id',
);

// Browser login works the same way
final credentials = await auth0.webAuth.login();
```

Add `auth0-spa-js` to your `web/index.html`:

```html
<script src="https://cdn.auth0.com/js/auth0-spa-js/2.0/auth0-spa-js.production.js"></script>
```

## Usage Examples

### Basic Login

```dart
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

final auth0 = Auth0Client(
  domain: 'your-tenant.auth0.com',
  clientId: 'your_client_id',
);

void login() async {
  try {
    final credentials = await auth0.webAuth.login(
      scopes: {'openid', 'profile', 'email'},
    );

    // Store securely
    await auth0.credentials.storeCredentials(credentials);

    // Use access token
    print('Logged in! Access token: ${credentials.accessToken}');
  } catch (e) {
    print('Error: $e');
  }
}
```

### Password-Based Login

```dart
void loginWithPassword() async {
  try {
    final credentials = await auth0.api.loginWithPassword(
      usernameOrEmail: 'user@example.com',
      password: 'password',
      realm: 'Username-Password-Authentication',
    );

    await auth0.credentials.storeCredentials(credentials);
    print('Logged in with password');
  } on ApiException catch (e) {
    if (e.isInvalidCredentials) {
      print('Invalid credentials');
    } else if (e.isMultifactorRequired) {
      print('MFA required');
    } else {
      print('Error: $e');
    }
  }
}
```

### Passwordless Login

```dart
void startPasswordlessEmail() async {
  try {
    await auth0.api.startPasswordlessEmail(email: 'user@example.com');
    print('Code sent to email. Waiting for user input...');
  } catch (e) {
    print('Error: $e');
  }
}

void completePasswordlessEmail() async {
  try {
    final credentials = await auth0.api.loginWithEmailCode(
      email: 'user@example.com',
      code: userEnteredCode,
    );

    await auth0.credentials.storeCredentials(credentials);
    print('Passwordless login successful');
  } catch (e) {
    print('Error: $e');
  }
}
```

### MFA

```dart
void handleMfaRequired(ApiException e) async {
  if (!e.isMultifactorRequired) return;

  final mfaToken = e.mfaToken;
  print('MFA required. Token: $mfaToken');

  // Get OTP challenge (if using SMS or authenticator app)
  final challenge = await auth0.api.getMfaChallenge(
    mfaToken: mfaToken!,
    challengeType: 'otp',
  );
  print('Challenge received. Delivery method: ${challenge.challengeType}');

  // User enters OTP
  final credentials = await auth0.api.verifyMfaOtp(
    mfaToken: mfaToken,
    otp: userEnteredOtp,
  );

  await auth0.credentials.storeCredentials(credentials);
  print('MFA verified. Now logged in.');
}
```

### User Profile

```dart
void fetchUserProfile() async {
  try {
    final credentials = await auth0.credentials.getCredentials();
    if (credentials == null) {
      print('Not logged in');
      return;
    }

    // Fetch from API
    final profile = await auth0.api.getUserInfo(accessToken: credentials.accessToken);
    print('Name: ${profile.name}');
    print('Email: ${profile.email}');
    print('Avatar: ${profile.picture}');

    // Or get from stored credentials
    final storedProfile = await auth0.credentials.getUserProfile();
    if (storedProfile != null) {
      print('Stored user sub: ${storedProfile.sub}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

### Token Refresh

```dart
void ensureValidToken() async {
  try {
    // Automatically refresh if TTL < 60 seconds
    final credentials = await auth0.credentials.getCredentials(minTtl: 60);

    if (credentials != null) {
      print('Token is valid. TTL: ${credentials.expiresIn} seconds');
    }
  } on CredentialStoreException catch (e) {
    if (e.isRefreshTokenExpired) {
      print('Refresh token expired. Need to log in again.');
    } else {
      print('Error: $e');
    }
  }
}
```

### Biometric Authentication

```dart
void setupBiometrics() async {
  try {
    // Check if device supports biometrics
    final isAvailable = await auth0.credentials.canUseBiometrics();

    if (isAvailable) {
      // Enable biometric requirement
      await auth0.credentials.enableBiometrics();
      print('Biometrics enabled');
    } else {
      print('Device does not support biometrics');
    }
  } on CredentialStoreException catch (e) {
    print('Biometric setup failed: $e');
  }
}

void getCredentialsWithBiometric() async {
  try {
    // This will prompt for biometric authentication
    final credentials = await auth0.credentials.getCredentials();

    if (credentials != null) {
      print('Retrieved credentials with biometric auth');
    }
  } on CredentialStoreException catch (e) {
    if (e.isBiometricAuthFailed) {
      print('Biometric authentication failed');
    } else {
      print('Error: $e');
    }
  }
}
```

### Logout

```dart
void logout() async {
  try {
    // Clear stored credentials
    await auth0.credentials.clearCredentials();

    // Optionally redirect to Auth0 logout endpoint
    await auth0.webAuth.logout(
      returnToUrl: 'com.example.app://logout',
    );

    print('Logged out');
  } catch (e) {
    print('Error during logout: $e');
  }
}
```

### DPoP

```dart
void setupDPoP() async {
  final auth0 = Auth0Client(
    domain: 'your-tenant.auth0.com',
    clientId: 'your_client_id',
    options: Auth0ClientOptions(enableDPoP: true),
  );

  // Initialize DPoP (generates keys)
  await auth0.dpop!.initialize();

  // Use in requests
  final credentials = await auth0.credentials.getCredentials();
  final headers = await auth0.dpop!.generateHeaders(
    url: 'https://api.example.com/resource',
    method: 'GET',
    accessToken: credentials?.accessToken,
  );

  // Make request with DPoP headers
  final response = await http.get(
    Uri.parse('https://api.example.com/resource'),
    headers: {
      ...headers,
      'Authorization': 'DPoP ${credentials?.accessToken}',
    },
  );

  print('Response: ${response.statusCode}');
}
```

## Error Handling

The SDK provides rich error information through exception hierarchies:

### ApiException

Used by `auth0.api.*` methods. Contains detailed error codes and flags:

```dart
try {
  await auth0.api.loginWithPassword(
    usernameOrEmail: 'user@example.com',
    password: 'password',
    realm: 'Username-Password-Authentication',
  );
} on ApiException catch (e) {
  print('Status Code: ${e.statusCode}');
  print('Error Code: ${e.errorCode}');
  print('Message: ${e.message}');

  // Use convenient boolean flags
  if (e.isInvalidCredentials) {
    showErrorSnackbar('Invalid username or password');
  } else if (e.isMultifactorRequired) {
    navigateToMfa(e.mfaToken!);
  } else if (e.isTooManyAttempts) {
    showErrorSnackbar('Too many login attempts. Try again later.');
  } else if (e.isPasswordNotStrongEnough) {
    showErrorSnackbar('Password does not meet strength requirements');
  } else if (e.isAlreadyExists) {
    showErrorSnackbar('User already exists');
  } else if (e.isNetworkError) {
    showErrorSnackbar('Network error. Check your connection.');
  } else {
    showErrorSnackbar(e.message);
  }
}
```

Available error flags:
- `isMultifactorRequired` — MFA is required; check `e.mfaToken`
- `isInvalidCredentials` — Wrong username/password
- `isRefreshTokenDeleted` — Refresh token was revoked
- `isPasswordNotStrongEnough` — Weak password during signup
- `isAlreadyExists` — User/username already exists
- `isTooManyAttempts` — Rate limit hit
- `isNetworkError` — Network connectivity issue
- And 12+ others (see `ApiException` docs)

### WebAuthException

Used by `auth0.webAuth.*` methods:

```dart
try {
  final credentials = await auth0.webAuth.login();
} on WebAuthException catch (e) {
  if (e.isCancelled) {
    print('User cancelled the login flow');
  } else if (e.isStateMismatch) {
    print('State mismatch — possible CSRF attack');
  } else if (e.isIdTokenValidationFailed) {
    print('ID token validation failed: ${e.message}');
  } else {
    print('Web auth error: ${e.message}');
  }
}
```

### CredentialStoreException

Used by `auth0.credentials.*` methods:

```dart
try {
  final credentials = await auth0.credentials.getCredentials();
} on CredentialStoreException catch (e) {
  if (e.isBiometricsUnavailable) {
    print('Device does not support biometrics');
  } else if (e.isBiometricAuthFailed) {
    print('Biometric authentication was rejected');
  } else if (e.isRefreshTokenExpired) {
    print('Refresh token expired. Please log in again.');
  } else if (e.isStorageError) {
    print('Failed to read from secure storage');
  } else {
    print('Credential store error: ${e.message}');
  }
}
```

### Other Exceptions

- **JwtException** — JWT validation or decoding failed
- **DPoPException** — DPoP key generation or proof signing failed
- **Auth0Exception** — Base exception for all Auth0 errors

## Testing

The SDK includes 176 unit tests with high coverage. Run tests with:

```bash
flutter test
```

Example test structure:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

void main() {
  group('Auth0Client', () {
    test('initializes with domain and clientId', () {
      final client = Auth0Client(
        domain: 'test.auth0.com',
        clientId: 'test_client_id',
      );

      expect(client.domain, 'test.auth0.com');
      expect(client.clientId, 'test_client_id');
    });
  });
}
```

## Architecture

### Design Philosophy

This SDK minimizes native code while maintaining security and features. Only two use cases require native bridges:

1. **Browser Launch** — ASWebAuthenticationSession (iOS/macOS) and Chrome Custom Tabs (Android) for secure OAuth flows
2. **DPoP Keys** — Hardware-backed key generation via Secure Enclave (iOS) and Android Keystore

Everything else is pure Dart:
- OAuth 2.0 + OpenID Connect flows (PKCE, state, nonce, code verification)
- JWT validation with JWKS caching and signature verification
- Secure token storage via flutter_secure_storage
- Biometric authentication via local_auth
- MFA, passwordless, custom token exchange, and 13+ API endpoints

### Code Organization

```
lib/src/
├── auth0_client.dart          # Main entry point
├── api/
│   ├── auth_api.dart          # 13 pure Dart HTTP endpoints
│   ├── auth_api_extensions.dart
│   └── http_client.dart        # HTTP wrapper with DPoP support
├── web_auth/
│   ├── web_auth.dart          # PKCE + browser flow
│   ├── browser_platform.dart   # Native platform bridge
│   ├── authorize_url_builder.dart
│   └── pkce.dart
├── credentials/
│   ├── credential_store.dart   # Secure storage + auto-refresh
│   ├── credential_store_options.dart
│   └── token_refresher.dart
├── dpop/
│   ├── dpop.dart
│   ├── dpop_platform.dart      # Native platform bridge
│   └── dpop_nonce_manager.dart
├── jwt/
│   ├── jwt_validator.dart      # RS256 validation
│   ├── jwt_decoder.dart
│   └── jwks_client.dart        # JWKS cache
├── models/
│   ├── credentials.dart        # Token model
│   ├── user_profile.dart
│   ├── database_user.dart
│   └── challenge.dart
├── exceptions/
│   ├── auth0_exception.dart    # Base
│   ├── api_exception.dart      # 20+ error flags
│   ├── web_auth_exception.dart
│   ├── credential_store_exception.dart
│   ├── jwt_exception.dart
│   └── dpop_exception.dart
└── web/                         # Web platform support
    ├── auth0_spa_adapter.dart
    └── js_interop.dart
```

### Native Code

**iOS/macOS** (~300 lines):
- `Auth0FlutterAuthPlugin` — ASWebAuthenticationSession launch
- `DPoPPlatform` — Secure Enclave key generation and signing

**Android** (~340 lines):
- `Auth0FlutterAuthPlugin` — Chrome Custom Tabs launch and callback
- `Auth0FlutterAuthCallbackActivity` — Callback receiver
- `DPoPPlatform` — Android Keystore key generation and signing

Total native code: ~640 lines (replaces ~40 native handler classes in full SDKs).

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Run `flutter test` to ensure all tests pass
5. Commit with clear messages
6. Push to your fork and open a Pull Request

### Development Setup

```bash
# Clone and install dependencies
git clone https://github.com/nicosabena/auth0-flutter.git
cd auth0_flutter_auth
flutter pub get

# Run tests
flutter test

# Run the example app (requires .env setup)
cd example
flutter run
```

### Example App Configuration

The example app uses `flutter_dotenv` to load credentials. Create `example/.env`:

```env
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_CLIENT_ID=your_client_id
AUTH0_REDIRECT_URL=com.example.app://your-tenant.auth0.com/ios/com.example.app/callback
```

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

For more information, visit [Auth0.com](https://auth0.com) or check out the [example app](example/).
