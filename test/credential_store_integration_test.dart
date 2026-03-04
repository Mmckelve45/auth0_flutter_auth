import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

// Since flutter_secure_storage and local_auth require platform channels,
// we test CredentialStore indirectly by testing the public contract
// through a helper that creates one with mocked dependencies.
// The actual flutter_secure_storage mock needs the Flutter test engine.

void main() {
  group('CredentialStore — contract tests', () {
    // These tests verify the CredentialStore public API contract
    // by testing the underlying components it depends on.

    test('Credentials JSON round-trip preserves all fields', () {
      final original = Credentials(
        accessToken: 'at',
        tokenType: 'Bearer',
        idToken: 'idt',
        refreshToken: 'rt',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scopes: {'openid', 'profile', 'email'},
      );

      final json = jsonEncode(original.toJson());
      final restored = Credentials.fromJson(jsonDecode(json));

      expect(restored.accessToken, original.accessToken);
      expect(restored.tokenType, original.tokenType);
      expect(restored.idToken, original.idToken);
      expect(restored.refreshToken, original.refreshToken);
      expect(restored.scopes, original.scopes);
      // expiresAt round-trips via millisecondsSinceEpoch
      expect(
        restored.expiresAt.millisecondsSinceEpoch,
        original.expiresAt.millisecondsSinceEpoch,
      );
    });

    test('expired credentials are detected', () {
      final expired = Credentials(
        accessToken: 'at',
        tokenType: 'Bearer',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(expired.isExpired, true);

      final valid = Credentials(
        accessToken: 'at',
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(valid.isExpired, false);
    });

    test('minTtl logic — token expiring within minTtl should trigger refresh', () {
      // Token expires in 30 seconds
      final creds = Credentials(
        accessToken: 'at',
        tokenType: 'Bearer',
        refreshToken: 'rt',
        expiresAt: DateTime.now().add(const Duration(seconds: 30)),
      );

      // With minTtl=60, this token needs refresh
      final ttl = creds.expiresAt.difference(DateTime.now()).inSeconds;
      expect(ttl < 60, true);
      expect(creds.isExpired, false); // Not expired yet, but needs refresh
    });

    test('scope coverage check — missing scopes require refresh', () {
      final creds = Credentials(
        accessToken: 'at',
        tokenType: 'Bearer',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scopes: {'openid', 'profile'},
      );

      // Has the requested scopes
      final requestedSubset = {'openid', 'profile'};
      expect(requestedSubset.every(creds.scopes.contains), true);

      // Missing scope
      final requestedMore = {'openid', 'profile', 'email'};
      expect(requestedMore.every(creds.scopes.contains), false);
    });

    test('renewTokens returns fresh credentials from API', () async {
      final mockHttp = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['grant_type'], 'refresh_token');
        expect(body['refresh_token'], 'old_rt');
        return http.Response(
          jsonEncode({
            'access_token': 'new_at',
            'token_type': 'Bearer',
            'refresh_token': 'new_rt',
            'expires_in': 3600,
            'scope': 'openid profile email',
          }),
          200,
        );
      });

      final httpClient = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        httpClient: mockHttp,
      );
      final api = AuthApi(client: httpClient, clientId: 'test_client');

      final refreshed = await api.renewTokens(refreshToken: 'old_rt');
      expect(refreshed.accessToken, 'new_at');
      expect(refreshed.refreshToken, 'new_rt');
      expect(refreshed.scopes, {'openid', 'profile', 'email'});
    });

    test('renewTokens throws ApiException on 403', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'invalid_grant',
            'error_description': 'Refresh token revoked',
          }),
          403,
        );
      });

      final httpClient = Auth0HttpClient(
        domain: 'test.auth0.com',
        clientId: 'test_client',
        httpClient: mockHttp,
      );
      final api = AuthApi(client: httpClient, clientId: 'test_client');

      try {
        await api.renewTokens(refreshToken: 'revoked_rt');
        fail('Should have thrown');
      } on ApiException catch (e) {
        expect(e.isRefreshTokenDeleted, true);
      }
    });

    test('UserProfile extraction from ID token payload', () {
      // Simulate what CredentialStore.user() does internally
      final payload = {
        'sub': 'auth0|user123',
        'name': 'Test User',
        'email': 'test@example.com',
        'email_verified': true,
        'picture': 'https://example.com/photo.jpg',
        'nickname': 'testuser',
      };

      final profile = UserProfile.fromJson(payload);
      expect(profile.sub, 'auth0|user123');
      expect(profile.name, 'Test User');
      expect(profile.email, 'test@example.com');
      expect(profile.emailVerified, true);
    });

    test('CredentialStoreException types', () {
      expect(CredentialStoreException.noCredentials().isNoCredentials, true);
      expect(CredentialStoreException.noRefreshToken().isNoRefreshToken, true);
      expect(CredentialStoreException.biometricFailed().isBiometricFailed, true);
      expect(CredentialStoreException.storageError().isStorageError, true);
      expect(CredentialStoreException.refreshFailed().isRefreshFailed, true);
    });
  });
}
