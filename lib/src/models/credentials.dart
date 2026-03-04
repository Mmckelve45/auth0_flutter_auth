import '../jwt/jwt_decoder.dart';
import 'user_profile.dart';

class Credentials {
  final String accessToken;
  final String tokenType;
  final String? idToken;
  final String? refreshToken;
  final DateTime expiresAt;
  final Set<String> scopes;

  Credentials({
    required this.accessToken,
    required this.tokenType,
    this.idToken,
    this.refreshToken,
    required this.expiresAt,
    this.scopes = const {},
  });

  UserProfile? get user {
    if (idToken == null) return null;
    try {
      return UserProfile.fromJson(JwtDecoder(idToken!).payload);
    } catch (_) {
      return null;
    }
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get expiresInSeconds =>
      expiresAt.difference(DateTime.now()).inSeconds.clamp(0, double.maxFinite.toInt());

  factory Credentials.fromJson(Map<String, dynamic> json) {
    final expiresIn = json['expires_in'] as int?;
    final expiresAtMs = json['expires_at'] as int?;

    DateTime expiresAt;
    if (expiresAtMs != null) {
      expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
    } else if (expiresIn != null) {
      expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    } else {
      expiresAt = DateTime.now().add(const Duration(hours: 1));
    }

    final scopeStr = json['scope'] as String? ?? '';
    final scopes = scopeStr.isEmpty
        ? <String>{}
        : scopeStr.split(' ').where((s) => s.isNotEmpty).toSet();

    return Credentials(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      idToken: json['id_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      expiresAt: expiresAt,
      scopes: scopes,
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        if (idToken != null) 'id_token': idToken,
        if (refreshToken != null) 'refresh_token': refreshToken,
        'expires_at': expiresAt.millisecondsSinceEpoch,
        'scope': scopes.join(' '),
      };

  @override
  String toString() =>
      'Credentials(tokenType: $tokenType, expiresAt: $expiresAt, scopes: $scopes)';
}
