class UserProfile {
  final String sub;
  final String? name;
  final String? givenName;
  final String? familyName;
  final String? middleName;
  final String? nickname;
  final String? preferredUsername;
  final String? email;
  final bool? emailVerified;
  final String? pictureUrl;
  final String? profileUrl;
  final String? websiteUrl;
  final String? phoneNumber;
  final bool? phoneNumberVerified;
  final String? gender;
  final String? birthdate;
  final String? zoneinfo;
  final String? locale;
  final DateTime? updatedAt;
  final Map<String, dynamic> customClaims;

  UserProfile({
    required this.sub,
    this.name,
    this.givenName,
    this.familyName,
    this.middleName,
    this.nickname,
    this.preferredUsername,
    this.email,
    this.emailVerified,
    this.pictureUrl,
    this.profileUrl,
    this.websiteUrl,
    this.phoneNumber,
    this.phoneNumberVerified,
    this.gender,
    this.birthdate,
    this.zoneinfo,
    this.locale,
    this.updatedAt,
    this.customClaims = const {},
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final knownKeys = {
      'sub', 'name', 'given_name', 'family_name', 'middle_name',
      'nickname', 'preferred_username', 'email', 'email_verified',
      'picture', 'profile', 'website', 'phone_number',
      'phone_number_verified', 'gender', 'birthdate', 'zoneinfo',
      'locale', 'updated_at',
    };

    final customClaims = Map<String, dynamic>.from(json)
      ..removeWhere((key, _) => knownKeys.contains(key));

    DateTime? updatedAt;
    final updatedAtValue = json['updated_at'];
    if (updatedAtValue is String) {
      updatedAt = DateTime.tryParse(updatedAtValue);
    }

    return UserProfile(
      sub: json['sub'] as String,
      name: json['name'] as String?,
      givenName: json['given_name'] as String?,
      familyName: json['family_name'] as String?,
      middleName: json['middle_name'] as String?,
      nickname: json['nickname'] as String?,
      preferredUsername: json['preferred_username'] as String?,
      email: json['email'] as String?,
      emailVerified: json['email_verified'] as bool?,
      pictureUrl: json['picture'] as String?,
      profileUrl: json['profile'] as String?,
      websiteUrl: json['website'] as String?,
      phoneNumber: json['phone_number'] as String?,
      phoneNumberVerified: json['phone_number_verified'] as bool?,
      gender: json['gender'] as String?,
      birthdate: json['birthdate'] as String?,
      zoneinfo: json['zoneinfo'] as String?,
      locale: json['locale'] as String?,
      updatedAt: updatedAt,
      customClaims: customClaims,
    );
  }

  Map<String, dynamic> toJson() => {
        'sub': sub,
        if (name != null) 'name': name,
        if (givenName != null) 'given_name': givenName,
        if (familyName != null) 'family_name': familyName,
        if (middleName != null) 'middle_name': middleName,
        if (nickname != null) 'nickname': nickname,
        if (preferredUsername != null) 'preferred_username': preferredUsername,
        if (email != null) 'email': email,
        if (emailVerified != null) 'email_verified': emailVerified,
        if (pictureUrl != null) 'picture': pictureUrl,
        if (profileUrl != null) 'profile': profileUrl,
        if (websiteUrl != null) 'website': websiteUrl,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (phoneNumberVerified != null)
          'phone_number_verified': phoneNumberVerified,
        if (gender != null) 'gender': gender,
        if (birthdate != null) 'birthdate': birthdate,
        if (zoneinfo != null) 'zoneinfo': zoneinfo,
        if (locale != null) 'locale': locale,
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        ...customClaims,
      };

  @override
  String toString() => 'UserProfile(sub: $sub, email: $email, name: $name)';
}
