import 'package:flutter/material.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';
import 'package:auth0_flutter_auth/src/jwt/jwt_decoder.dart';
import '../main.dart';
import '../widgets/token_card.dart';
import '../widgets/raw_token_card.dart';

void _log(String message) {
  debugPrint('[Auth0Example] $message');
}

class ProfileTab extends StatefulWidget {
  const ProfileTab();

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  UserProfile? _user;
  Credentials? _credentials;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final creds = await auth0.credentials.getCredentials();
      final user = await auth0.credentials.user();
      if (mounted) {
        setState(() {
          _credentials = creds;
          _user = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      _log('Failed to load profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshToken() async {
    try {
      await auth0.credentials.renewCredentials();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Token refreshed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
      }
    }
  }

  String? _pictureFromIdToken() {
    final idToken = _credentials?.idToken;
    if (idToken == null) return null;
    try {
      return JwtDecoder(idToken).payload['picture'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_user != null) _buildUserCard(),
        const SizedBox(height: 12),
        if (_credentials != null) _buildMetadataCard(),
        const SizedBox(height: 12),
        if (_credentials != null)
          TokenCard(title: 'Access Token', token: _credentials!.accessToken),
        const SizedBox(height: 12),
        if (_credentials?.idToken != null)
          TokenCard(title: 'ID Token', token: _credentials!.idToken!),
        const SizedBox(height: 12),
        if (_credentials?.refreshToken != null)
          RawTokenCard(
              title: 'Refresh Token', token: _credentials!.refreshToken!),
      ],
    );
  }

  Widget _buildUserCard() {
    final pictureUrl = _pictureFromIdToken() ?? _user?.pictureUrl;
    _log('pictureUrl: $pictureUrl');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (pictureUrl != null)
              CircleAvatar(
                radius: 30,
                backgroundImage: NetworkImage(pictureUrl),
                onBackgroundImageError: (e, __) {
                  _log('Failed to load avatar: $e');
                },
              ),
            if (pictureUrl != null) const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_user?.name ?? 'Unknown',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (_user?.email != null)
                    Text(_user!.email!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  Text(_user!.sub,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                          fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataCard() {
    final c = _credentials!;
    final remaining = c.expiresAt.difference(DateTime.now());
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    final expiresStr =
        h > 0 ? '${h}h ${m}m ${s}s' : (m > 0 ? '${m}m ${s}s' : '${s}s');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Token Info',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _refreshToken,
                  tooltip: 'Refresh Token',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _metaRow('Type', c.tokenType),
            _metaRow('Expires In', expiresStr),
            _metaRow('Expires At', c.expiresAt.toLocal().toString()),
            _metaRow('Scopes', c.scopes.join(', ')),
            _metaRow(
                'Has Refresh Token', c.refreshToken != null ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
