import 'auth0_exception.dart';

class CredentialStoreException extends Auth0Exception {
  final String code;

  CredentialStoreException({
    required String message,
    required this.code,
    dynamic cause,
  }) : super(message, cause: cause);

  static const _codeNoCredentials = 'a0.no_credentials';
  static const _codeNoRefreshToken = 'a0.no_refresh_token';
  static const _codeBiometricFailed = 'a0.biometric_failed';
  static const _codeStorageError = 'a0.storage_error';
  static const _codeRefreshFailed = 'a0.refresh_failed';

  bool get isNoCredentials => code == _codeNoCredentials;
  bool get isNoRefreshToken => code == _codeNoRefreshToken;
  bool get isBiometricFailed => code == _codeBiometricFailed;
  bool get isStorageError => code == _codeStorageError;
  bool get isRefreshFailed => code == _codeRefreshFailed;

  factory CredentialStoreException.noCredentials() =>
      CredentialStoreException(
        message: 'No credentials stored',
        code: _codeNoCredentials,
      );

  factory CredentialStoreException.noRefreshToken() =>
      CredentialStoreException(
        message: 'No refresh token available for renewal',
        code: _codeNoRefreshToken,
      );

  factory CredentialStoreException.biometricFailed({dynamic cause}) =>
      CredentialStoreException(
        message: 'Biometric authentication failed',
        code: _codeBiometricFailed,
        cause: cause,
      );

  factory CredentialStoreException.storageError({dynamic cause}) =>
      CredentialStoreException(
        message: 'Credential storage error',
        code: _codeStorageError,
        cause: cause,
      );

  factory CredentialStoreException.refreshFailed({dynamic cause}) =>
      CredentialStoreException(
        message: 'Token refresh failed',
        code: _codeRefreshFailed,
        cause: cause,
      );

  @override
  String toString() =>
      'CredentialStoreException(code: $code, message: $message)';
}
