class CredentialStoreOptions {
  final bool requireBiometrics;
  final String biometricPrompt;
  final int defaultMinTtl;
  final String storageKey;

  const CredentialStoreOptions({
    this.requireBiometrics = false,
    this.biometricPrompt = 'Authenticate to access credentials',
    this.defaultMinTtl = 0,
    this.storageKey = 'auth0_flutter_auth_credentials',
  });
}
