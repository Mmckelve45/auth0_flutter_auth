class WebAuthOptions {
  final String? redirectUrl;
  final String? audience;
  final Set<String> scopes;
  final bool preferEphemeral;
  final String? organizationId;
  final String? invitationUrl;
  final int? maxAge;
  final Map<String, String> parameters;

  const WebAuthOptions({
    this.redirectUrl,
    this.audience,
    this.scopes = const {'openid', 'profile', 'email'},
    this.preferEphemeral = false,
    this.organizationId,
    this.invitationUrl,
    this.maxAge,
    this.parameters = const {},
  });
}
