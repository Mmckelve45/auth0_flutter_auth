class PasskeyChallenge {
  final Map<String, dynamic> authnParamsPublicKey;
  final String authSession;

  PasskeyChallenge({
    required this.authnParamsPublicKey,
    required this.authSession,
  });

  factory PasskeyChallenge.fromJson(Map<String, dynamic> json) {
    return PasskeyChallenge(
      authnParamsPublicKey:
          json['authn_params_public_key'] as Map<String, dynamic>,
      authSession: json['auth_session'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'authn_params_public_key': authnParamsPublicKey,
        'auth_session': authSession,
      };

  @override
  String toString() =>
      'PasskeyChallenge(authSession: $authSession)';
}
