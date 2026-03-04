import 'package:flutter_test/flutter_test.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

void main() {
  group('PasskeyChallenge', () {
    test('fromJson parses fields correctly', () {
      final json = {
        'authn_params_public_key': {
          'challenge': 'abc123',
          'rp': {'id': 'example.auth0.com', 'name': 'Example'},
          'user': {'id': 'user1', 'name': 'test@example.com'},
        },
        'auth_session': 'session_xyz',
      };

      final challenge = PasskeyChallenge.fromJson(json);
      expect(challenge.authSession, 'session_xyz');
      expect(challenge.authnParamsPublicKey['challenge'], 'abc123');
      expect(
        (challenge.authnParamsPublicKey['rp'] as Map)['id'],
        'example.auth0.com',
      );
    });

    test('toJson produces correct map', () {
      final challenge = PasskeyChallenge(
        authnParamsPublicKey: {'challenge': 'c1', 'rp': {'id': 'rp1'}},
        authSession: 'sess1',
      );

      final json = challenge.toJson();
      expect(json['auth_session'], 'sess1');
      expect(json['authn_params_public_key'], isA<Map>());
      expect(json['authn_params_public_key']['challenge'], 'c1');
    });

    test('fromJson → toJson round-trips', () {
      final original = {
        'authn_params_public_key': {
          'challenge': 'round_trip',
          'timeout': 60000,
        },
        'auth_session': 'rt_session',
      };

      final challenge = PasskeyChallenge.fromJson(original);
      final result = challenge.toJson();
      expect(result['auth_session'], original['auth_session']);
      expect(
        (result['authn_params_public_key'] as Map)['challenge'],
        'round_trip',
      );
    });
  });

  group('PasskeyException', () {
    test('notAvailable has correct code and getter', () {
      final e = PasskeyException.notAvailable();
      expect(e.isNotAvailable, true);
      expect(e.isCancelled, false);
      expect(e.code, 'a0.passkeys_not_available');
    });

    test('cancelled has correct code and getter', () {
      final e = PasskeyException.cancelled();
      expect(e.isCancelled, true);
      expect(e.isNotAvailable, false);
    });

    test('registrationFailed has correct code and getter', () {
      final e = PasskeyException.registrationFailed();
      expect(e.isRegistrationFailed, true);
      expect(e.code, 'a0.passkeys_registration_failed');
    });

    test('assertionFailed has correct code and getter', () {
      final e = PasskeyException.assertionFailed();
      expect(e.isAssertionFailed, true);
      expect(e.code, 'a0.passkeys_assertion_failed');
    });

    test('platformError includes detail in message', () {
      final e = PasskeyException.platformError('something broke');
      expect(e.message, contains('something broke'));
      expect(e.code, 'a0.passkeys_platform_error');
    });

    test('cause is preserved', () {
      final cause = Exception('root cause');
      final e = PasskeyException.cancelled(cause: cause);
      expect(e.cause, cause);
    });

    test('toString includes code and message', () {
      final e = PasskeyException.notAvailable();
      expect(e.toString(), contains('a0.passkeys_not_available'));
      expect(e.toString(), contains('not available'));
    });
  });
}
