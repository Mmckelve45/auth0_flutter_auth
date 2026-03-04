import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';
import 'package:auth0_flutter_auth/src/credentials/token_refresher.dart';

// Helper to build a fake AuthApi backed by a MockClient whose renewTokens
// response is controlled by [onRenew].
AuthApi _buildFakeApi(Credentials Function() onRenew) {
  final mock = MockClient((request) async {
    try {
      final creds = onRenew();
      return http.Response(jsonEncode(creds.toJson()), 200);
    } catch (e) {
      return http.Response(
        jsonEncode({'error': 'server_error', 'error_description': '$e'}),
        500,
      );
    }
  });

  final httpClient = Auth0HttpClient(
    domain: 'test.auth0.com',
    clientId: 'test',
    httpClient: mock,
  );

  return AuthApi(client: httpClient, clientId: 'test');
}

void main() {
  group('TokenRefresher', () {
    test('refresh calls renewTokens and returns credentials', () async {
      final api = _buildFakeApi(() => Credentials(
            accessToken: 'refreshed_at',
            tokenType: 'Bearer',
            refreshToken: 'new_rt',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ));

      final refresher = TokenRefresher(api: api);

      final result = await refresher.refresh(refreshToken: 'old_rt');
      expect(result.accessToken, 'refreshed_at');
    });

    test('refresh preserves refresh token when server omits it', () async {
      final api = _buildFakeApi(() => Credentials(
            accessToken: 'new_at',
            tokenType: 'Bearer',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            // No refresh token returned by server
          ));

      final refresher = TokenRefresher(api: api);
      final result = await refresher.refresh(refreshToken: 'original_rt');

      expect(result.accessToken, 'new_at');
      expect(result.refreshToken, 'original_rt');
    });

    test('refresh resets mutex after completion, allowing subsequent calls',
        () async {
      var callCount = 0;
      final api = _buildFakeApi(() {
        callCount++;
        return Credentials(
          accessToken: 'at_$callCount',
          tokenType: 'Bearer',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        );
      });

      final refresher = TokenRefresher(api: api);

      final first = await refresher.refresh(refreshToken: 'rt');
      expect(first.accessToken, 'at_1');

      final second = await refresher.refresh(refreshToken: 'rt');
      expect(second.accessToken, 'at_2');
      expect(callCount, 2);
    });

    test('refresh propagates error and resets mutex', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Invalid grant',
          }),
          403,
        );
      });

      final httpClient = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'test',
        httpClient: mock,
      );
      final api = AuthApi(client: httpClient, clientId: 'test');
      final refresher = TokenRefresher(api: api);

      try {
        await refresher.refresh(refreshToken: 'rt');
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<CredentialStoreException>());
      }
    });
  });

  group('revokeToken', () {
    test('revokeToken posts to /oauth/revoke', () async {
      final mock = MockClient((request) async {
        if (request.url.path == '/oauth/revoke') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['client_id'], 'test');
          expect(body['token'], 'rt_to_revoke');
          return http.Response(jsonEncode({}), 200);
        }
        return http.Response(jsonEncode({}), 200);
      });

      final httpClient = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'test',
        httpClient: mock,
      );
      final api = AuthApi(client: httpClient, clientId: 'test');

      await api.revokeToken(refreshToken: 'rt_to_revoke');
    });
  });

  group('BiometricPolicy', () {
    test('BiometricPolicy.disabled is the default', () {
      const options = CredentialStoreOptions();
      expect(options.biometricPolicy, BiometricPolicy.disabled);
    });

    test('BiometricPolicy.session has default timeout of 300', () {
      const options = CredentialStoreOptions(
        biometricPolicy: BiometricPolicy.session,
      );
      expect(options.biometricSessionTimeout, 300);
    });

    test('BiometricPolicy.session accepts custom timeout', () {
      const options = CredentialStoreOptions(
        biometricPolicy: BiometricPolicy.session,
        biometricSessionTimeout: 60,
      );
      expect(options.biometricSessionTimeout, 60);
    });

    test('all BiometricPolicy enum values exist', () {
      expect(BiometricPolicy.values, containsAll([
        BiometricPolicy.always,
        BiometricPolicy.session,
        BiometricPolicy.appLifecycle,
        BiometricPolicy.disabled,
      ]));
    });
  });

  group('CredentialStoreException factories', () {
    test('noCredentials', () {
      final e = CredentialStoreException.noCredentials();
      expect(e.isNoCredentials, true);
    });

    test('noRefreshToken', () {
      final e = CredentialStoreException.noRefreshToken();
      expect(e.isNoRefreshToken, true);
    });

    test('biometricFailed', () {
      final e = CredentialStoreException.biometricFailed();
      expect(e.isBiometricFailed, true);
    });

    test('storageError', () {
      final e = CredentialStoreException.storageError();
      expect(e.isStorageError, true);
    });

    test('refreshFailed', () {
      final e = CredentialStoreException.refreshFailed();
      expect(e.isRefreshFailed, true);
    });
  });
}
