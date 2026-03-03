class SSOCredentials {
  final String accessToken;
  final String tokenType;
  final String? idToken;
  final DateTime expiresAt;
  final Set<String> scopes;

  SSOCredentials({
    required this.accessToken,
    required this.tokenType,
    this.idToken,
    required this.expiresAt,
    this.scopes = const {},
  });

  factory SSOCredentials.fromJson(Map<String, dynamic> json) {
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

    return SSOCredentials(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      idToken: json['id_token'] as String?,
      expiresAt: expiresAt,
      scopes: scopes,
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'token_type': tokenType,
        if (idToken != null) 'id_token': idToken,
        'expires_at': expiresAt.millisecondsSinceEpoch,
        'scope': scopes.join(' '),
      };

  @override
  String toString() =>
      'SSOCredentials(tokenType: $tokenType, expiresAt: $expiresAt)';
}
