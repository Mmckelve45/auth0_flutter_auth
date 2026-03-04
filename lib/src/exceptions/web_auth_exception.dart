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

  // ── SPA adapter factories ──

  static const _codeSpaNotInitialized = 'a0.spa_not_initialized';
  static const _codeSpaLibraryMissing = 'a0.spa_library_missing';
  static const _codePopupBlocked = 'a0.popup_blocked';
  static const _codeLoginRequired = 'a0.login_required';

  bool get isSpaNotInitialized => code == _codeSpaNotInitialized;
  bool get isSpaLibraryMissing => code == _codeSpaLibraryMissing;
  bool get isPopupBlocked => code == _codePopupBlocked;
  bool get isLoginRequired => code == _codeLoginRequired;

  factory WebAuthException.spaNotInitialized() => WebAuthException(
        message:
            'Auth0SpaAdapter has not been initialized. Call onLoad() first.',
        code: _codeSpaNotInitialized,
      );

  factory WebAuthException.spaLibraryMissing() => WebAuthException(
        message: 'auth0-spa-js is not loaded. Add the following script tag to '
            'your web/index.html:\n'
            '<script src="https://cdn.auth0.com/js/auth0-spa-js/2.1/auth0-spa-js.production.js"></script>',
        code: _codeSpaLibraryMissing,
      );

  factory WebAuthException.popupBlocked() => WebAuthException(
        message: 'The login popup was blocked by the browser. '
            'Ensure popups are allowed for this origin.',
        code: _codePopupBlocked,
      );

  factory WebAuthException.loginRequired() => WebAuthException(
        message: 'No valid session found. The user must log in.',
        code: _codeLoginRequired,
      );

  @override
  String toString() => 'WebAuthException(code: $code, message: $message)';
}
