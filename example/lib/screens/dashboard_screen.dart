import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';
import '../main.dart';
import '../tabs/profile_tab.dart';
import '../tabs/api_explorer_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;

  Future<void> _logout() async {
    try {
      await auth0.webAuth.logout(
        returnTo: '${dotenv.env['AUTH0_MOBILE_CALLBACK_SCHEME']}:/logout',
      );
    } on WebAuthException {
      // ignore cancellation
    }
    await auth0.credentials.clearCredentials();

    // No manual call needed — clearCredentials() emits null on the stream,
    // AuthState picks it up, GoRouter redirect sends user to /.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auth0 Flutter Auth'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Log Out',
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          ProfileTab(),
          ApiExplorerTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.api), label: 'API Explorer'),
        ],
      ),
    );
  }
}
