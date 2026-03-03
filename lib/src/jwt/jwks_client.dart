import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pointycastle/pointycastle.dart';
import '../exceptions/jwt_exception.dart';

class JwksClient {
  final String domain;
  final http.Client _httpClient;
  final Duration _cacheDuration;

  Map<String, RSAPublicKey>? _cachedKeys;
  DateTime? _cacheExpiry;

  JwksClient({
    required this.domain,
    http.Client? httpClient,
    Duration cacheDuration = const Duration(hours: 1),
  })  : _httpClient = httpClient ?? http.Client(),
        _cacheDuration = cacheDuration;

  Future<RSAPublicKey> getKey(String kid) async {
    if (_cachedKeys != null &&
        _cacheExpiry != null &&
        DateTime.now().isBefore(_cacheExpiry!)) {
      final key = _cachedKeys![kid];
      if (key != null) return key;
    }

    await _fetchKeys();

    final key = _cachedKeys?[kid];
    if (key == null) {
      throw JwtException.keyNotFound(kid);
    }
    return key;
  }

  Future<void> _fetchKeys() async {
    final url = Uri.https(domain, '/.well-known/jwks.json');
    try {
      final response = await _httpClient.get(url).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        throw JwtException.jwksFetchError(
          cause: 'HTTP ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final keys = json['keys'] as List<dynamic>;

      _cachedKeys = {};
      for (final keyJson in keys) {
        final key = keyJson as Map<String, dynamic>;
        if (key['kty'] != 'RSA' || key['use'] != 'sig') continue;

        final kid = key['kid'] as String?;
        if (kid == null) continue;

        try {
          final n = _decodeBigInt(key['n'] as String);
          final e = _decodeBigInt(key['e'] as String);
          _cachedKeys![kid] = RSAPublicKey(n, e);
        } catch (_) {
          // Skip malformed keys
        }
      }

      _cacheExpiry = DateTime.now().add(_cacheDuration);
    } on JwtException {
      rethrow;
    } catch (e) {
      throw JwtException.jwksFetchError(cause: e);
    }
  }

  static BigInt _decodeBigInt(String base64Url) {
    String normalized = base64Url.replaceAll('-', '+').replaceAll('_', '/');
    switch (normalized.length % 4) {
      case 0:
        break;
      case 2:
        normalized += '==';
        break;
      case 3:
        normalized += '=';
        break;
    }
    final bytes = base64Decode(normalized);
    return _bytesToBigInt(Uint8List.fromList(bytes));
  }

  static BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (int i = 0; i < bytes.length; i++) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    return result;
  }

  void clearCache() {
    _cachedKeys = null;
    _cacheExpiry = null;
  }

  void close() {
    _httpClient.close();
  }
}
