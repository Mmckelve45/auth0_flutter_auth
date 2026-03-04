import 'http_client.dart';
import '../models/credentials.dart';
import '../models/user_profile.dart';
import '../models/database_user.dart';
import '../models/challenge.dart';
import '../models/sso_credentials.dart';
import '../models/passkey_challenge.dart';

class AuthApi {
  final Auth0HttpClient _client;
  final String _clientId;

  AuthApi({required Auth0HttpClient client, required String clientId})
      : _client = client,
        _clientId = clientId;

  Future<Credentials> loginWithPassword({
    required String usernameOrEmail,
    required String password,
    required String realm,
    String? audience,
    Set<String> scopes = const {},
    Map<String, String>? parameters,
  }) async {
    final body = <String, dynamic>{
      'grant_type': 'http://auth0.com/oauth/grant-type/password-realm',
      'client_id': _clientId,
      'username': usernameOrEmail,
      'password': password,
      'realm': realm,
      if (audience != null) 'audience': audience,
      if (scopes.isNotEmpty) 'scope': scopes.join(' '),
      ...?parameters,
    };
    final json = await _client.post('/oauth/token', body);
    return Credentials.fromJson(json);
  }

  Future<Credentials> exchangeCode({
    required String code,
    required String codeVerifier,
    required String redirectUrl,
    String? nonce,
  }) async {
    final body = <String, dynamic>{
      'grant_type': 'authorization_code',
      'client_id': _clientId,
      'code': code,
      'code_verifier': codeVerifier,
      'redirect_uri': redirectUrl,
    };
    final json = await _client.post('/oauth/token', body);
    return Credentials.fromJson(json);
  }

  Future<Credentials> renewTokens({
    required String refreshToken,
    Set<String> scopes = const {},
    Map<String, String>? parameters,
  }) async {
    final body = <String, dynamic>{
      'grant_type': 'refresh_token',
      'client_id': _clientId,
      'refresh_token': refreshToken,
      if (scopes.isNotEmpty) 'scope': scopes.join(' '),
      ...?parameters,
    };
    final json = await _client.post('/oauth/token', body);
    return Credentials.fromJson(json);
  }

  Future<Credentials> verifyMfaOtp({
    required String mfaToken,
    required String otp,
  }) async {
    final body = <String, dynamic>{
      'grant_type': 'http://auth0.com/oauth/grant-type/mfa-otp',
      'client_id': _clientId,
      'mfa_token': mfaToken,
      'otp': otp,
    };
    final json = await _client.post('/oauth/token', body);
    return Credentials.fromJson(json);
  }

  Future<Challenge> getMfaChallenge({
    required String mfaToken,
    String? challengeType,
    String? authenticatorId,
  }) async {
    final body = <String, dynamic>{
      'client_id': _clientId,
      'mfa_token': mfaToken,
      if (challengeType != null) 'challenge_type': challengeType,
      if (authenticatorId != null) 'authenticator_id': authenticatorId,
    };
    final json = await _client.post('/mfa/challenge', body);
    return Challenge.fromJson(json);
  }

  Future<void> startPasswordlessEmail({
    required String email,
    String type = 'code',
  }) async {
    final body = <String, dynamic>{
      'client_id': _clientId,
      'connection': 'email',
      'email': email,
      'send': type,
    };
    await _client.post('/passwordless/start', body);
  }

  Future<void> startPasswordlessSms({
    required String phoneNumber,
    String type = 'code',
  }) async {
    final body = <String, dynamic>{
      'client_id': _clientId,
      'connection': 'sms',
      'phone_number': phoneNumber,
      'send': type,
    };
    await _client.post('/passwordless/start', body);
  }

  Future<Credentials> loginWithEmailCode({
    required String email,
    required String code,
    String? audience,
    Set<String> scopes = const {},
    Map<String, String>? parameters,
  }) async {
    final body = <String, dynamic>{
      'grant_type': 'http://auth0.com/oauth/grant-type/passwordless/otp',
      'client_id': _clientId,
      'username': email,
      'otp': code,
      'realm': 'email',
      if (audience != null) 'audience': audience,
      if (scopes.isNotEmpty) 'scope': scopes.join(' '),
      ...?parameters,
    };
    final json = await _client.post('/oauth/token', body);
    return Credentials.fromJson(json);
  }

  Future<Credentials> loginWithSmsCode({
    required String phoneNumber,
    required String code,
    String? audience,
    Set<String> scopes = const {},
    Map<String, String>? parameters,
  }) async {
    final body = <String, dynamic>{
      'grant_type': 'http://auth0.com/oauth/grant-type/passwordless/otp',
      'client_id': _clientId,
      'username': phoneNumber,
      'otp': code,
      'realm': 'sms',
      if (audience != null) 'audience': audience,
      if (scopes.isNotEmpty) 'scope': scopes.join(' '),
      ...?parameters,
    };
    final json = await _client.post('/oauth/token', body);
    return Credentials.fromJson(json);
  }

  Future<DatabaseUser> signup({
    required String email,
    required String password,
    required String connection,
    String? username,
    Map<String, dynamic>? userMetadata,
  }) async {
    final body = <String, dynamic>{
      'client_id': _clientId,
      'email': email,
      'password': password,
      'connection': connection,
      if (username != null) 'username': username,
      if (userMetadata != null) 'user_metadata': userMetadata,
    };
    final json = await _client.post('/dbconnections/signup', body);
    return DatabaseUser.fromJson(json);
  }

  Future<UserProfile> getUserInfo({
    required String accessToken,
    String tokenType = 'Bearer',
    Map<String, String> parameters = const {},
  }) async {
    final path = parameters.isEmpty
        ? '/userinfo'
        : '/userinfo?${Uri(queryParameters: parameters).query}';
    final json = await _client.get(
      path,
      extraHeaders: {'Authorization': '$tokenType $accessToken'},
    );
    return UserProfile.fromJson(json);
  }

  Future<void> resetPassword({
    required String email,
    required String connection,
  }) async {
    final body = <String, dynamic>{
      'client_id': _clientId,
      'email': email,
      'connection': connection,
    };
    await _client.post('/dbconnections/change_password', body);
  }

  Future<Credentials> customTokenExchange({
    required String subjectToken,
    required String subjectTokenType,
    String? audience,
    Set<String> scopes = const {},
    String? organization,
  }) async {
    final body = <String, dynamic>{
      'grant_type': 'urn:ietf:params:oauth:grant-type:token-exchange',
      'client_id': _clientId,
      'subject_token': subjectToken,
      'subject_token_type': subjectTokenType,
      if (audience != null) 'audience': audience,
      if (scopes.isNotEmpty) 'scope': scopes.join(' '),
      if (organization != null) 'organization': organization,
    };
    final json = await _client.post('/oauth/token', body);
    return Credentials.fromJson(json);
  }

  Future<SSOCredentials> ssoExchange({
    required String refreshToken,
    Map<String, String>? parameters,
    Map<String, String>? headers,
  }) async {
    final body = <String, dynamic>{
      'grant_type':
          'http://auth0.com/oauth/grant-type/sso-exchange-refresh-token',
      'client_id': _clientId,
      'refresh_token': refreshToken,
      ...?parameters,
    };
    final json = await _client.post('/oauth/token', body, extraHeaders: headers);
    return SSOCredentials.fromJson(json);
  }

  // ---------------------------------------------------------------------------
  // Passkeys (Limited Early Access)
  // ---------------------------------------------------------------------------

  Future<PasskeyChallenge> passkeyRegisterChallenge({
    required String email,
    String? name,
    String? realm,
  }) async {
    final body = <String, dynamic>{
      'client_id': _clientId,
      'email': email,
      if (name != null) 'name': name,
      if (realm != null) 'realm': realm,
    };
    final json = await _client.post('/passkey/register', body);
    return PasskeyChallenge.fromJson(json);
  }

  Future<PasskeyChallenge> passkeyLoginChallenge({String? realm}) async {
    final body = <String, dynamic>{
      'client_id': _clientId,
      if (realm != null) 'realm': realm,
    };
    final json = await _client.post('/passkey/challenge', body);
    return PasskeyChallenge.fromJson(json);
  }

  Future<Credentials> authenticateWithPasskey({
    required String authSession,
    required Map<String, dynamic> authnResponse,
    String? audience,
    Set<String> scopes = const {},
  }) async {
    final body = <String, dynamic>{
      'grant_type': 'urn:okta:params:oauth:grant-type:webauthn',
      'client_id': _clientId,
      'auth_session': authSession,
      'authn_response': authnResponse,
      if (audience != null) 'audience': audience,
      if (scopes.isNotEmpty) 'scope': scopes.join(' '),
    };
    final json = await _client.post('/oauth/token', body);
    return Credentials.fromJson(json);
  }

  Future<PasskeyChallenge> passkeyEnrollmentChallenge({
    required String accessToken,
  }) async {
    final body = <String, dynamic>{
      'type': 'public-key',
    };
    final json = await _client.post(
      '/me/v1/authentication-methods',
      body,
      extraHeaders: {'Authorization': 'Bearer $accessToken'},
    );
    return PasskeyChallenge.fromJson(json);
  }

  Future<void> verifyPasskeyEnrollment({
    required String authSession,
    required Map<String, dynamic> authnResponse,
  }) async {
    final body = <String, dynamic>{
      'auth_session': authSession,
      'authn_response': authnResponse,
    };
    await _client.post(
      '/me/v1/authentication-methods/passkey%7Cnew/verify',
      body,
    );
  }

  void close() => _client.close();
}
