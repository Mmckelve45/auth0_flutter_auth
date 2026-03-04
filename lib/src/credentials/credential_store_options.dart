enum SecureStorageAccessibility {
  afterFirstUnlock,
  afterFirstUnlockThisDevice,
  whenUnlocked,
  whenUnlockedThisDevice,
  whenPasscodeSetThisDevice,
}

enum BiometricPolicy {
  /// Prompt biometric authentication on every [getCredentials] call.
  always,

  /// Prompt once, then re-prompt after [biometricSessionTimeout] seconds.
  session,

  /// Prompt once while the app remains in the foreground.
  appLifecycle,

  /// No biometric authentication (default).
  disabled,
}

class CredentialStoreOptions {
  final bool requireBiometrics;
  final String biometricPrompt;
  final int defaultMinTtl;
  final String storageKey;
  final bool biometricOnly;
  final SecureStorageAccessibility? accessibility;
  final String? accessGroup;
  final BiometricPolicy biometricPolicy;
  final int biometricSessionTimeout;

  const CredentialStoreOptions({
    this.requireBiometrics = false,
    this.biometricPrompt = 'Authenticate to access credentials',
    this.defaultMinTtl = 0,
    this.storageKey = 'auth0_flutter_auth_credentials',
    this.biometricOnly = true,
    this.accessibility,
    this.accessGroup,
    this.biometricPolicy = BiometricPolicy.disabled,
    this.biometricSessionTimeout = 300,
  });
}
