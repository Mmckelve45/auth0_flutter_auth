import 'package:flutter_test/flutter_test.dart';
import 'package:auth0_flutter_auth/src/dpop/dpop_platform.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

/// Mock DPoPPlatform that doesn't use MethodChannels.
class _MockDPoPPlatform extends DPoPPlatform {
  bool keyPairGenerated = false;
  bool cleared = false;
  int signCallCount = 0;
  String? lastSignUrl;
  String? lastSignMethod;
  String? lastSignAccessToken;
  String? lastSignNonce;

  @override
  Future<void> generateKeyPair() async {
    keyPairGenerated = true;
  }

  @override
  Future<String> signProof({
    required String url,
    required String method,
    String? accessToken,
    String? nonce,
  }) async {
    signCallCount++;
    lastSignUrl = url;
    lastSignMethod = method;
    lastSignAccessToken = accessToken;
    lastSignNonce = nonce;
    return 'mock-dpop-proof-jwt';
  }

  @override
  Future<void> clearKeyPair() async {
    keyPairGenerated = false;
    cleared = true;
  }

  @override
  Future<bool> hasKeyPair() async {
    return keyPairGenerated;
  }
}

void main() {
  late _MockDPoPPlatform mockPlatform;
  late DPoP dpop;

  setUp(() {
    mockPlatform = _MockDPoPPlatform();
    dpop = DPoP(platform: mockPlatform);
  });

  group('DPoP', () {
    test('starts uninitialized', () {
      expect(dpop.isInitialized, false);
    });

    test('initialize generates key pair', () async {
      await dpop.initialize();
      expect(dpop.isInitialized, true);
      expect(mockPlatform.keyPairGenerated, true);
    });

    test('initialize is idempotent', () async {
      await dpop.initialize();
      await dpop.initialize(); // Second call should be no-op
      expect(dpop.isInitialized, true);
      // keyPairGenerated would be called only once via the guard
    });

    test('generateHeaders throws when not initialized', () {
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

    test('generateHeaders returns DPoP header after initialization', () async {
      await dpop.initialize();

      final headers = await dpop.generateHeaders(
        url: 'https://api.example.com/token',
        method: 'POST',
      );

      expect(headers, containsPair('DPoP', 'mock-dpop-proof-jwt'));
      expect(mockPlatform.lastSignUrl, 'https://api.example.com/token');
      expect(mockPlatform.lastSignMethod, 'POST');
    });

    test('generateHeaders passes access token', () async {
      await dpop.initialize();

      await dpop.generateHeaders(
        url: 'https://api.example.com/resource',
        method: 'GET',
        accessToken: 'my_access_token',
      );

      expect(mockPlatform.lastSignAccessToken, 'my_access_token');
    });

    test('generateHeaders passes nonce from nonce manager', () async {
      await dpop.initialize();
      dpop.updateNonce('server-nonce-123');

      await dpop.generateHeaders(
        url: 'https://api.example.com/resource',
        method: 'GET',
      );

      expect(mockPlatform.lastSignNonce, 'server-nonce-123');
    });

    test('generateHeaders passes server-specific nonce', () async {
      await dpop.initialize();
      dpop.updateNonceForServer('api.example.com', 'specific-nonce');

      await dpop.generateHeaders(
        url: 'https://api.example.com/resource',
        method: 'GET',
      );

      expect(mockPlatform.lastSignNonce, 'specific-nonce');
    });

    test('generateHeaders passes null nonce when none set', () async {
      await dpop.initialize();

      await dpop.generateHeaders(
        url: 'https://api.example.com/resource',
        method: 'GET',
      );

      expect(mockPlatform.lastSignNonce, isNull);
    });

    test('clear resets initialization state', () async {
      await dpop.initialize();
      expect(dpop.isInitialized, true);

      await dpop.clear();
      expect(dpop.isInitialized, false);
      expect(mockPlatform.cleared, true);
    });

    test('clear resets nonce manager', () async {
      await dpop.initialize();
      dpop.updateNonce('some-nonce');

      await dpop.clear();

      // Re-initialize and check nonce is gone
      await dpop.initialize();
      await dpop.generateHeaders(
        url: 'https://api.example.com',
        method: 'GET',
      );
      expect(mockPlatform.lastSignNonce, isNull);
    });

    test('generateHeaders can be called multiple times', () async {
      await dpop.initialize();

      await dpop.generateHeaders(url: 'https://a.com', method: 'GET');
      await dpop.generateHeaders(url: 'https://b.com', method: 'POST');
      await dpop.generateHeaders(url: 'https://c.com', method: 'DELETE');

      expect(mockPlatform.signCallCount, 3);
    });
  });
}
