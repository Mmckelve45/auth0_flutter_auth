import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../main.dart';
import '../widgets/method_tile.dart' show MethodTile, truncate;
import '../widgets/method_tile_with_form.dart';

class ApiExplorerTab extends StatefulWidget {
  const ApiExplorerTab({super.key});

  @override
  State<ApiExplorerTab> createState() => _ApiExplorerTabState();
}

class _ApiExplorerTabState extends State<ApiExplorerTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader('Credential Store'),
        MethodTile(
          name: 'credentials.getCredentials()',
          description:
              'Retrieve stored credentials, auto-refreshing if expired.',
          onRun: () async {
            final c = await auth0.credentials.getCredentials();
            if (c == null) return 'No credentials stored';
            return 'accessToken: ${truncate(c.accessToken)}\n'
                'expiresAt: ${c.expiresAt.toLocal()}\n'
                'scopes: ${c.scopes.join(', ')}\n'
                'hasRefreshToken: ${c.refreshToken != null}';
          },
        ),
        MethodTile(
          name: 'credentials.hasValidCredentials()',
          description:
              'Check if valid credentials exist without retrieving them.',
          onRun: () async {
            final valid = await auth0.credentials.hasValidCredentials();
            return 'hasValidCredentials: $valid';
          },
        ),
        MethodTile(
          name: 'credentials.hasValidCredentials(minTtl: 3600)',
          description: 'Check validity with a 1-hour minimum TTL.',
          onRun: () async {
            final valid =
                await auth0.credentials.hasValidCredentials(minTtl: 3600);
            return 'hasValidCredentials(minTtl=3600): $valid';
          },
        ),
        MethodTile(
          name: 'credentials.user()',
          description: 'Extract user profile from the stored ID token.',
          onRun: () async {
            final user = await auth0.credentials.user();
            if (user == null) return 'No user (no ID token stored)';
            return const JsonEncoder.withIndent('  ').convert(user.toJson());
          },
        ),
        MethodTile(
          name: 'credentials.renewCredentials()',
          description:
              'Force refresh using stored refresh token. Updates stored credentials.',
          onRun: () async {
            final c = await auth0.credentials.renewCredentials();
            return 'Refreshed!\n'
                'accessToken: ${truncate(c.accessToken)}\n'
                'expiresAt: ${c.expiresAt.toLocal()}';
          },
        ),
        const Divider(height: 32),
        _sectionHeader('Authentication API'),
        MethodTile(
          name: 'api.getUserInfo(accessToken)',
          description: 'Call /userinfo with the current access token.',
          onRun: () async {
            final creds = await auth0.credentials.getCredentials();
            if (creds == null) return 'No credentials — log in first';
            final user = await auth0.api.getUserInfo(accessToken: creds.accessToken);
            return const JsonEncoder.withIndent('  ').convert(user.toJson());
          },
        ),
        MethodTileWithForm(
          name: 'api.signup()',
          description:
              'POST /dbconnections/signup — create a new database user.',
          fields: const ['email', 'password', 'connection'],
          defaults: const {'connection': 'Username-Password-Authentication'},
          onRun: (values) async {
            final result = await auth0.api.signup(
              email: values['email']!,
              password: values['password']!,
              connection: values['connection']!,
            );
            return const JsonEncoder.withIndent('  ')
                .convert(result.toJson());
          },
        ),
        MethodTileWithForm(
          name: 'api.resetPassword()',
          description:
              'POST /dbconnections/change_password — send a password reset email.',
          fields: const ['email', 'connection'],
          defaults: const {'connection': 'Username-Password-Authentication'},
          onRun: (values) async {
            await auth0.api.resetPassword(
              email: values['email']!,
              connection: values['connection']!,
            );
            return 'Password reset email sent.';
          },
        ),
        MethodTileWithForm(
          name: 'api.customTokenExchange()',
          description:
              'POST /oauth/token (token-exchange grant). Exchange an external token.',
          fields: const ['subjectToken', 'subjectTokenType'],
          defaults: const {
            'subjectTokenType': 'urn:ietf:params:oauth:token-type:access_token'
          },
          onRun: (values) async {
            final c = await auth0.api.customTokenExchange(
              subjectToken: values['subjectToken']!,
              subjectTokenType: values['subjectTokenType']!,
            );
            return 'Exchange success!\naccessToken: ${truncate(c.accessToken)}\n'
                'expiresAt: ${c.expiresAt.toLocal()}';
          },
        ),
        MethodTile(
          name: 'credentials.ssoCredentials()',
          description:
              'SSO token exchange using stored refresh token for cross-app SSO.',
          onRun: () async {
            final sso = await auth0.credentials.ssoCredentials();
            return 'SSO exchange success!\naccessToken: ${truncate(sso.accessToken)}';
          },
        ),
        const Divider(height: 32),
        _sectionHeader('Passkeys (Early Access)'),
        MethodTile(
          name: 'passkeys.isAvailable()',
          description: 'Check if passkeys are supported on this device.',
          onRun: () async {
            final passkeys = auth0.passkeys;
            if (passkeys == null) return 'Passkeys not enabled on this Auth0Client.';
            final available = await passkeys.isAvailable();
            return 'isAvailable: $available';
          },
        ),
        MethodTile(
          name: 'passkeys.enroll(accessToken)',
          description:
              'Enroll a passkey for the current user (requires logged-in user with access token).',
          onRun: () async {
            final passkeys = auth0.passkeys;
            if (passkeys == null) return 'Passkeys not enabled.';
            final creds = await auth0.credentials.getCredentials();
            if (creds == null) return 'No credentials — log in first.';
            await passkeys.enroll(accessToken: creds.accessToken);
            return 'Passkey enrolled successfully.';
          },
        ),
        const Divider(height: 32),
        _sectionHeader('DPoP'),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demonstration of Proof-of-Possession',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'DPoP (RFC 9449) binds access tokens to a cryptographic key '
                  'pair so that stolen tokens cannot be replayed by an attacker. '
                  'Each API request includes a signed proof JWT proving the '
                  'sender holds the private key. The key pair is hardware-backed '
                  '(Secure Enclave on iOS/macOS, Android Keystore on Android) '
                  'and never leaves the device.',
                ),
                const SizedBox(height: 12),
                Text(
                  'How to enable',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'final auth0 = Auth0Client(\n'
                    '  domain: \'your-tenant.auth0.com\',\n'
                    '  clientId: \'YOUR_CLIENT_ID\',\n'
                    '  options: Auth0ClientOptions(\n'
                    '    enableDPoP: true,\n'
                    '  ),\n'
                    ');',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Once enabled, call dpop.initialize() to generate the key '
                  'pair, then dpop.generateHeaders() to create proof headers '
                  'for your API requests. Your Auth0 API must also be '
                  'configured to require DPoP-bound tokens in the dashboard '
                  'under API Settings > Token Settings.',
                ),
              ],
            ),
          ),
        ),
        MethodTile(
          name: 'dpop.initialize()',
          description:
              'Generate a hardware-backed EC key pair (Secure Enclave / Keystore).',
          onRun: () async {
            final dpop = auth0.dpop;
            if (dpop == null) return 'DPoP not enabled on this Auth0Client.';
            await dpop.initialize();
            return 'DPoP initialized. isInitialized: ${dpop.isInitialized}';
          },
        ),
        MethodTile(
          name: 'dpop.generateHeaders()',
          description: 'Sign a DPoP proof JWT for a sample request.',
          onRun: () async {
            final dpop = auth0.dpop;
            if (dpop == null) return 'DPoP not enabled.';
            if (!dpop.isInitialized) return 'Call initialize() first.';
            final headers = await dpop.generateHeaders(
              url: 'https://${dotenv.env['AUTH0_DOMAIN']}/oauth/token',
              method: 'POST',
            );
            return 'DPoP header:\n${headers['DPoP']}';
          },
        ),
        MethodTile(
          name: 'dpop.clear()',
          description: 'Delete the DPoP key pair.',
          onRun: () async {
            final dpop = auth0.dpop;
            if (dpop == null) return 'DPoP not enabled.';
            await dpop.clear();
            return 'DPoP key pair cleared. isInitialized: ${dpop.isInitialized}';
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
