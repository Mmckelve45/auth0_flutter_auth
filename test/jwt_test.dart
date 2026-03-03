import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:auth0_flutter_auth/src/jwt/jwt_decoder.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

// Helper to create a minimal JWT string (unsigned, for decoder testing)
String _makeJwt({
  Map<String, dynamic>? header,
  Map<String, dynamic>? payload,
}) {
  final h = header ?? {'alg': 'RS256', 'typ': 'JWT', 'kid': 'test-kid'};
  final p = payload ??
      {
        'iss': 'https://test.auth0.com/',
        'sub': 'auth0|123',
        'aud': 'test_client',
        'exp': (DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000),
        'iat': (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        'nonce': 'test-nonce',
      };

  final headerB64 = base64UrlEncode(utf8.encode(jsonEncode(h))).replaceAll('=', '');
  final payloadB64 = base64UrlEncode(utf8.encode(jsonEncode(p))).replaceAll('=', '');
  // Fake signature (not verifiable)
  final sigB64 = base64UrlEncode(List.filled(64, 0)).replaceAll('=', '');

  return '$headerB64.$payloadB64.$sigB64';
}

void main() {
  group('JwtDecoder', () {
    test('decodes valid JWT header and payload', () {
      final jwt = _makeJwt();
      final decoder = JwtDecoder(jwt);

      expect(decoder.algorithm, 'RS256');
      expect(decoder.keyId, 'test-kid');
      expect(decoder.issuer, 'https://test.auth0.com/');
      expect(decoder.subject, 'auth0|123');
      expect(decoder.nonce, 'test-nonce');
    });

    test('throws on JWT with wrong number of parts', () {
      expect(
        () => JwtDecoder('only.two'),
        throwsA(isA<JwtException>().having(
          (e) => e.isMalformed,
          'isMalformed',
          true,
        )),
      );
    });

    test('throws on JWT with 1 part', () {
      expect(
        () => JwtDecoder('onlyonepart'),
        throwsA(isA<JwtException>()),
      );
    });

    test('throws on invalid base64 in header', () {
      expect(
        () => JwtDecoder('!!!.${base64UrlEncode(utf8.encode('{}'))}.sig'),
        throwsA(isA<JwtException>()),
      );
    });

    test('decodes audience as string', () {
      final jwt = _makeJwt(payload: {
        'iss': 'https://test.auth0.com/',
        'aud': 'single_client',
        'exp': (DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000),
        'iat': (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      });

      final decoder = JwtDecoder(jwt);
      expect(decoder.audience, 'single_client');
    });

    test('decodes audience as list', () {
      final jwt = _makeJwt(payload: {
        'iss': 'https://test.auth0.com/',
        'aud': ['client1', 'client2'],
        'exp': (DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000),
        'iat': (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      });

      final decoder = JwtDecoder(jwt);
      expect(decoder.audience, ['client1', 'client2']);
    });

    test('isExpired returns true for past exp', () {
      final jwt = _makeJwt(payload: {
        'iss': 'https://test.auth0.com/',
        'aud': 'client',
        'exp': (DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000),
        'iat': (DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000),
      });

      final decoder = JwtDecoder(jwt);
      expect(decoder.isExpired, true);
    });

    test('isExpired returns false for future exp', () {
      final jwt = _makeJwt();
      final decoder = JwtDecoder(jwt);
      expect(decoder.isExpired, false);
    });

    test('decodePayload static helper works', () {
      final jwt = _makeJwt(payload: {'sub': 'test_sub', 'iss': 'iss', 'exp': 999999999999, 'iat': 1000});
      final payload = JwtDecoder.decodePayload(jwt);
      expect(payload['sub'], 'test_sub');
    });

    test('handles missing optional fields', () {
      final jwt = _makeJwt(payload: {
        'iss': 'https://test.auth0.com/',
        'aud': 'client',
        'exp': (DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000),
        'iat': (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      });

      final decoder = JwtDecoder(jwt);
      expect(decoder.nonce, isNull);
      expect(decoder.subject, isNull);
    });
  });
}
