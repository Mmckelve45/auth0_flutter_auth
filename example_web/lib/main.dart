import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

/// Web example: redirect-based flow using buildAuthorizeUrl + handleCallback.
///
/// How it works:
/// 1. User clicks "Log In" → app calls buildAuthorizeUrl() → redirects browser
/// 2. Auth0 processes login → redirects back to /callback?code=...&state=...
/// 3. GoRouter routes to CallbackScreen → calls handleCallback() → exchanges code
/// 4. Credentials are stored and user sees profile
///
/// Configuration:
/// - Set your Auth0 domain, client ID, and redirect URL below
/// - In Auth0 dashboard: add http://localhost:PORT/callback to Allowed Callback URLs
/// - Add http://localhost:PORT to Allowed Logout URLs and Allowed Web Origins

// ──────── CONFIGURATION ────────
const auth0Domain = 'YOUR_AUTH0_DOMAIN';
const auth0ClientId = 'YOUR_AUTH0_CLIENT_ID';
// For flutter run -d chrome, the default port is 5000 or a random port
// Use the URL shown in the terminal after `flutter run -d chrome`
const redirectUrl = 'http://localhost:5000/callback';
const logoutReturnTo = 'http://localhost:5000/';
// ────────────────────────────────

late final Auth0Client auth0;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  auth0 = Auth0Client(domain: auth0Domain, clientId: auth0ClientId);
  runApp(const WebExampleApp());
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/callback',
      builder: (context, state) => CallbackScreen(uri: state.uri),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);

class WebExampleApp extends StatelessWidget {
  const WebExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Auth0 Web Example',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      routerConfig: _router,
    );
  }
}

// ─────── HOME SCREEN ───────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _login(BuildContext context) {
    // Build the authorize URL (stores PKCE state internally)
    final url = auth0.webAuth.buildAuthorizeUrl(
      redirectUrl: redirectUrl,
      audience: 'https://$auth0Domain/api/v2/',
      scopes: {'openid', 'profile', 'email', 'offline_access'},
    );

    // Redirect the browser to Auth0
    // In Flutter web, use url_launcher or html.window.location.href
    _redirectTo(url.toString());
  }

  /// Redirect the browser window. On web this uses dart:html.
  void _redirectTo(String url) {
    // ignore: avoid_web_libraries_in_flutter
    // In a real app, use: import 'dart:html' as html;
    // html.window.location.href = url;
    //
    // For this example, we show the URL for manual testing:
    debugPrint('Redirect to: $url');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auth0 Web Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Redirect-based Auth0 login for Flutter Web',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _login(context),
              icon: const Icon(Icons.login),
              label: const Text('Log In with Auth0'),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will redirect you to Auth0 Universal Login.\n'
              'After login, you\'ll be redirected back to /callback.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────── CALLBACK SCREEN ───────

class CallbackScreen extends StatefulWidget {
  final Uri uri;
  const CallbackScreen({super.key, required this.uri});

  @override
  State<CallbackScreen> createState() => _CallbackScreenState();
}

class _CallbackScreenState extends State<CallbackScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      // Exchange the authorization code for tokens
      final credentials = await auth0.webAuth.handleCallback(widget.uri);
      await auth0.credentials.storeCredentials(credentials);

      if (mounted) context.go('/profile');
    } on WebAuthException catch (e) {
      setState(() => _error = 'Auth error: ${e.message}');
    } on ApiException catch (e) {
      setState(() => _error = 'API error: ${e.message}');
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _error != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Back to Home'),
                  ),
                ],
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Exchanging authorization code...'),
                ],
              ),
      ),
    );
  }
}

// ─────── PROFILE SCREEN ───────

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _user;
  Credentials? _credentials;
  bool _isLoading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await auth0.credentials.user();
    final creds = await auth0.credentials.getCredentials();
    setState(() {
      _user = user;
      _credentials = creds;
      _isLoading = false;
    });
  }

  Future<void> _refresh() async {
    try {
      final creds = await auth0.credentials.renewCredentials();
      setState(() {
        _credentials = creds;
        _message = 'Token refreshed successfully';
      });
    } catch (e) {
      setState(() => _message = 'Refresh failed: $e');
    }
  }

  Future<void> _fetchUserInfo() async {
    try {
      final creds = await auth0.credentials.getCredentials();
      if (creds == null) return;
      final profile = await auth0.api.getUserInfo(creds.accessToken);
      setState(() {
        _user = profile;
        _message = 'User info fetched from /userinfo endpoint';
      });
    } catch (e) {
      setState(() => _message = 'Error: $e');
    }
  }

  void _logout() {
    auth0.credentials.clearCredentials();
    // Redirect to Auth0 logout
    final logoutUrl = Uri.https(auth0Domain, '/v2/logout', {
      'client_id': auth0ClientId,
      'returnTo': logoutReturnTo,
    });
    debugPrint('Logout URL: $logoutUrl');
    // In production: html.window.location.href = logoutUrl.toString();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          IconButton(icon: const Icon(Icons.person_search), onPressed: _fetchUserInfo),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_message != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_message!),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_user != null) ...[
              Center(
                child: Column(
                  children: [
                    if (_user!.pictureUrl != null)
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(_user!.pictureUrl!),
                      ),
                    const SizedBox(height: 12),
                    Text(_user!.name ?? 'Unknown',
                        style: Theme.of(context).textTheme.headlineMedium),
                    Text(_user!.email ?? '',
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_credentials != null) ...[
              Text('Token Details',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _infoRow('Token Type', _credentials!.tokenType),
              _infoRow('Expires At', _credentials!.expiresAt.toIso8601String()),
              _infoRow('Expires In', '${_credentials!.expiresInSeconds}s'),
              _infoRow('Scopes', _credentials!.scopes.join(', ')),
              _infoRow('Has Refresh Token',
                  _credentials!.refreshToken != null ? 'Yes' : 'No'),
              _infoRow('Has ID Token',
                  _credentials!.idToken != null ? 'Yes' : 'No'),
              const SizedBox(height: 16),
              Text('Access Token (first 50 chars)',
                  style: Theme.of(context).textTheme.titleSmall),
              SelectableText(
                _credentials!.accessToken.length > 50
                    ? '${_credentials!.accessToken.substring(0, 50)}...'
                    : _credentials!.accessToken,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
