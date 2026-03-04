import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';
import '../config/test_config.dart';

/// Creates an [Auth0Client] configured from the test environment.
Auth0Client createTestClient() {
  assert(TestConfig.isConfigured, 'Auth0 test config not set. '
      'Run with --dart-define-from-file=.env.test');
  return Auth0Client(
    domain: TestConfig.domain,
    clientId: TestConfig.clientId,
  );
}

/// Logs in with the primary test user and returns [Credentials].
///
/// Wraps `loginWithPassword` with diagnostic messages for common
/// Auth0 tenant configuration errors.
Future<Credentials> loginTestUser(AuthApi api) async {
  try {
    return await api.loginWithPassword(
      usernameOrEmail: TestConfig.testEmail,
      password: TestConfig.testPassword,
      realm: TestConfig.connection,
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );
  } on ApiException catch (e) {
    fail('${diagnoseApiError(e)}\n\nOriginal: $e');
  }
}

/// Returns a human-readable diagnostic message for common Auth0 config errors.
///
/// Call this in test `catch` blocks to surface actionable guidance when a
/// test fails due to tenant misconfiguration rather than a real bug.
String diagnoseApiError(ApiException e) {
  final msg = e.message.toLowerCase();
  final code = e.errorCode;

  if (code == 'unauthorized_client') {
    if (msg.contains('password-realm') || msg.contains('password')) {
      return 'AUTH0 CONFIG: The "Password" (Resource Owner Password) grant '
          'type is not enabled.\n'
          '  -> Dashboard > Applications > Your App > Settings > '
          'Advanced Settings > Grant Types > enable "Password"';
    }
    if (msg.contains('mfa')) {
      return 'AUTH0 CONFIG: The "MFA" grant type is not enabled.\n'
          '  -> Dashboard > Applications > Your App > Settings > '
          'Advanced Settings > Grant Types > enable "MFA"';
    }
    return 'AUTH0 CONFIG: A required grant type is not enabled for this '
        'client (unauthorized_client).\n'
        '  -> Dashboard > Applications > Your App > Settings > '
        'Advanced Settings > Grant Types\n'
        '  Server message: ${e.message}';
  }

  if (code == 'invalid_grant' && msg.contains('refresh token')) {
    return 'AUTH0 CONFIG: Refresh tokens may not be enabled or the token '
        'was already revoked.\n'
        '  -> Ensure "offline_access" scope is allowed and refresh token '
        'rotation settings are correct in your API and Application config.';
  }

  if (code == 'access_denied' && msg.contains('connection')) {
    return 'AUTH0 CONFIG: The database connection '
        '"${TestConfig.connection}" is not enabled for this application.\n'
        '  -> Dashboard > Applications > Your App > Connections > '
        'enable "${TestConfig.connection}"';
  }

  if (e.isInvalidCredentials) {
    return 'AUTH0 CONFIG: Invalid credentials — check TEST_USER_EMAIL and '
        'TEST_USER_PASSWORD in .env.test, and verify the user exists in '
        'the "${TestConfig.connection}" connection.';
  }

  if (code == 'unauthorized' && msg.contains('not authorized')) {
    return 'AUTH0 CONFIG: The connection or API is not authorized.\n'
        '  -> Dashboard > Applications > Your App > Connections > '
        'verify the database connection is enabled.\n'
        '  -> If using an audience, check API > Authorized Applications.';
  }

  // No specific diagnosis — return the raw error
  return 'ApiException: statusCode=${e.statusCode}, '
      'errorCode=$code, message=${e.message}';
}

/// Builds a fake but structurally valid JWT for credential storage tests.
///
/// The token is NOT cryptographically signed — it only needs to be
/// parseable by the SDK's JWT decoder for `user()` extraction.
String buildFakeIdToken({
  String sub = 'auth0|test',
  String? email,
  String? name,
}) {
  final header = _base64UrlEncode('{"alg":"RS256","typ":"JWT"}');
  final payloadMap = <String, dynamic>{
    'sub': sub,
    'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    if (email != null) 'email': email,
    if (name != null) 'name': name,
  };
  final payload = _base64UrlEncode(jsonEncode(payloadMap));
  final sig = _base64UrlEncode('fakesig');
  return '$header.$payload.$sig';
}

/// Generates a unique email for signup tests to avoid collisions.
String uniqueTestEmail() {
  final ts = DateTime.now().millisecondsSinceEpoch;
  return 'test+$ts@integration.test';
}

String _base64UrlEncode(String input) {
  return base64Url.encode(utf8.encode(input)).replaceAll('=', '');
}
