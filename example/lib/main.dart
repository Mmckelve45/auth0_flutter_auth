import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';

late final Auth0Client auth0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  auth0 = Auth0Client(
    domain: dotenv.env['AUTH0_DOMAIN']!,
    clientId: dotenv.env['AUTH0_CLIENT_ID']!,
  );
  runApp(const MyApp());
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
      builder: (context, state) {
        // Handle the callback from Auth0 (web redirect flow)
        return CallbackScreen(uri: state.uri);
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Auth0 Flutter Auth Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final credentials = await auth0.webAuth.login(
        audience: 'https://${dotenv.env['AUTH0_DOMAIN']}/api/v2/',
        scopes: {'openid', 'profile', 'email', 'offline_access'},
      );

      // Store credentials
      await auth0.credentials.storeCredentials(credentials);

      if (mounted) {
        context.go('/profile');
      }
    } on WebAuthException catch (e) {
      if (!e.isCancelled) {
        setState(() => _error = e.message);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auth0 Flutter Auth')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            FilledButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Log In'),
            ),
          ],
        ),
      ),
    );
  }
}

class CallbackScreen extends StatefulWidget {
  final Uri uri;
  const CallbackScreen({super.key, required this.uri});

  @override
  State<CallbackScreen> createState() => _CallbackScreenState();
}

class _CallbackScreenState extends State<CallbackScreen> {
  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    try {
      final credentials = await auth0.webAuth.handleCallback(widget.uri);
      await auth0.credentials.storeCredentials(credentials);
      if (mounted) {
        context.go('/profile');
      }
    } catch (e) {
      if (mounted) {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await auth0.credentials.user();
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await auth0.webAuth.logout(
        returnTo: '${auth0.domain.replaceAll('.', '-').replaceAll(':', '-')}://callback',
      );
    } on WebAuthException {
      // Ignore cancellation
    }
    await auth0.credentials.clearCredentials();
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _refreshToken() async {
    try {
      await auth0.credentials.renewCredentials();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token refreshed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refresh failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshToken,
            tooltip: 'Refresh Token',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Log Out',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_user?.pictureUrl != null)
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(_user!.pictureUrl!),
              ),
            const SizedBox(height: 16),
            Text(
              _user?.name ?? 'Unknown',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _user?.email ?? '',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
