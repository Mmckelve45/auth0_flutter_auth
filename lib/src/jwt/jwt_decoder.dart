import 'dart:convert';
import 'dart:typed_data';
import '../exceptions/jwt_exception.dart';

class JwtDecoder {
  final String token;
  late final Map<String, dynamic> header;
  late final Map<String, dynamic> payload;
  late final Uint8List signature;
  late final Uint8List signedData; // header.payload bytes for sig verification

  JwtDecoder(this.token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw JwtException.malformed('Expected 3 parts, got ${parts.length}');
    }

    try {
      header = _decodeJson(parts[0]);
    } catch (e) {
      throw JwtException.malformed('Invalid header');
    }

    try {
      payload = _decodeJson(parts[1]);
    } catch (e) {
      throw JwtException.malformed('Invalid payload');
    }

    try {
      signature = _decodeBase64Url(parts[2]);
    } catch (e) {
      throw JwtException.malformed('Invalid signature');
    }

    signedData = Uint8List.fromList(utf8.encode('${parts[0]}.${parts[1]}'));
  }

  Map<String, dynamic> _decodeJson(String part) {
    final decoded = utf8.decode(_decodeBase64Url(part));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  static Uint8List _decodeBase64Url(String input) {
    String normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    switch (normalized.length % 4) {
      case 0:
        break;
      case 2:
        normalized += '==';
        break;
      case 3:
        normalized += '=';
        break;
      default:
        throw FormatException('Invalid base64url length');
    }
    return base64Decode(normalized);
  }

  String? get issuer => payload['iss'] as String?;
  String? get subject => payload['sub'] as String?;
  dynamic get audience => payload['aud'];
  String? get nonce => payload['nonce'] as String?;
  String? get keyId => header['kid'] as String?;
  String? get algorithm => header['alg'] as String?;

  DateTime? get expiresAt {
    final exp = payload['exp'] as int?;
    if (exp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  }

  DateTime? get issuedAt {
    final iat = payload['iat'] as int?;
    if (iat == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(iat * 1000);
  }

  bool get isExpired {
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().isAfter(exp);
  }

  /// Decodes a JWT payload without validating. Useful for quick inspection.
  static Map<String, dynamic> decodePayload(String token) {
    return JwtDecoder(token).payload;
  }
}
