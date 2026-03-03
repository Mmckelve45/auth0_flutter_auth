import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class Pkce {
  final String codeVerifier;
  final String codeChallenge;

  Pkce._({required this.codeVerifier, required this.codeChallenge});

  factory Pkce.generate() {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);
    return Pkce._(codeVerifier: verifier, codeChallenge: challenge);
  }

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
