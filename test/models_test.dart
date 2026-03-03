import 'package:flutter_test/flutter_test.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

void main() {
  group('Credentials', () {
    test('fromJson parses token response with expires_in', () {
      final json = {
        'access_token': 'access123',
        'token_type': 'Bearer',
        'id_token': 'id.token.here',
        'refresh_token': 'refresh123',
        'expires_in': 3600,
        'scope': 'openid profile email',
      };

      final creds = Credentials.fromJson(json);
      expect(creds.accessToken, 'access123');
      expect(creds.tokenType, 'Bearer');
      expect(creds.idToken, 'id.token.here');
      expect(creds.refreshToken, 'refresh123');
      expect(creds.scopes, {'openid', 'profile', 'email'});
      expect(creds.isExpired, false);
    });

    test('fromJson parses token response with expires_at', () {
      final futureMs =
          DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch;
      final json = {
        'access_token': 'access456',
        'token_type': 'DPoP',
        'expires_at': futureMs,
      };

      final creds = Credentials.fromJson(json);
      expect(creds.accessToken, 'access456');
      expect(creds.tokenType, 'DPoP');
      expect(creds.isExpired, false);
    });

    test('isExpired returns true for past expiresAt', () {
      final creds = Credentials(
        accessToken: 'token',
        tokenType: 'Bearer',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(creds.isExpired, true);
    });

    test('toJson round-trips correctly', () {
      final original = Credentials(
        accessToken: 'at',
        tokenType: 'Bearer',
        idToken: 'idt',
        refreshToken: 'rt',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        scopes: {'openid', 'profile'},
      );

      final json = original.toJson();
      final restored = Credentials.fromJson(json);
      expect(restored.accessToken, original.accessToken);
      expect(restored.idToken, original.idToken);
      expect(restored.refreshToken, original.refreshToken);
    });

    test('fromJson defaults tokenType to Bearer', () {
      final json = {'access_token': 'tok', 'expires_in': 3600};
      final creds = Credentials.fromJson(json);
      expect(creds.tokenType, 'Bearer');
    });

    test('fromJson handles empty scope string', () {
      final json = {
        'access_token': 'tok',
        'expires_in': 3600,
        'scope': '',
      };
      final creds = Credentials.fromJson(json);
      expect(creds.scopes, isEmpty);
    });
  });

  group('UserProfile', () {
    test('fromJson parses standard OIDC claims', () {
      final json = {
        'sub': 'auth0|123',
        'name': 'John Doe',
        'given_name': 'John',
        'family_name': 'Doe',
        'email': 'john@example.com',
        'email_verified': true,
        'picture': 'https://example.com/photo.jpg',
        'updated_at': '2024-01-01T00:00:00.000Z',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.sub, 'auth0|123');
      expect(profile.name, 'John Doe');
      expect(profile.email, 'john@example.com');
      expect(profile.emailVerified, true);
      expect(profile.pictureUrl, 'https://example.com/photo.jpg');
      expect(profile.updatedAt, isNotNull);
    });

    test('fromJson captures custom claims', () {
      final json = {
        'sub': 'auth0|456',
        'https://example.com/roles': ['admin'],
        'custom_field': 'value',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.customClaims['https://example.com/roles'], ['admin']);
      expect(profile.customClaims['custom_field'], 'value');
    });

    test('toJson round-trips correctly', () {
      final original = UserProfile(
        sub: 'auth0|789',
        name: 'Jane',
        email: 'jane@example.com',
      );

      final json = original.toJson();
      final restored = UserProfile.fromJson(json);
      expect(restored.sub, original.sub);
      expect(restored.name, original.name);
      expect(restored.email, original.email);
    });
  });

  group('DatabaseUser', () {
    test('fromJson parses signup response', () {
      final json = {
        '_id': '507f1f77bcf86cd799439011',
        'email': 'user@example.com',
        'email_verified': false,
        'username': 'testuser',
      };

      final user = DatabaseUser.fromJson(json);
      expect(user.email, 'user@example.com');
      expect(user.emailVerified, false);
      expect(user.id, '507f1f77bcf86cd799439011');
      expect(user.username, 'testuser');
    });

    test('fromJson defaults emailVerified to false', () {
      final json = {'email': 'user@example.com'};
      final user = DatabaseUser.fromJson(json);
      expect(user.emailVerified, false);
    });
  });

  group('Challenge', () {
    test('fromJson parses MFA challenge response', () {
      final json = {
        'challenge_type': 'oob',
        'oob_code': 'oob123',
        'binding_method': 'prompt',
      };

      final challenge = Challenge.fromJson(json);
      expect(challenge.challengeType, 'oob');
      expect(challenge.oobCode, 'oob123');
      expect(challenge.bindingMethod, 'prompt');
    });
  });

  group('SSOCredentials', () {
    test('fromJson parses SSO exchange response', () {
      final json = {
        'access_token': 'sso_access',
        'token_type': 'Bearer',
        'id_token': 'sso_id',
        'expires_in': 7200,
        'scope': 'openid profile',
      };

      final creds = SSOCredentials.fromJson(json);
      expect(creds.accessToken, 'sso_access');
      expect(creds.idToken, 'sso_id');
      expect(creds.scopes, {'openid', 'profile'});
    });
  });
}
