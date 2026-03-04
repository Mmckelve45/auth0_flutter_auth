import 'dart:convert';
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
Future<Credentials> loginTestUser(AuthApi api) {
  return api.loginWithPassword(
    usernameOrEmail: TestConfig.testEmail,
    password: TestConfig.testPassword,
    realm: TestConfig.connection,
    scopes: {'openid', 'profile', 'email', 'offline_access'},
  );
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
