import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';
import 'package:otp/otp.dart';

import '../config/test_config.dart';
import '../helpers/test_helpers.dart';

/// Helper that logs in the MFA user and extracts the mfa_token.
///
/// Fails with a diagnostic message if the login doesn't trigger MFA
/// (e.g. grant type not enabled, wrong credentials).
Future<String> _loginAndGetMfaToken(AuthApi api) async {
  try {
    await api.loginWithPassword(
      usernameOrEmail: TestConfig.mfaUserEmail,
      password: TestConfig.mfaUserPassword,
      realm: TestConfig.connection,
    );
    fail('Should have thrown ApiException with mfa_required');
  } on ApiException catch (e) {
    if (e.isMultifactorRequired) {
      return e.mfaToken!;
    }
    // Not an MFA error — likely a config issue
    fail(diagnoseApiError(e));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final skip = !TestConfig.hasMfaConfig
      ? 'MFA config not provided in .env.test'
      : null;

  late Auth0Client client;

  setUp(() {
    client = createTestClient();
  });

  tearDown(() {
    client.close();
  });

  group('MFA flow', skip: skip, () {
    testWidgets('login for MFA-enrolled user throws mfa_required',
        (tester) async {
      final mfaToken = await _loginAndGetMfaToken(client.api);
      expect(mfaToken, isNotEmpty);
    });

    testWidgets('getMfaChallenge returns otp challenge', (tester) async {
      final mfaToken = await _loginAndGetMfaToken(client.api);

      final challenge = await client.api.getMfaChallenge(
        mfaToken: mfaToken,
        challengeType: 'otp',
      );

      expect(challenge.challengeType, 'otp');
    });

    testWidgets('verifyMfaOtp with valid TOTP code returns Credentials',
        (tester) async {
      final mfaToken = await _loginAndGetMfaToken(client.api);

      // Generate a real TOTP code from the shared secret
      final code = OTP.generateTOTPCodeString(
        TestConfig.mfaTotpSecret,
        DateTime.now().millisecondsSinceEpoch,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );

      final creds = await client.api.verifyMfaOtp(
        mfaToken: mfaToken,
        otp: code,
      );

      expect(creds.accessToken, isNotEmpty);
    });

    testWidgets('verifyMfaOtp with wrong code throws ApiException',
        (tester) async {
      final mfaToken = await _loginAndGetMfaToken(client.api);

      try {
        await client.api.verifyMfaOtp(
          mfaToken: mfaToken,
          otp: '000000',
        );
        fail('Should have thrown ApiException');
      } on ApiException catch (e) {
        expect(
          e.isMultifactorCodeInvalid || e.errorCode == 'invalid_grant',
          isTrue,
        );
      }
    });

    testWidgets('verifyMfaRecoveryCode with invalid code throws ApiException',
        (tester) async {
      final mfaToken = await _loginAndGetMfaToken(client.api);

      try {
        await client.api.verifyMfaRecoveryCode(
          mfaToken: mfaToken,
          recoveryCode: 'INVALID-RECOVERY-CODE',
        );
        fail('Should have thrown ApiException');
      } on ApiException {
        // Expected
      }
    });

    testWidgets('full MFA chain: login → challenge → TOTP → Credentials',
        (tester) async {
      // Step 1: Login triggers mfa_required
      final mfaToken = await _loginAndGetMfaToken(client.api);

      // Step 2: Request OTP challenge
      final challenge = await client.api.getMfaChallenge(
        mfaToken: mfaToken,
        challengeType: 'otp',
      );
      expect(challenge.challengeType, 'otp');

      // Step 3: Generate TOTP code
      final code = OTP.generateTOTPCodeString(
        TestConfig.mfaTotpSecret,
        DateTime.now().millisecondsSinceEpoch,
        algorithm: Algorithm.SHA1,
        isGoogle: true,
      );

      // Step 4: Verify OTP
      final creds = await client.api.verifyMfaOtp(
        mfaToken: mfaToken,
        otp: code,
      );

      expect(creds.accessToken, isNotEmpty);
      expect(creds.idToken, isNotNull);
    });
  });
}
