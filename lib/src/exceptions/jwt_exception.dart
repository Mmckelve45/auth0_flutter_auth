import 'auth0_exception.dart';

class JwtException extends Auth0Exception {
  final String code;

  JwtException({
    required String message,
    required this.code,
    dynamic cause,
  }) : super(message, cause: cause);

  static const _codeMalformed = 'a0.jwt_malformed';
  static const _codeExpired = 'a0.jwt_expired';
  static const _codeInvalidSignature = 'a0.jwt_invalid_signature';
  static const _codeInvalidIssuer = 'a0.jwt_invalid_issuer';
  static const _codeInvalidAudience = 'a0.jwt_invalid_audience';
  static const _codeInvalidNonce = 'a0.jwt_invalid_nonce';
  static const _codeJwksFetchError = 'a0.jwks_fetch_error';
  static const _codeKeyNotFound = 'a0.jwks_key_not_found';

  bool get isMalformed => code == _codeMalformed;
  bool get isExpired => code == _codeExpired;
  bool get isInvalidSignature => code == _codeInvalidSignature;
  bool get isInvalidIssuer => code == _codeInvalidIssuer;
  bool get isInvalidAudience => code == _codeInvalidAudience;
  bool get isInvalidNonce => code == _codeInvalidNonce;

  factory JwtException.malformed([String detail = '']) => JwtException(
        message: 'Malformed JWT${detail.isNotEmpty ? ': $detail' : ''}',
        code: _codeMalformed,
      );

  factory JwtException.expired() => JwtException(
        message: 'JWT has expired',
        code: _codeExpired,
      );

  factory JwtException.invalidSignature() => JwtException(
        message: 'JWT signature verification failed',
        code: _codeInvalidSignature,
      );

  factory JwtException.invalidIssuer(String expected, String actual) =>
      JwtException(
        message: 'Invalid issuer: expected "$expected", got "$actual"',
        code: _codeInvalidIssuer,
      );

  factory JwtException.invalidAudience(String expected, String actual) =>
      JwtException(
        message: 'Invalid audience: expected "$expected", got "$actual"',
        code: _codeInvalidAudience,
      );

  factory JwtException.invalidNonce(String expected, String actual) =>
      JwtException(
        message: 'Invalid nonce: expected "$expected", got "$actual"',
        code: _codeInvalidNonce,
      );

  factory JwtException.jwksFetchError({dynamic cause}) => JwtException(
        message: 'Failed to fetch JWKS',
        code: _codeJwksFetchError,
        cause: cause,
      );

  factory JwtException.keyNotFound(String kid) => JwtException(
        message: 'Key with kid "$kid" not found in JWKS',
        code: _codeKeyNotFound,
      );

  @override
  String toString() => 'JwtException(code: $code, message: $message)';
}
