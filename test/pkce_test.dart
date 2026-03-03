import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:auth0_flutter_auth/src/web_auth/pkce.dart';

void main() {
  group('Pkce', () {
    test('generate creates valid code_verifier', () {
      final pkce = Pkce.generate();
      // code_verifier should be 43-128 chars of unreserved characters
      expect(pkce.codeVerifier.length, greaterThanOrEqualTo(43));
      expect(pkce.codeVerifier.length, lessThanOrEqualTo(128));
      // Should not contain padding chars
      expect(pkce.codeVerifier, isNot(contains('=')));
    });

    test('generate creates valid code_challenge (S256)', () {
      final pkce = Pkce.generate();
      // Verify the challenge is S256(verifier)
      final bytes = utf8.encode(pkce.codeVerifier);
      final digest = sha256.convert(bytes);
      final expected = base64UrlEncode(digest.bytes).replaceAll('=', '');

      expect(pkce.codeChallenge, expected);
    });

    test('each generation produces unique values', () {
      final pkce1 = Pkce.generate();
      final pkce2 = Pkce.generate();

      expect(pkce1.codeVerifier, isNot(pkce2.codeVerifier));
      expect(pkce1.codeChallenge, isNot(pkce2.codeChallenge));
    });

    test('code_challenge does not contain padding', () {
      // Run multiple times to increase confidence
      for (var i = 0; i < 10; i++) {
        final pkce = Pkce.generate();
        expect(pkce.codeChallenge, isNot(contains('=')));
        expect(pkce.codeChallenge, isNot(contains('+')));
        expect(pkce.codeChallenge, isNot(contains('/')));
      }
    });
  });
}
