/// Environment configuration for integration tests.
///
/// Values are injected at compile time via `--dart-define-from-file=.env.test`.
class TestConfig {
  static const domain = String.fromEnvironment('AUTH0_DOMAIN');
  static const clientId = String.fromEnvironment('AUTH0_CLIENT_ID');
  static const connection = String.fromEnvironment('AUTH0_CONNECTION');
  static const testEmail = String.fromEnvironment('TEST_USER_EMAIL');
  static const testPassword = String.fromEnvironment('TEST_USER_PASSWORD');
  static const mfaUserEmail = String.fromEnvironment('TEST_MFA_USER_EMAIL');
  static const mfaUserPassword =
      String.fromEnvironment('TEST_MFA_USER_PASSWORD');
  static const mfaTotpSecret =
      String.fromEnvironment('TEST_MFA_TOTP_SECRET');

  static bool get isConfigured =>
      domain.isNotEmpty && clientId.isNotEmpty && testEmail.isNotEmpty;

  static bool get hasMfaConfig =>
      mfaUserEmail.isNotEmpty && mfaTotpSecret.isNotEmpty;
}
