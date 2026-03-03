import 'auth0_exception.dart';

class ApiException extends Auth0Exception {
  final int statusCode;
  final String errorCode;
  final String? errorDescription;
  final Map<String, dynamic>? body;

  ApiException({
    required String message,
    required this.statusCode,
    this.errorCode = 'unknown_error',
    this.errorDescription,
    this.body,
    dynamic cause,
  }) : super(message, cause: cause);

  factory ApiException.fromResponse(int statusCode, Map<String, dynamic> json) {
    final error = json['error'] as String? ??
        json['code'] as String? ??
        'unknown_error';
    final description = json['error_description'] as String? ??
        json['message'] as String? ??
        json['description'] as String? ??
        'Unknown error';

    return ApiException(
      message: description,
      statusCode: statusCode,
      errorCode: error,
      errorDescription: description,
      body: json,
    );
  }

  factory ApiException.networkError(dynamic cause) {
    return ApiException(
      message: 'Network error',
      statusCode: 0,
      errorCode: 'network_error',
      cause: cause,
    );
  }

  // Auth0 error flags — parsed from error code and response
  bool get isMultifactorRequired => errorCode == 'mfa_required';
  bool get isMultifactorEnrollRequired =>
      errorCode == 'unsupported_challenge_type';
  bool get isMultifactorTokenInvalid =>
      errorCode == 'expired_token' && statusCode == 401;
  bool get isMultifactorCodeInvalid => errorCode == 'invalid_otp';
  bool get isPasswordNotStrongEnough =>
      errorCode == 'invalid_password' &&
      body?['name'] == 'PasswordStrengthError';
  bool get isPasswordAlreadyUsed =>
      errorCode == 'invalid_password' &&
      body?['name'] == 'PasswordHistoryError';
  bool get isRuleError => errorCode == 'unauthorized';
  bool get isInvalidCredentials =>
      errorCode == 'invalid_grant' ||
      errorCode == 'invalid_user_password' ||
      errorCode == 'wrong_email_or_password';
  bool get isRefreshTokenDeleted =>
      errorCode == 'invalid_grant' &&
      (errorDescription?.toLowerCase().contains('refresh token') ?? false);
  bool get isAccessDenied => errorCode == 'access_denied';
  bool get isTooManyAttempts => errorCode == 'too_many_attempts';
  bool get isVerificationRequired =>
      errorCode == 'requires_verification';
  bool get isNetworkError => errorCode == 'network_error';
  bool get isInvalidScope => errorCode == 'invalid_scope';
  bool get isLoginRequired => errorCode == 'login_required';
  bool get isPasswordLeaked =>
      errorCode == 'password_leaked';
  bool get isBlockedUser => errorCode == 'blocked_user';
  bool get isAlreadyExists =>
      errorCode == 'user_exists' || errorCode == 'username_exists';
  bool get isInvalidConnection => errorCode == 'invalid_connection';
  bool get isBotDetected => errorCode == 'requires_verification';

  String? get mfaToken => body?['mfa_token'] as String?;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, errorCode: $errorCode, message: $message)';
}
