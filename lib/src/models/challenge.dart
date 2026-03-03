class Challenge {
  final String challengeType;
  final String? oobCode;
  final String? bindingMethod;

  Challenge({
    required this.challengeType,
    this.oobCode,
    this.bindingMethod,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      challengeType: json['challenge_type'] as String,
      oobCode: json['oob_code'] as String?,
      bindingMethod: json['binding_method'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'challenge_type': challengeType,
        if (oobCode != null) 'oob_code': oobCode,
        if (bindingMethod != null) 'binding_method': bindingMethod,
      };

  @override
  String toString() =>
      'Challenge(challengeType: $challengeType, bindingMethod: $bindingMethod)';
}
