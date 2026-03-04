/// # Auth0 Flutter Auth — Example App
///
/// ## Checking auth state
///
/// The SDK offers two approaches depending on your needs:
///
/// ### Stream (reactive) — `auth0.authStateChanges()`
///
/// Returns a `Stream<Credentials?>` that emits the current state immediately
/// on listen, then on every credential change. Works like Firebase's
/// `authStateChanges()` or Supabase's `onAuthStateChange`. The stream is
/// extremely lightweight — no polling, no timers, no network calls. It's just
/// an in-memory event listener that fires when `storeCredentials()` or
/// `clearCredentials()` is called.
///
/// ```dart
/// // GoRouter — wrap in a ChangeNotifier (see AuthState class below)
/// // StreamBuilder — StreamBuilder(stream: auth0.authStateChanges(), ...)
/// // Riverpod — StreamProvider((_) => auth0.authStateChanges())
/// // BLoC — listen in constructor, emit states
/// // Plain Navigator — listen and push/pop routes
/// ```
///
/// ### One-shot (imperative) — check once, no subscription
///
/// If you already use Firebase/Supabase for routing and just need to check
/// Auth0 credentials on startup or at a specific point:
///
/// ```dart
/// // Boolean check — "do I have valid tokens?"
/// final loggedIn = await auth0.credentials.hasValidCredentials();
///
/// // Get the actual credentials (auto-refreshes if expired, null if none)
/// final creds = await auth0.credentials.getCredentials();
/// if (creds != null) { /* authenticated */ }
/// ```
///
/// ## This example's approach
///
/// This app uses the **stream** approach with GoRouter:
///
/// 1. **[AuthState]** — A thin [ChangeNotifier] wrapper around
///    `auth0.authStateChanges()`. GoRouter listens to it via
///    [refreshListenable] and re-evaluates its [redirect] whenever the
///    stream emits (login, logout, or initial credential check).
///
/// 2. **GoRouter redirect** — Inspects [AuthState.isAuthenticated] on every
///    navigation event (including hot reloads). Authenticated → `/dashboard`,
///    unauthenticated → `/`, still loading → `/splash`.
///
/// 3. **Splash screen** — Shown while the stream's first emission is pending
///    (reading from secure storage). Prevents a flash of the login page.
///
/// No manual `authState.notifyLoggedIn()` calls are needed anywhere —
/// `storeCredentials()` and `clearCredentials()` automatically emit on the
/// stream, and the router reacts.

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/callback_screen.dart';
import 'screens/dashboard_screen.dart';

void _log(String message) {
  developer.log(message, name: 'auth0_example');
  debugPrint('[Auth0Example] $message');
}

late final Auth0Client auth0;
late final AuthState authState;

// ---------------------------------------------------------------------------
// Auth State — ChangeNotifier wrapper around auth0.authStateChanges()
//
// The SDK provides a framework-agnostic Stream<Credentials?> via
// auth0.authStateChanges(). This class adapts it to a ChangeNotifier so
// GoRouter can use it as refreshListenable. If you use Riverpod, BLoC,
// or StreamBuilder, you can skip this class and use the stream directly:
//
//   // Riverpod
//   final authProvider = StreamProvider((_) => auth0.authStateChanges());
//
//   // StreamBuilder
//   StreamBuilder<Credentials?>(
//     stream: auth0.authStateChanges(),
//     builder: (context, snapshot) { ... },
//   );
//
//   // Plain Navigator
//   auth0.authStateChanges().listen((creds) {
//     if (creds == null) navigator.pushReplacementNamed('/login');
//   });
// ---------------------------------------------------------------------------

class AuthState extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  late final StreamSubscription<Credentials?> _sub;

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;

  AuthState() {
    // authStateChanges() emits the current stored state first (like
    // Firebase), then emits on every storeCredentials / clearCredentials.
    _sub = auth0.authStateChanges().listen((credentials) {
      _isAuthenticated = credentials != null;
      _isInitialized = true;
      _log('AuthState: isAuthenticated=$_isAuthenticated');
      notifyListeners();
    }, onError: (e) {
      _log('AuthState stream error: $e');
      _isAuthenticated = false;
      _isInitialized = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// App entry point
// ---------------------------------------------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  auth0 = Auth0Client(
    domain: dotenv.env['AUTH0_DOMAIN']!,
    clientId: dotenv.env['AUTH0_CLIENT_ID']!,
    options: const Auth0ClientOptions(enablePasskeys: true),
  );

  // Create the auth state notifier. It will asynchronously check the
  // credential store and flip isAuthenticated + isInitialized.
  authState = AuthState();

  runApp(const MyApp());
}

// ---------------------------------------------------------------------------
// Router — redirect based on auth state
// ---------------------------------------------------------------------------

final _router = GoRouter(
  initialLocation: '/',

  // Re-evaluate redirect whenever authState notifies (login, logout, init).
  refreshListenable: authState,

  redirect: (context, state) {
    final path = state.uri.path;

    // While AuthState is still checking the credential store, show splash.
    if (!authState.isInitialized) {
      return path == '/splash' ? null : '/splash';
    }

    final loggedIn = authState.isAuthenticated;

    // Allow the callback route to handle itself (web redirect flow).
    if (path == '/callback') return null;

    // Not logged in → force to login page.
    if (!loggedIn) {
      return path == '/' ? null : '/';
    }

    // Logged in → don't show login or splash, go to dashboard.
    if (path == '/' || path == '/splash') {
      return '/dashboard';
    }

    return null; // no redirect
  },

  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/callback',
      builder: (context, state) => CallbackScreen(uri: state.uri),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
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
