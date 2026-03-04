class AuthorizeUrlBuilder {
  final String domain;
  final String clientId;

  AuthorizeUrlBuilder({required this.domain, required this.clientId});

  Uri buildAuthorizeUrl({
    required String redirectUrl,
    required String state,
    required String codeChallenge,
    String? audience,
    Set<String> scopes = const {},
    String? organizationId,
    String? invitationUrl,
    int? maxAge,
    String? nonce,
    String? connection,
    String? connectionScope,
    Map<String, String>? parameters,
  }) {
    final queryParams = <String, String>{
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUrl,
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      if (audience != null) 'audience': audience,
      if (scopes.isNotEmpty) 'scope': scopes.join(' '),
      if (organizationId != null) 'organization': organizationId,
      if (invitationUrl != null) 'invitation': invitationUrl,
      if (maxAge != null) 'max_age': maxAge.toString(),
      if (nonce != null) 'nonce': nonce,
      if (connection != null) 'connection': connection,
      if (connectionScope != null) 'connection_scope': connectionScope,
      ...?parameters,
    };

    return Uri.https(domain, '/authorize', queryParams);
  }

  Uri buildLogoutUrl({
    String? returnTo,
    bool federated = false,
  }) {
    final queryParams = <String, String>{
      'client_id': clientId,
      if (returnTo != null) 'returnTo': returnTo,
      if (federated) 'federated': '',
    };

    return Uri.https(domain, '/v2/logout', queryParams);
  }
}
