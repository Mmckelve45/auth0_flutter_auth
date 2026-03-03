class DatabaseUser {
  final String email;
  final bool emailVerified;
  final String? id;
  final String? username;

  DatabaseUser({
    required this.email,
    required this.emailVerified,
    this.id,
    this.username,
  });

  factory DatabaseUser.fromJson(Map<String, dynamic> json) {
    return DatabaseUser(
      email: json['email'] as String,
      emailVerified: json['email_verified'] as bool? ?? false,
      id: json['_id'] as String?,
      username: json['username'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'email': email,
        'email_verified': emailVerified,
        if (id != null) '_id': id,
        if (username != null) 'username': username,
      };

  @override
  String toString() =>
      'DatabaseUser(email: $email, emailVerified: $emailVerified)';
}
