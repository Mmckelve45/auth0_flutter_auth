import 'credentials/credential_store_options.dart';

class Auth0ClientOptions {
  final bool enableDPoP;
  final bool enablePasskeys;
  final bool enableBiometrics;
  final String? audience;
  final Set<String> scopes;
  final CredentialStoreOptions? credentialStoreOptions;
  final Duration? httpTimeout;
  final Duration? jwtLeeway;

  const Auth0ClientOptions({
    this.enableDPoP = false,
    this.enablePasskeys = false,
    this.enableBiometrics = false,
    this.audience,
    this.scopes = const {'openid', 'profile', 'email'},
    this.credentialStoreOptions,
    this.httpTimeout,
    this.jwtLeeway,
  });
}
