import 'auth0_exception.dart';

class WebAuthException extends Auth0Exception {
  final String code;

  WebAuthException({
    required String message,
    required this.code,
    dynamic cause,
  }) : super(message, cause: cause);

  static const _codeCancelled = 'a0.user_cancelled';
  static const _codeStateMismatch = 'a0.state_mismatch';
  static const _codeIdTokenValidation = 'a0.id_token_validation';
  static const _codeNoCallbackUrl = 'a0.no_callback_url';
  static const _codePkceNotAvailable = 'a0.pkce_not_available';
  static const _codeUnknown = 'a0.unknown';

  bool get isCancelled => code == _codeCancelled;
  bool get isStateMismatch => code == _codeStateMismatch;
  bool get isIdTokenValidationFailed => code == _codeIdTokenValidation;

  factory WebAuthException.cancelled() => WebAuthException(
        message: 'User cancelled the authentication',
        code: _codeCancelled,
      );

  factory WebAuthException.stateMismatch() => WebAuthException(
        message: 'State parameter mismatch',
        code: _codeStateMismatch,
      );

  factory WebAuthException.idTokenValidation(String detail) =>
      WebAuthException(
        message: 'ID token validation failed: $detail',
        code: _codeIdTokenValidation,
      );

  factory WebAuthException.noCallbackUrl() => WebAuthException(
        message: 'No callback URL received from browser',
        code: _codeNoCallbackUrl,
      );

  factory WebAuthException.unknown({dynamic cause}) => WebAuthException(
        message: 'Unknown web auth error',
        code: _codeUnknown,
        cause: cause,
      );

  @override
  String toString() => 'WebAuthException(code: $code, message: $message)';
}
