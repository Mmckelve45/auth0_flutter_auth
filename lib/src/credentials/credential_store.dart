import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../api/auth_api.dart';
import '../jwt/jwt_decoder.dart';
import '../models/credentials.dart';
import '../models/user_profile.dart';
import '../models/sso_credentials.dart';
import '../exceptions/credential_store_exception.dart';
import 'credential_store_options.dart';
import 'token_refresher.dart';

class CredentialStore {
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;
  final TokenRefresher _refresher;
  final AuthApi _api;
  final CredentialStoreOptions _options;

  /// Broadcast stream controller for credential changes.
  /// Emits [Credentials] when stored/refreshed, or `null` when cleared.
  final _onChangeController = StreamController<Credentials?>.broadcast();

  CredentialStore({
    required AuthApi api,
    CredentialStoreOptions? options,
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _api = api,
        _options = options ?? const CredentialStoreOptions(),
        _storage = storage ?? const FlutterSecureStorage(),
        _localAuth = localAuth ?? LocalAuthentication(),
        _refresher = TokenRefresher(api: api);

  String get _storageKey => _options.storageKey;

  /// Stream that emits whenever credentials change.
  ///
  /// Emits [Credentials] after [storeCredentials] or [renewCredentials],
  /// and `null` after [clearCredentials]. Does **not** emit the current
  /// state on listen — use [authStateChanges] on [Auth0Client] for that.
  Stream<Credentials?> get onCredentialsChanged => _onChangeController.stream;

  /// Closes the internal stream controller. Called by [Auth0Client.close].
  void dispose() {
    _onChangeController.close();
  }

  /// Stores credentials securely.
  Future<void> storeCredentials(Credentials credentials) async {
    try {
      final json = jsonEncode(credentials.toJson());
      await _storage.write(key: _storageKey, value: json);
      _onChangeController.add(credentials);
    } catch (e) {
      throw CredentialStoreException.storageError(cause: e);
    }
  }

  /// Gets valid credentials, auto-refreshing if needed.
  /// Returns null if no credentials are stored.
  Future<Credentials?> getCredentials({
    int minTtl = 0,
    Set<String> scopes = const {},
  }) async {
    if (_options.requireBiometrics) {
      await _authenticateBiometric();
    }

    final credentials = await _readCredentials();
    if (credentials == null) return null;

    // Check scope coverage
    if (scopes.isNotEmpty && !scopes.every(credentials.scopes.contains)) {
      return await _refreshIfPossible(credentials, scopes: scopes);
    }

    // Check if token needs refresh based on minTtl
    final effectiveMinTtl = minTtl > 0 ? minTtl : _options.defaultMinTtl;
    if (effectiveMinTtl > 0) {
      final ttl = credentials.expiresAt
          .difference(DateTime.now())
          .inSeconds;
      if (ttl < effectiveMinTtl) {
        return await _refreshIfPossible(credentials, scopes: scopes);
      }
    }

    // Check if expired
    if (credentials.isExpired) {
      return await _refreshIfPossible(credentials, scopes: scopes);
    }

    return credentials;
  }

  /// Forces a token renewal using the stored refresh token.
  Future<Credentials> renewCredentials({
    Map<String, String>? parameters,
  }) async {
    final stored = await _readCredentials();
    if (stored == null) {
      throw CredentialStoreException.noCredentials();
    }
    if (stored.refreshToken == null) {
      throw CredentialStoreException.noRefreshToken();
    }

    final refreshed = await _refresher.refresh(
      refreshToken: stored.refreshToken!,
      parameters: parameters,
    );

    await storeCredentials(refreshed);
    return refreshed;
  }

  /// Checks if valid credentials exist without retrieving them.
  Future<bool> hasValidCredentials({int minTtl = 0}) async {
    final credentials = await _readCredentials();
    if (credentials == null) return false;

    final effectiveMinTtl = minTtl > 0 ? minTtl : _options.defaultMinTtl;
    if (effectiveMinTtl > 0) {
      final ttl = credentials.expiresAt
          .difference(DateTime.now())
          .inSeconds;
      if (ttl < effectiveMinTtl) {
        return credentials.refreshToken != null;
      }
    }

    if (credentials.isExpired) {
      return credentials.refreshToken != null;
    }

    return true;
  }

  /// Extracts the user profile from the stored ID token.
  Future<UserProfile?> user() async {
    final credentials = await _readCredentials();
    if (credentials?.idToken == null) return null;

    try {
      final jwt = JwtDecoder(credentials!.idToken!);
      return UserProfile.fromJson(jwt.payload);
    } catch (_) {
      return null;
    }
  }

  /// Clears all stored credentials.
  Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _storageKey);
      _onChangeController.add(null);
    } catch (e) {
      throw CredentialStoreException.storageError(cause: e);
    }
  }

  /// Performs SSO token exchange using the stored refresh token.
  Future<SSOCredentials> ssoCredentials({
    Map<String, String>? parameters,
  }) async {
    final stored = await _readCredentials();
    if (stored == null) {
      throw CredentialStoreException.noCredentials();
    }
    if (stored.refreshToken == null) {
      throw CredentialStoreException.noRefreshToken();
    }

    return _api.ssoExchange(
      refreshToken: stored.refreshToken!,
      parameters: parameters,
    );
  }

  // Private helpers

  Future<Credentials?> _readCredentials() async {
    try {
      final json = await _storage.read(key: _storageKey);
      if (json == null) return null;
      return Credentials.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      throw CredentialStoreException.storageError(cause: e);
    }
  }

  Future<Credentials> _refreshIfPossible(
    Credentials credentials, {
    Set<String> scopes = const {},
  }) async {
    if (credentials.refreshToken == null) {
      throw CredentialStoreException.noRefreshToken();
    }

    final refreshed = await _refresher.refresh(
      refreshToken: credentials.refreshToken!,
      scopes: scopes,
    );

    await storeCredentials(refreshed);
    return refreshed;
  }

  Future<void> _authenticateBiometric() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) return;

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: _options.biometricPrompt,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (!didAuthenticate) {
        throw CredentialStoreException.biometricFailed();
      }
    } on CredentialStoreException {
      rethrow;
    } catch (e) {
      throw CredentialStoreException.biometricFailed(cause: e);
    }
  }
}
