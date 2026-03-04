library auth0_flutter_auth;

// Main entry point
export 'src/auth0_client.dart';
export 'src/auth0_client_options.dart';

// API
export 'src/api/auth_api.dart';
export 'src/api/http_client.dart';

// Web Auth
export 'src/web_auth/web_auth.dart';
export 'src/web_auth/web_auth_options.dart';

// Credentials
export 'src/credentials/credential_store.dart';
export 'src/credentials/credential_store_options.dart';

// DPoP
export 'src/dpop/dpop.dart';

// Passkeys
export 'src/passkeys/passkeys.dart';

// Models
export 'src/models/credentials.dart';
export 'src/models/user_profile.dart';
export 'src/models/database_user.dart';
export 'src/models/challenge.dart';
export 'src/models/sso_credentials.dart';
export 'src/models/passkey_challenge.dart';

// Exceptions
export 'src/exceptions/auth0_exception.dart';
export 'src/exceptions/api_exception.dart';
export 'src/exceptions/web_auth_exception.dart';
export 'src/exceptions/credential_store_exception.dart';
export 'src/exceptions/jwt_exception.dart';
export 'src/exceptions/dpop_exception.dart';
export 'src/exceptions/passkey_exception.dart';
