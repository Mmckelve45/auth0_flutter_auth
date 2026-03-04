import 'auth0_exception.dart';

class PasskeyException extends Auth0Exception {
  final String code;

  PasskeyException({
    required String message,
    required this.code,
    dynamic cause,
  }) : super(message, cause: cause);

  static const _codeNotAvailable = 'a0.passkeys_not_available';
  static const _codeCancelled = 'a0.passkeys_cancelled';
  static const _codeRegistrationFailed = 'a0.passkeys_registration_failed';
  static const _codeAssertionFailed = 'a0.passkeys_assertion_failed';
  static const _codePlatformError = 'a0.passkeys_platform_error';

  bool get isNotAvailable => code == _codeNotAvailable;
  bool get isCancelled => code == _codeCancelled;
  bool get isRegistrationFailed => code == _codeRegistrationFailed;
  bool get isAssertionFailed => code == _codeAssertionFailed;

  factory PasskeyException.notAvailable({dynamic cause}) => PasskeyException(
        message: 'Passkeys are not available on this device.',
        code: _codeNotAvailable,
        cause: cause,
      );

  factory PasskeyException.cancelled({dynamic cause}) => PasskeyException(
        message: 'Passkey operation was cancelled by the user.',
        code: _codeCancelled,
        cause: cause,
      );

  factory PasskeyException.registrationFailed({dynamic cause}) =>
      PasskeyException(
        message: 'Passkey registration failed.',
        code: _codeRegistrationFailed,
        cause: cause,
      );

  factory PasskeyException.assertionFailed({dynamic cause}) =>
      PasskeyException(
        message: 'Passkey assertion (authentication) failed.',
        code: _codeAssertionFailed,
        cause: cause,
      );

  factory PasskeyException.platformError(String detail, {dynamic cause}) =>
      PasskeyException(
        message: 'Passkey platform error: $detail',
        code: _codePlatformError,
        cause: cause,
      );

  @override
  String toString() => 'PasskeyException(code: $code, message: $message)';
}
