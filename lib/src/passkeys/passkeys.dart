import 'dart:convert';
import 'dart:developer' as developer;
import 'passkeys_platform.dart';
import '../api/auth_api.dart';
import '../models/credentials.dart';

class Passkeys {
  final AuthApi _api;
  final PasskeysPlatform _platform;

  static bool _warningLogged = false;

  Passkeys({required AuthApi api, PasskeysPlatform? platform})
      : _api = api,
        _platform = platform ?? PasskeysPlatform();

  void _logEarlyAccessWarning() {
    if (_warningLogged) return;
    _warningLogged = true;
    developer.log(
      'WARNING: Native Passkeys is a Limited Early Access feature. '
      'This API is subject to change and is not recommended for '
      'production use until General Availability.',
      name: 'auth0_flutter_auth',
    );
  }

  Future<bool> isAvailable() async {
    return _platform.isAvailable();
  }

  Future<Credentials> signup({
    required String email,
    String? name,
    String? realm,
    String? audience,
    Set<String> scopes = const {},
  }) async {
    _logEarlyAccessWarning();

    final challenge = await _api.passkeyRegisterChallenge(
      email: email,
      name: name,
      realm: realm,
    );

    final optionsJson = jsonEncode(challenge.authnParamsPublicKey);
    final responseJson = await _platform.register(optionsJson);
    final authnResponse =
        jsonDecode(responseJson) as Map<String, dynamic>;

    return _api.authenticateWithPasskey(
      authSession: challenge.authSession,
      authnResponse: authnResponse,
      audience: audience,
      scopes: scopes,
    );
  }

  Future<Credentials> login({
    String? realm,
    String? audience,
    Set<String> scopes = const {},
  }) async {
    _logEarlyAccessWarning();

    final challenge = await _api.passkeyLoginChallenge(realm: realm);

    final optionsJson = jsonEncode(challenge.authnParamsPublicKey);
    final responseJson = await _platform.authenticate(optionsJson);
    final authnResponse =
        jsonDecode(responseJson) as Map<String, dynamic>;

    return _api.authenticateWithPasskey(
      authSession: challenge.authSession,
      authnResponse: authnResponse,
      audience: audience,
      scopes: scopes,
    );
  }

  Future<void> enroll({required String accessToken}) async {
    _logEarlyAccessWarning();

    final challenge =
        await _api.passkeyEnrollmentChallenge(accessToken: accessToken);

    final optionsJson = jsonEncode(challenge.authnParamsPublicKey);
    final responseJson = await _platform.register(optionsJson);
    final authnResponse =
        jsonDecode(responseJson) as Map<String, dynamic>;

    await _api.verifyPasskeyEnrollment(
      authSession: challenge.authSession,
      authnResponse: authnResponse,
    );
  }
}
