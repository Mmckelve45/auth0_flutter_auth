import 'package:flutter_test/flutter_test.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

void main() {
  group('ApiException', () {
    test('fromResponse parses standard Auth0 error', () {
      final json = {
        'error': 'invalid_grant',
        'error_description': 'Wrong email or password.',
      };

      final e = ApiException.fromResponse(403, json);
      expect(e.statusCode, 403);
      expect(e.errorCode, 'invalid_grant');
      expect(e.errorDescription, 'Wrong email or password.');
      expect(e.isInvalidCredentials, true);
    });

    test('fromResponse parses code + message format', () {
      final json = {
        'code': 'too_many_attempts',
        'message': 'Too many attempts.',
      };

      final e = ApiException.fromResponse(429, json);
      expect(e.errorCode, 'too_many_attempts');
      expect(e.isTooManyAttempts, true);
    });

    test('isMultifactorRequired returns true and exposes mfaToken', () {
      final json = {
        'error': 'mfa_required',
        'error_description': 'MFA is required.',
        'mfa_token': 'mfa_tok_123',
      };

      final e = ApiException.fromResponse(403, json);
      expect(e.isMultifactorRequired, true);
      expect(e.mfaToken, 'mfa_tok_123');
    });

    test('isPasswordNotStrongEnough checks name field', () {
      final json = {
        'error': 'invalid_password',
        'error_description': 'Password too weak',
        'name': 'PasswordStrengthError',
      };

      final e = ApiException.fromResponse(400, json);
      expect(e.isPasswordNotStrongEnough, true);
      expect(e.isPasswordAlreadyUsed, false);
    });

    test('isPasswordAlreadyUsed checks name field', () {
      final json = {
        'error': 'invalid_password',
        'error_description': 'Password already used',
        'name': 'PasswordHistoryError',
      };

      final e = ApiException.fromResponse(400, json);
      expect(e.isPasswordAlreadyUsed, true);
      expect(e.isPasswordNotStrongEnough, false);
    });

    test('isRefreshTokenDeleted checks description content', () {
      final json = {
        'error': 'invalid_grant',
        'error_description': 'The refresh token has been revoked.',
      };

      final e = ApiException.fromResponse(403, json);
      expect(e.isRefreshTokenDeleted, true);
    });

    test('networkError creates correct exception', () {
      final e = ApiException.networkError(Exception('connection refused'));
      expect(e.isNetworkError, true);
      expect(e.statusCode, 0);
    });

    test('isAccessDenied flag', () {
      final e = ApiException.fromResponse(401, {
        'error': 'access_denied',
        'error_description': 'Access denied.',
      });
      expect(e.isAccessDenied, true);
    });

    test('isAlreadyExists for user_exists', () {
      final e = ApiException.fromResponse(409, {
        'error': 'user_exists',
        'error_description': 'User already exists.',
      });
      expect(e.isAlreadyExists, true);
    });

    test('isAlreadyExists for username_exists', () {
      final e = ApiException.fromResponse(409, {
        'error': 'username_exists',
        'error_description': 'Username already exists.',
      });
      expect(e.isAlreadyExists, true);
    });

    test('isRuleError flag', () {
      final e = ApiException.fromResponse(401, {
        'error': 'unauthorized',
        'error_description': 'Rule error.',
      });
      expect(e.isRuleError, true);
    });

    test('isLoginRequired flag', () {
      final e = ApiException.fromResponse(401, {
        'error': 'login_required',
        'error_description': 'Login required.',
      });
      expect(e.isLoginRequired, true);
    });

    test('isMultifactorCodeInvalid flag', () {
      final e = ApiException.fromResponse(403, {
        'error': 'invalid_otp',
        'error_description': 'Invalid OTP.',
      });
      expect(e.isMultifactorCodeInvalid, true);
    });

    test('isMultifactorTokenInvalid flag', () {
      final e = ApiException.fromResponse(401, {
        'error': 'expired_token',
        'error_description': 'Token expired.',
      });
      expect(e.isMultifactorTokenInvalid, true);
    });

    test('isBlockedUser flag', () {
      final e = ApiException.fromResponse(403, {
        'error': 'blocked_user',
        'error_description': 'Blocked.',
      });
      expect(e.isBlockedUser, true);
    });

    test('isPasswordLeaked flag', () {
      final e = ApiException.fromResponse(400, {
        'error': 'password_leaked',
        'error_description': 'Leaked.',
      });
      expect(e.isPasswordLeaked, true);
    });

    test('isVerificationRequired flag', () {
      final e = ApiException.fromResponse(403, {
        'error': 'requires_verification',
        'error_description': 'Verification required.',
      });
      expect(e.isVerificationRequired, true);
    });

    test('isInvalidScope flag', () {
      final e = ApiException.fromResponse(400, {
        'error': 'invalid_scope',
        'error_description': 'Invalid scope.',
      });
      expect(e.isInvalidScope, true);
    });

    test('isInvalidConnection flag', () {
      final e = ApiException.fromResponse(400, {
        'error': 'invalid_connection',
        'error_description': 'Invalid connection.',
      });
      expect(e.isInvalidConnection, true);
    });
  });

  group('WebAuthException', () {
    test('cancelled has correct code', () {
      final e = WebAuthException.cancelled();
      expect(e.isCancelled, true);
    });

    test('stateMismatch has correct code', () {
      final e = WebAuthException.stateMismatch();
      expect(e.isStateMismatch, true);
    });

    test('idTokenValidation includes detail', () {
      final e = WebAuthException.idTokenValidation('expired');
      expect(e.isIdTokenValidationFailed, true);
      expect(e.message, contains('expired'));
    });
  });

  group('CredentialStoreException', () {
    test('noCredentials has correct code', () {
      final e = CredentialStoreException.noCredentials();
      expect(e.isNoCredentials, true);
    });

    test('noRefreshToken has correct code', () {
      final e = CredentialStoreException.noRefreshToken();
      expect(e.isNoRefreshToken, true);
    });

    test('biometricFailed has correct code', () {
      final e = CredentialStoreException.biometricFailed();
      expect(e.isBiometricFailed, true);
    });
  });

  group('JwtException', () {
    test('malformed includes detail', () {
      final e = JwtException.malformed('bad header');
      expect(e.isMalformed, true);
      expect(e.message, contains('bad header'));
    });

    test('expired flag', () {
      final e = JwtException.expired();
      expect(e.isExpired, true);
    });

    test('invalidSignature flag', () {
      final e = JwtException.invalidSignature();
      expect(e.isInvalidSignature, true);
    });

    test('invalidIssuer includes expected and actual', () {
      final e = JwtException.invalidIssuer('expected.com', 'actual.com');
      expect(e.isInvalidIssuer, true);
      expect(e.message, contains('expected.com'));
      expect(e.message, contains('actual.com'));
    });

    test('invalidAudience includes expected and actual', () {
      final e = JwtException.invalidAudience('client1', 'client2');
      expect(e.isInvalidAudience, true);
    });

    test('invalidNonce includes expected and actual', () {
      final e = JwtException.invalidNonce('nonce1', 'nonce2');
      expect(e.isInvalidNonce, true);
    });

    test('keyNotFound includes kid', () {
      final e = JwtException.keyNotFound('kid123');
      expect(e.message, contains('kid123'));
    });
  });

  group('DPoPException', () {
    test('notInitialized has correct code', () {
      final e = DPoPException.notInitialized();
      expect(e.isNotInitialized, true);
    });

    test('keyGenerationFailed has correct code', () {
      final e = DPoPException.keyGenerationFailed();
      expect(e.isKeyGenerationFailed, true);
    });

    test('signingFailed has correct code', () {
      final e = DPoPException.signingFailed();
      expect(e.isSigningFailed, true);
    });
  });
}
