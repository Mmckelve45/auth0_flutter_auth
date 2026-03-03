import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import '../exceptions/jwt_exception.dart';
import 'jwt_decoder.dart';
import 'jwks_client.dart';

class JwtValidator {
  final String issuer;
  final String audience;
  final JwksClient _jwksClient;
  final Duration _leeway;

  JwtValidator({
    required this.issuer,
    required this.audience,
    required JwksClient jwksClient,
    Duration leeway = const Duration(seconds: 60),
  })  : _jwksClient = jwksClient,
        _leeway = leeway;

  /// Validates the ID token: verifies RS256 signature and checks claims.
  Future<Map<String, dynamic>> validate(
    String idToken, {
    String? nonce,
    String? organization,
    int? maxAge,
  }) async {
    final jwt = JwtDecoder(idToken);

    // Check algorithm
    if (jwt.algorithm != 'RS256') {
      throw JwtException.malformed(
          'Unsupported algorithm: ${jwt.algorithm}');
    }

    // Check issuer
    final expectedIssuer = issuer.endsWith('/')
        ? issuer
        : '$issuer/';
    final actualIssuer = jwt.issuer ?? '';
    final normalizedActual = actualIssuer.endsWith('/')
        ? actualIssuer
        : '$actualIssuer/';
    if (normalizedActual != expectedIssuer) {
      throw JwtException.invalidIssuer(expectedIssuer, actualIssuer);
    }

    // Check audience
    final aud = jwt.audience;
    final audList = aud is List
        ? aud.cast<String>()
        : [aud as String];
    if (!audList.contains(audience)) {
      throw JwtException.invalidAudience(audience, audList.join(', '));
    }

    // Check expiration
    final now = DateTime.now();
    final exp = jwt.expiresAt;
    if (exp != null && now.isAfter(exp.add(_leeway))) {
      throw JwtException.expired();
    }

    // Check issued at (not too far in the future)
    final iat = jwt.issuedAt;
    if (iat != null && iat.isAfter(now.add(_leeway))) {
      throw JwtException.malformed('Token issued in the future');
    }

    // Check nonce
    if (nonce != null) {
      final tokenNonce = jwt.nonce;
      if (tokenNonce != nonce) {
        throw JwtException.invalidNonce(nonce, tokenNonce ?? '(null)');
      }
    }

    // Check organization
    if (organization != null) {
      final orgId = jwt.payload['org_id'] as String?;
      final orgName = jwt.payload['org_name'] as String?;
      if (orgId != organization && orgName != organization) {
        throw JwtException.malformed(
          'Organization mismatch: expected "$organization"',
        );
      }
    }

    // Check auth_time for max_age
    if (maxAge != null) {
      final authTime = jwt.payload['auth_time'] as int?;
      if (authTime == null) {
        throw JwtException.malformed(
          'max_age specified but auth_time claim is missing',
        );
      }
      final authDateTime =
          DateTime.fromMillisecondsSinceEpoch(authTime * 1000);
      final maxAuthAge = Duration(seconds: maxAge);
      if (now.isAfter(authDateTime.add(maxAuthAge).add(_leeway))) {
        throw JwtException.expired();
      }
    }

    // Verify RS256 signature
    final kid = jwt.keyId;
    if (kid == null) {
      throw JwtException.malformed('Missing kid in JWT header');
    }

    final publicKey = await _jwksClient.getKey(kid);
    final isValid = _verifyRS256(jwt.signedData, jwt.signature, publicKey);
    if (!isValid) {
      throw JwtException.invalidSignature();
    }

    return jwt.payload;
  }

  bool _verifyRS256(
      Uint8List data, Uint8List signature, RSAPublicKey publicKey) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201');
    signer.init(
      false,
      PublicKeyParameter<RSAPublicKey>(publicKey),
    );

    try {
      return signer.verifySignature(data, RSASignature(signature));
    } catch (_) {
      return false;
    }
  }
}
