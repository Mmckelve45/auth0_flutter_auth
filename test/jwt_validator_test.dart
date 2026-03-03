import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:auth0_flutter_auth/src/jwt/jwt_validator.dart';
import 'package:auth0_flutter_auth/src/jwt/jwks_client.dart';
import 'package:auth0_flutter_auth/src/exceptions/jwt_exception.dart';

// ============================================================================
// Helper Functions
// ============================================================================

/// Generates an RSA key pair using PointyCastle with 2048-bit keys
AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _generateRSAKeyPair() {
  final keyGen = RSAKeyGenerator()
    ..init(ParametersWithRandom(
      RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
      _secureRandom(),
    ));
  final pair = keyGen.generateKeyPair();
  return AsymmetricKeyPair(
    pair.publicKey as RSAPublicKey,
    pair.privateKey as RSAPrivateKey,
  );
}

/// Creates a secure random instance seeded with cryptographically secure random data
FortunaRandom _secureRandom() {
  final secureRandom = FortunaRandom();
  final random = Random.secure();
  final seeds = List<int>.generate(32, (_) => random.nextInt(256));
  secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
  return secureRandom;
}

/// Encodes bytes to base64url format without padding
String _base64UrlEncode(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Signs data with an RSA private key using SHA-256/RSA/PKCS1 (RS256)
Uint8List _signRS256(Uint8List data, RSAPrivateKey privateKey) {
  final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
  signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));
  final signature = signer.generateSignature(data) as RSASignature;
  return signature.bytes;
}

/// Builds a complete signed JWT with customizable header and payload claims
String _buildJwt({
  required RSAPrivateKey privateKey,
  Map<String, dynamic>? headerOverrides,
  Map<String, dynamic>? payloadOverrides,
  String kid = 'test-kid',
  String issuer = 'https://test.auth0.com/',
  String audience = 'test_client',
  String? nonce,
  int? exp,
  int? iat,
  int? authTime,
  bool skipSign = false,
  String? algorithm,
  String? orgId,
  String? orgName,
}) {
  final header = {
    'alg': algorithm ?? 'RS256',
    'typ': 'JWT',
    'kid': kid,
    ...?headerOverrides,
  };

  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final payload = {
    'iss': issuer,
    'sub': 'auth0|123',
    'aud': audience,
    'exp': exp ?? (now + 3600),
    'iat': iat ?? now,
    if (nonce != null) 'nonce': nonce,
    if (authTime != null) 'auth_time': authTime,
    if (orgId != null) 'org_id': orgId,
    if (orgName != null) 'org_name': orgName,
    ...?payloadOverrides,
  };

  final headerB64 = _base64UrlEncode(utf8.encode(jsonEncode(header)));
  final payloadB64 = _base64UrlEncode(utf8.encode(jsonEncode(payload)));
  final signingInput = '$headerB64.$payloadB64';

  if (skipSign) {
    return '$signingInput.${_base64UrlEncode(List.filled(64, 0))}';
  }

  final signatureBytes = _signRS256(
    Uint8List.fromList(utf8.encode(signingInput)),
    privateKey,
  );
  final signatureB64 = _base64UrlEncode(signatureBytes);

  return '$signingInput.$signatureB64';
}

// ============================================================================
// Mock JwksClient
// ============================================================================

/// Mock implementation of JwksClient that returns pre-loaded RSA public keys
class _MockJwksClient extends JwksClient {
  final Map<String, RSAPublicKey> _keys;

  _MockJwksClient(this._keys) : super(domain: 'test.auth0.com');

  @override
  Future<RSAPublicKey> getKey(String kid) async {
    final key = _keys[kid];
    if (key == null) throw JwtException.keyNotFound(kid);
    return key;
  }
}

// ============================================================================
// Tests
// ============================================================================

void main() {
  group('JwtValidator — valid tokens', () {
    test('valid token passes validation', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        kid: 'test-kid',
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      final payload = await validator.validate(token);
      expect(payload['iss'], 'https://test.auth0.com/');
      expect(payload['aud'], 'test_client');
      expect(payload['sub'], 'auth0|123');
    });

    test('valid token with nonce passes validation', () async {
      final keyPair = _generateRSAKeyPair();
      const testNonce = 'test-nonce-123';
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        nonce: testNonce,
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      final payload = await validator.validate(token, nonce: testNonce);
      expect(payload['nonce'], testNonce);
    });
  });

  group('JwtValidator — issuer', () {
    test('wrong issuer throws invalidIssuer', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        issuer: 'https://wrong.auth0.com/',
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      expect(
        () => validator.validate(token),
        throwsA(isA<JwtException>().having((e) => e.isInvalidIssuer, 'isInvalidIssuer', true)),
      );
    });

    test('trailing slash normalization works for issuer', () async {
      final keyPair = _generateRSAKeyPair();
      // Token has issuer with trailing slash
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        issuer: 'https://test.auth0.com/',
      );

      // Validator configured without trailing slash
      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      // Should pass despite difference in trailing slash
      final payload = await validator.validate(token);
      expect(payload['iss'], 'https://test.auth0.com/');
    });

    test('issuer without trailing slash in token is normalized', () async {
      final keyPair = _generateRSAKeyPair();
      // Token has issuer without trailing slash
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        issuer: 'https://test.auth0.com',
      );

      // Validator configured with trailing slash
      final validator = JwtValidator(
        issuer: 'https://test.auth0.com/',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      // Should pass despite difference in trailing slash
      final payload = await validator.validate(token);
      expect(payload['iss'], 'https://test.auth0.com');
    });
  });

  group('JwtValidator — audience', () {
    test('wrong audience throws invalidAudience', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        audience: 'wrong_client',
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      expect(
        () => validator.validate(token),
        throwsA(isA<JwtException>().having((e) => e.isInvalidAudience, 'isInvalidAudience', true)),
      );
    });

    test('array audience containing correct client passes', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        payloadOverrides: {
          'aud': ['test_client', 'other_client', 'another_client']
        },
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      final payload = await validator.validate(token);
      expect(payload['aud'], ['test_client', 'other_client', 'another_client']);
    });

    test('array audience not containing correct client throws invalidAudience', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        payloadOverrides: {
          'aud': ['other_client', 'another_client']
        },
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      expect(
        () => validator.validate(token),
        throwsA(isA<JwtException>().having((e) => e.isInvalidAudience, 'isInvalidAudience', true)),
      );
    });
  });

  group('JwtValidator — expiration', () {
    test('expired token throws expired exception', () async {
      final keyPair = _generateRSAKeyPair();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        exp: now - 3600, // Expired 1 hour ago
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      expect(
        () => validator.validate(token),
        throwsA(isA<JwtException>().having((e) => e.isExpired, 'isExpired', true)),
      );
    });

    test('token near expiry within leeway passes', () async {
      final keyPair = _generateRSAKeyPair();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        exp: now + 30, // Expires in 30 seconds
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
        leeway: const Duration(seconds: 60), // 60 second leeway
      );

      final payload = await validator.validate(token);
      expect(payload['sub'], 'auth0|123');
    });

    test('token expired beyond leeway throws expired exception', () async {
      final keyPair = _generateRSAKeyPair();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        exp: now - 120, // Expired 2 minutes ago
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
        leeway: const Duration(seconds: 60), // 60 second leeway
      );

      expect(
        () => validator.validate(token),
        throwsA(isA<JwtException>().having((e) => e.isExpired, 'isExpired', true)),
      );
    });
  });

  group('JwtValidator — nonce', () {
    test('wrong nonce throws invalidNonce', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        nonce: 'token-nonce',
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      expect(
        () => validator.validate(token, nonce: 'expected-nonce'),
        throwsA(isA<JwtException>().having((e) => e.isInvalidNonce, 'isInvalidNonce', true)),
      );
    });

    test('missing nonce when expected throws invalidNonce', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        // No nonce in token
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      expect(
        () => validator.validate(token, nonce: 'expected-nonce'),
        throwsA(isA<JwtException>().having((e) => e.isInvalidNonce, 'isInvalidNonce', true)),
      );
    });

    test('nonce not requested is not validated', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        nonce: 'token-nonce',
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      // Should pass even though nonce is present but not validated
      final payload = await validator.validate(token);
      expect(payload['nonce'], 'token-nonce');
    });
  });

  group('JwtValidator — signature', () {
    test('tampered signature throws invalidSignature', () async {
      final keyPair = _generateRSAKeyPair();
      var token = _buildJwt(
        privateKey: keyPair.privateKey,
      );

      // Tamper with signature by replacing last character
      final parts = token.split('.');
      final tamperedSig = parts[2].substring(0, parts[2].length - 1) + 'X';
      token = '${parts[0]}.${parts[1]}.$tamperedSig';

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      await expectLater(
        validator.validate(token),
        throwsA(isA<JwtException>().having(
          (e) => e.isInvalidSignature || e.isMalformed,
          'isInvalidSignature or isMalformed',
          true,
        )),
      );
    });

    test('signed with different key throws invalidSignature', () async {
      final keyPair1 = _generateRSAKeyPair();
      final keyPair2 = _generateRSAKeyPair();

      // Token signed with keyPair1
      final token = _buildJwt(
        privateKey: keyPair1.privateKey,
      );

      // Validator configured with keyPair2 public key
      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair2.publicKey}),
      );

      expect(
        () => validator.validate(token),
        throwsA(isA<JwtException>().having((e) => e.isInvalidSignature, 'isInvalidSignature', true)),
      );
    });
  });

  group('JwtValidator — algorithm', () {
    test('non-RS256 algorithm throws malformed', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        algorithm: 'HS256', // Wrong algorithm
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      expect(
        () => validator.validate(token),
        throwsA(isA<JwtException>().having((e) => e.isMalformed, 'isMalformed', true)),
      );
    });

    test('unsupported algorithm throws malformed', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        algorithm: 'none',
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      expect(
        () => validator.validate(token),
        throwsA(isA<JwtException>().having((e) => e.isMalformed, 'isMalformed', true)),
      );
    });
  });

  group('JwtValidator — token issued in future', () {
    test('token with iat in future throws malformed', () async {
      final keyPair = _generateRSAKeyPair();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        iat: now + 3600, // Issued 1 hour in the future
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      expect(
        () => validator.validate(token),
        throwsA(isA<JwtException>().having((e) => e.isMalformed, 'isMalformed', true)),
      );
    });

    test('token with iat in near future within leeway passes', () async {
      final keyPair = _generateRSAKeyPair();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        iat: now + 30, // Issued 30 seconds in the future
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
        leeway: const Duration(seconds: 60),
      );

      final payload = await validator.validate(token);
      expect(payload['sub'], 'auth0|123');
    });
  });

  group('JwtValidator — missing kid', () {
    test('missing kid in header throws malformed', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        headerOverrides: {'kid': null}, // Remove kid
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      expect(
        () => validator.validate(token),
        throwsA(isA<JwtException>().having((e) => e.isMalformed, 'isMalformed', true)),
      );
    });
  });

  group('JwtValidator — organization', () {
    test('org_id match passes validation', () async {
      final keyPair = _generateRSAKeyPair();
      const orgId = 'org_test123';
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        orgId: orgId,
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      final payload = await validator.validate(token, organization: orgId);
      expect(payload['org_id'], orgId);
    });

    test('org_name match passes validation', () async {
      final keyPair = _generateRSAKeyPair();
      const orgName = 'Acme Inc';
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        orgName: orgName,
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      final payload = await validator.validate(token, organization: orgName);
      expect(payload['org_name'], orgName);
    });

    test('organization mismatch throws malformed', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        orgId: 'org_actual',
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      expect(
        () => validator.validate(token, organization: 'org_expected'),
        throwsA(isA<JwtException>().having((e) => e.isMalformed, 'isMalformed', true)),
      );
    });

    test('both org_id and org_name present, org_id checked first', () async {
      final keyPair = _generateRSAKeyPair();
      const orgId = 'org_id_match';
      const orgName = 'Different Org';
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        orgId: orgId,
        orgName: orgName,
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      // Should pass because org_id matches
      final payload = await validator.validate(token, organization: orgId);
      expect(payload['org_id'], orgId);
    });
  });

  group('JwtValidator — max_age', () {
    test('missing auth_time when max_age specified throws malformed', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        authTime: null, // No auth_time
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      expect(
        () => validator.validate(token, maxAge: 3600),
        throwsA(isA<JwtException>().having((e) => e.isMalformed, 'isMalformed', true)),
      );
    });

    test('auth_time too old (beyond max_age) throws expired', () async {
      final keyPair = _generateRSAKeyPair();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        authTime: now - 7200, // Authenticated 2 hours ago
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      // maxAge is 1 hour
      expect(
        () => validator.validate(token, maxAge: 3600),
        throwsA(isA<JwtException>().having((e) => e.isExpired, 'isExpired', true)),
      );
    });

    test('auth_time within max_age passes validation', () async {
      final keyPair = _generateRSAKeyPair();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        authTime: now - 1800, // Authenticated 30 minutes ago
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      // maxAge is 1 hour
      final payload = await validator.validate(token, maxAge: 3600);
      expect(payload['auth_time'], now - 1800);
    });

    test('auth_time near max_age boundary within leeway passes', () async {
      final keyPair = _generateRSAKeyPair();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        authTime: now - 3630, // Authenticated 1 hour 30 seconds ago (just beyond max_age)
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
        leeway: const Duration(seconds: 60), // 60 second leeway
      );

      // maxAge is 1 hour, but leeway allows this
      final payload = await validator.validate(token, maxAge: 3600);
      expect(payload['auth_time'], now - 3630);
    });
  });

  group('JwtValidator — key lookup', () {
    test('key with correct kid is fetched and used for verification', () async {
      final keyPair1 = _generateRSAKeyPair();
      final keyPair2 = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair1.privateKey,
        kid: 'kid-001',
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({
          'kid-001': keyPair1.publicKey,
          'kid-002': keyPair2.publicKey,
        }),
      );

      final payload = await validator.validate(token);
      expect(payload['sub'], 'auth0|123');
    });

    test('missing kid in client throws keyNotFound exception', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        kid: 'unknown-kid',
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'other-kid': keyPair.publicKey}),
      );

      expect(
        () => validator.validate(token),
        throwsA(isA<JwtException>()),
      );
    });
  });

  group('JwtValidator — complex scenarios', () {
    test('all validations pass together for well-formed token', () async {
      final keyPair = _generateRSAKeyPair();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const nonce = 'auth-nonce-abc';
      const orgId = 'org_complex_test';

      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        kid: 'prod-key-001',
        issuer: 'https://example.auth0.com',
        audience: 'myapp',
        nonce: nonce,
        authTime: now - 900, // 15 minutes ago
        orgId: orgId,
      );

      final validator = JwtValidator(
        issuer: 'https://example.auth0.com',
        audience: 'myapp',
        jwksClient: _MockJwksClient({'prod-key-001': keyPair.publicKey}),
        leeway: const Duration(seconds: 30),
      );

      final payload = await validator.validate(
        token,
        nonce: nonce,
        organization: orgId,
        maxAge: 3600,
      );

      expect(payload['iss'], 'https://example.auth0.com');
      expect(payload['aud'], 'myapp');
      expect(payload['nonce'], nonce);
      expect(payload['org_id'], orgId);
      expect(payload['auth_time'], now - 900);
    });

    test('multiple failures detected in order: algorithm checked before signature', () async {
      final keyPair = _generateRSAKeyPair();
      final token = _buildJwt(
        privateKey: keyPair.privateKey,
        algorithm: 'HS256', // Wrong algorithm
      );

      final validator = JwtValidator(
        issuer: 'https://test.auth0.com',
        audience: 'test_client',
        jwksClient: _MockJwksClient({'test-kid': keyPair.publicKey}),
      );

      // Should fail on algorithm check before signature
      await expectLater(
        validator.validate(token),
        throwsA(isA<JwtException>().having((e) => e.isMalformed, 'isMalformed', true)),
      );
    });
  });
}
