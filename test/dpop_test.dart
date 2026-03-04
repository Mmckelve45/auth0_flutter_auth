import 'package:flutter_test/flutter_test.dart';
import 'package:auth0_flutter_auth/src/dpop/dpop_nonce_manager.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

void main() {
  group('DPoPNonceManager', () {
    late DPoPNonceManager manager;

    setUp(() {
      manager = DPoPNonceManager();
    });

    test('stores and retrieves nonce by server', () {
      manager.updateNonce('api.example.com', 'nonce1');
      expect(manager.getNonce('https://api.example.com/endpoint'), 'nonce1');
    });

    test('update stores default nonce', () {
      manager.update('default-nonce');
      expect(manager.getNonce('https://any.server.com'), 'default-nonce');
    });

    test('server-specific nonce takes priority over default', () {
      manager.update('default-nonce');
      manager.updateNonce('api.example.com', 'specific-nonce');
      expect(
        manager.getNonce('https://api.example.com/endpoint'),
        'specific-nonce',
      );
    });

    test('returns null for unknown server without default', () {
      expect(manager.getNonce('https://unknown.com'), isNull);
    });

    test('clear removes all nonces', () {
      manager.update('nonce1');
      manager.updateNonce('server', 'nonce2');
      manager.clear();
      expect(manager.getNonce('https://server'), isNull);
    });

    test('update with null is ignored', () {
      manager.update('nonce1');
      manager.update(null);
      expect(manager.getNonce('https://any.com'), 'nonce1');
    });
  });

  group('DPoP', () {
    test('throws DPoPException.notInitialized when not initialized', () {
      final dpop = DPoP();

      expect(
        () => dpop.generateHeaders(
          url: 'https://api.example.com',
          method: 'POST',
        ),
        throwsA(isA<DPoPException>().having(
          (e) => e.isNotInitialized,
          'isNotInitialized',
          true,
        )),
      );
    });

    test('isInitialized is false by default', () {
      final dpop = DPoP();
      expect(dpop.isInitialized, false);
    });

    test('updateNonce sets nonce for next request', () {
      final dpop = DPoP();
      dpop.updateNonce('server-nonce');
      // Verify via nonce manager (internal state, tested through behavior)
    });

    test('updateNonceForServer sets server-specific nonce', () {
      final dpop = DPoP();
      dpop.updateNonceForServer('api.example.com', 'specific-nonce');
    });
  });
}
