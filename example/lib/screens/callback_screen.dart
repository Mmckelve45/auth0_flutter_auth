import 'package:flutter/material.dart';
import '../main.dart';

void _log(String message) {
  debugPrint('[Auth0Example] $message');
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
      // Stream auto-notifies via storeCredentials().
    } catch (e) {
      _log('Callback error: $e');
      // Stream auto-notifies via clearCredentials().
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
