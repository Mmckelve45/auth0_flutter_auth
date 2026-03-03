import 'auth0_exception.dart';

class DPoPException extends Auth0Exception {
  final String code;

  DPoPException({
    required String message,
    required this.code,
    dynamic cause,
  }) : super(message, cause: cause);

  static const _codeNotInitialized = 'a0.dpop_not_initialized';
  static const _codeKeyGenerationFailed = 'a0.dpop_key_generation_failed';
  static const _codeSigningFailed = 'a0.dpop_signing_failed';
  static const _codePlatformError = 'a0.dpop_platform_error';

  bool get isNotInitialized => code == _codeNotInitialized;
  bool get isKeyGenerationFailed => code == _codeKeyGenerationFailed;
  bool get isSigningFailed => code == _codeSigningFailed;

  factory DPoPException.notInitialized() => DPoPException(
        message: 'DPoP has not been initialized. Call initialize() first.',
        code: _codeNotInitialized,
      );

  factory DPoPException.keyGenerationFailed({dynamic cause}) => DPoPException(
        message: 'Failed to generate DPoP key pair',
        code: _codeKeyGenerationFailed,
        cause: cause,
      );

  factory DPoPException.signingFailed({dynamic cause}) => DPoPException(
        message: 'Failed to sign DPoP proof',
        code: _codeSigningFailed,
        cause: cause,
      );

  factory DPoPException.platformError(String detail, {dynamic cause}) =>
      DPoPException(
        message: 'DPoP platform error: $detail',
        code: _codePlatformError,
        cause: cause,
      );

  @override
  String toString() => 'DPoPException(code: $code, message: $message)';
}
