import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:auth0_flutter_auth/auth0_flutter_auth.dart';
import '../main.dart';
import '../widgets/result_box.dart';

void _log(String message) {
  debugPrint('[Auth0Example] $message');
}

// ---------------------------------------------------------------------------
// Home screen — tabbed login explorer
// ---------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auth0 Flutter Auth'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Universal Login'),
            Tab(text: 'Password'),
            Tab(text: 'Email Code'),
            Tab(text: 'SMS Code'),
            Tab(text: 'Passkeys'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _UniversalLoginTab(),
                _PasswordLoginTab(),
                _EmailPasswordlessTab(),
                _SmsPasswordlessTab(),
                _PasskeysTab(),
              ],
            ),
          ),
          const _DPoPInfoCard(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Stores credentials and lets the auth-state stream handle navigation.
Future<void> _storeAndNavigate(Credentials credentials) async {
  await auth0.credentials.storeCredentials(credentials);
  // No manual navigation needed — storeCredentials() emits on the stream,
  // AuthState picks it up, GoRouter redirect sends user to /dashboard.
}

/// Shows the MFA challenge → verify OTP dialog. Returns credentials on
/// success, or null if cancelled.
Future<Credentials?> _handleMfaFlow(
  BuildContext context,
  ApiException mfaError,
) async {
  final mfaToken = mfaError.mfaToken;
  if (mfaToken == null) return null;

  return showDialog<Credentials>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MfaDialog(mfaToken: mfaToken),
  );
}

// ---------------------------------------------------------------------------
// Callout widget — info / warning banners
// ---------------------------------------------------------------------------

class _Callout extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String body;
  final Color? background;

  const _Callout({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.body,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor ?? theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1 — Universal Login (Redirect / PKCE)
// ---------------------------------------------------------------------------

class _UniversalLoginTab extends StatefulWidget {
  const _UniversalLoginTab();

  @override
  State<_UniversalLoginTab> createState() => _UniversalLoginTabState();
}

class _UniversalLoginTabState extends State<_UniversalLoginTab>
    with AutomaticKeepAliveClientMixin {
  bool _loading = false;
  String? _result;
  bool _isError = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _result = null;
      _isError = false;
    });

    final scheme = dotenv.env['AUTH0_MOBILE_CALLBACK_SCHEME']!;
    final callbackUrl = '$scheme:/callback';
    _log('Universal Login starting — callback: $callbackUrl');

    try {
      final credentials = await auth0.webAuth.login(
        redirectUrl: callbackUrl,
        audience: 'https://${dotenv.env['AUTH0_DOMAIN']}/api/v2/',
        scopes: {'openid', 'profile', 'email', 'offline_access'},
      );

      _log('Universal Login success');
      await _storeAndNavigate(credentials);
    } on WebAuthException catch (e) {
      _log('WebAuthException: code=${e.code}, message=${e.message}');
      if (!e.isCancelled) {
        setState(() {
          _result = '${e.message}\n\nCode: ${e.code}';
          _isError = true;
        });
      }
    } on ApiException catch (e) {
      _log('ApiException: ${e.errorCode} - ${e.message}');
      setState(() {
        _result = '${e.message}\n\nCode: ${e.errorCode}';
        _isError = true;
      });
    } catch (e) {
      _log('Unexpected error: $e');
      setState(() {
        _result = e.toString();
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _Callout(
          icon: Icons.open_in_browser,
          title: 'Recommended approach',
          body: 'Universal Login opens Auth0\'s hosted login page in a secure '
              'system browser. It supports all connection types, Adaptive MFA, '
              'anomaly detection, and bot protection out of the box — no extra '
              'configuration needed. This is the approach Auth0 recommends for '
              'most applications.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('webAuth.login()',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontFamily: 'monospace', fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  'PKCE flow: generate code verifier → open browser → '
                  'user authenticates → exchange authorization code for tokens.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'final creds = await auth0.webAuth.login(\n'
                    '  redirectUrl: \'\$scheme:/callback\',\n'
                    '  audience: \'https://my-api/\',\n'
                    '  scopes: {\'openid\', \'profile\', \'email\',\n'
                    '           \'offline_access\'},\n'
                    ');\n'
                    'await auth0.credentials.storeCredentials(creds);',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _login,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login),
                    label: const Text('Log In with Universal Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 8),
          ResultBox(text: _result!, isError: _isError),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2 — Password Login (Resource Owner)
// ---------------------------------------------------------------------------

class _PasswordLoginTab extends StatefulWidget {
  const _PasswordLoginTab();

  @override
  State<_PasswordLoginTab> createState() => _PasswordLoginTabState();
}

class _PasswordLoginTabState extends State<_PasswordLoginTab>
    with AutomaticKeepAliveClientMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _realmCtrl =
      TextEditingController(text: 'Username-Password-Authentication');
  bool _enforceMfa = false;
  bool _loading = false;
  String? _result;
  bool _isError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _realmCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.trim().isEmpty) {
      setState(() {
        _result = 'Email and password are required.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
      _isError = false;
    });

    try {
      final credentials = await auth0.api.loginWithPassword(
        usernameOrEmail: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        realm: _realmCtrl.text.trim(),
        audience: 'https://${dotenv.env['AUTH0_DOMAIN']}/api/v2/',
        scopes: {'openid', 'profile', 'email', 'offline_access'},
      );

      _log('Password login success');
      await _storeAndNavigate(credentials);
    } on ApiException catch (e) {
      if (e.isMultifactorRequired && _enforceMfa && mounted) {
        _log('MFA required — mfaToken: ${e.mfaToken}');
        setState(() => _loading = false);
        final creds = await _handleMfaFlow(context, e);
        if (creds != null) {
          await _storeAndNavigate(creds);
        } else {
          setState(() {
            _result = 'MFA cancelled.';
            _isError = true;
          });
        }
        return;
      }
      _log('ApiException: ${e.errorCode} - ${e.message}');
      setState(() {
        _result = '${e.message}\n\nCode: ${e.errorCode}';
        _isError = true;
      });
    } catch (e) {
      _log('Unexpected error: $e');
      setState(() {
        _result = e.toString();
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Callout(
          icon: Icons.warning_amber_rounded,
          iconColor: theme.colorScheme.error,
          title: 'Password grant must be enabled',
          body: 'This uses the Resource Owner Password grant which is '
              'disabled by default. To enable it:\n\n'
              'Auth0 Dashboard → Applications → your app → Settings → '
              'Advanced Settings → Grant Types → check "Password".\n\n'
              'Note: Auth0 recommends Universal Login (redirect) instead. '
              'The password grant does not support Anomaly Detection, '
              'bot protection, or Adaptive MFA policies.',
          background: theme.colorScheme.errorContainer.withAlpha(50),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('api.loginWithPassword()',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontFamily: 'monospace', fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  'POST /oauth/token with grant_type password-realm. '
                  'Sends credentials directly to Auth0 without a browser.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _realmCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Realm (connection)',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.dns_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                _MfaToggle(
                  value: _enforceMfa,
                  onChanged: (v) => setState(() => _enforceMfa = v),
                ),
                const SizedBox(height: 12),
                Center(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _login,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login),
                    label: const Text('Log In with Password'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 8),
          ResultBox(text: _result!, isError: _isError),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3 — Email Passwordless
// ---------------------------------------------------------------------------

class _EmailPasswordlessTab extends StatefulWidget {
  const _EmailPasswordlessTab();

  @override
  State<_EmailPasswordlessTab> createState() => _EmailPasswordlessTabState();
}

class _EmailPasswordlessTabState extends State<_EmailPasswordlessTab>
    with AutomaticKeepAliveClientMixin {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _enforceMfa = false;
  bool _codeSent = false;
  bool _loading = false;
  String? _result;
  bool _isError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() {
        _result = 'Email is required.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
      _isError = false;
    });

    try {
      await auth0.api.startPasswordlessEmail(email: _emailCtrl.text.trim());
      _log('Passwordless email sent to ${_emailCtrl.text.trim()}');
      setState(() {
        _codeSent = true;
        _result = 'Code sent to ${_emailCtrl.text.trim()}';
        _isError = false;
      });
    } catch (e) {
      _log('Error sending email code: $e');
      setState(() {
        _result = e.toString();
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() {
        _result = 'Enter the code from your email.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
      _isError = false;
    });

    try {
      final credentials = await auth0.api.loginWithEmailCode(
        email: _emailCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        audience: 'https://${dotenv.env['AUTH0_DOMAIN']}/api/v2/',
        scopes: {'openid', 'profile', 'email', 'offline_access'},
      );

      _log('Email passwordless login success');
      await _storeAndNavigate(credentials);
    } on ApiException catch (e) {
      if (e.isMultifactorRequired && _enforceMfa && mounted) {
        _log('MFA required — mfaToken: ${e.mfaToken}');
        setState(() => _loading = false);
        final creds = await _handleMfaFlow(context, e);
        if (creds != null) {
          await _storeAndNavigate(creds);
        } else {
          setState(() {
            _result = 'MFA cancelled.';
            _isError = true;
          });
        }
        return;
      }
      _log('ApiException: ${e.errorCode} - ${e.message}');
      setState(() {
        _result = '${e.message}\n\nCode: ${e.errorCode}';
        _isError = true;
      });
    } catch (e) {
      _log('Unexpected error: $e');
      setState(() {
        _result = e.toString();
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Callout(
          icon: Icons.warning_amber_rounded,
          iconColor: theme.colorScheme.tertiary,
          title: 'Email passwordless must be enabled',
          body: 'This requires the Email passwordless connection to be '
              'configured:\n\n'
              'Auth0 Dashboard → Authentication → Passwordless → '
              'Email → toggle ON.\n\n'
              'Then enable it for your app: Applications → your app → '
              'Connections → toggle "Email" under Passwordless.',
          background: theme.colorScheme.tertiaryContainer.withAlpha(50),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _codeSent
                        ? 'Step 2 — api.loginWithEmailCode()'
                        : 'Step 1 — api.startPasswordlessEmail()',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontFamily: 'monospace', fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  _codeSent
                      ? 'POST /oauth/token with the OTP code from your email.'
                      : 'POST /passwordless/start — sends a one-time code to '
                          'the user\'s email address.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  enabled: !_codeSent,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'One-time code',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin_outlined, size: 20),
                    ),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                  ),
                ],
                const SizedBox(height: 12),
                _MfaToggle(
                  value: _enforceMfa,
                  onChanged: (v) => setState(() => _enforceMfa = v),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_codeSent)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                    _codeSent = false;
                                    _codeCtrl.clear();
                                    _result = null;
                                  }),
                          child: const Text('Back'),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed:
                          _loading ? null : (_codeSent ? _verifyCode : _sendCode),
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_codeSent ? Icons.check : Icons.send),
                      label: Text(_codeSent ? 'Verify Code' : 'Send Code'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 8),
          ResultBox(text: _result!, isError: _isError),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 4 — SMS Passwordless
// ---------------------------------------------------------------------------

class _SmsPasswordlessTab extends StatefulWidget {
  const _SmsPasswordlessTab();

  @override
  State<_SmsPasswordlessTab> createState() => _SmsPasswordlessTabState();
}

class _SmsPasswordlessTabState extends State<_SmsPasswordlessTab>
    with AutomaticKeepAliveClientMixin {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _enforceMfa = false;
  bool _codeSent = false;
  bool _loading = false;
  String? _result;
  bool _isError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() {
        _result = 'Phone number is required.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
      _isError = false;
    });

    try {
      await auth0.api.startPasswordlessSms(
          phoneNumber: _phoneCtrl.text.trim());
      _log('SMS sent to ${_phoneCtrl.text.trim()}');
      setState(() {
        _codeSent = true;
        _result = 'Code sent to ${_phoneCtrl.text.trim()}';
        _isError = false;
      });
    } catch (e) {
      _log('Error sending SMS: $e');
      setState(() {
        _result = e.toString();
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() {
        _result = 'Enter the code from your SMS.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
      _isError = false;
    });

    try {
      final credentials = await auth0.api.loginWithSmsCode(
        phoneNumber: _phoneCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        audience: 'https://${dotenv.env['AUTH0_DOMAIN']}/api/v2/',
        scopes: {'openid', 'profile', 'email', 'offline_access'},
      );

      _log('SMS passwordless login success');
      await _storeAndNavigate(credentials);
    } on ApiException catch (e) {
      if (e.isMultifactorRequired && _enforceMfa && mounted) {
        _log('MFA required — mfaToken: ${e.mfaToken}');
        setState(() => _loading = false);
        final creds = await _handleMfaFlow(context, e);
        if (creds != null) {
          await _storeAndNavigate(creds);
        } else {
          setState(() {
            _result = 'MFA cancelled.';
            _isError = true;
          });
        }
        return;
      }
      _log('ApiException: ${e.errorCode} - ${e.message}');
      setState(() {
        _result = '${e.message}\n\nCode: ${e.errorCode}';
        _isError = true;
      });
    } catch (e) {
      _log('Unexpected error: $e');
      setState(() {
        _result = e.toString();
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Callout(
          icon: Icons.warning_amber_rounded,
          iconColor: theme.colorScheme.tertiary,
          title: 'SMS passwordless must be enabled',
          body: 'This requires the SMS passwordless connection plus a Twilio '
              'account:\n\n'
              'Auth0 Dashboard → Authentication → Passwordless → '
              'SMS → toggle ON → configure Twilio SID, token, and '
              'sender number.\n\n'
              'Then enable it for your app: Applications → your app → '
              'Connections → toggle "SMS" under Passwordless.',
          background: theme.colorScheme.tertiaryContainer.withAlpha(50),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _codeSent
                        ? 'Step 2 — api.loginWithSmsCode()'
                        : 'Step 1 — api.startPasswordlessSms()',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontFamily: 'monospace', fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  _codeSent
                      ? 'POST /oauth/token with the OTP code from your SMS.'
                      : 'POST /passwordless/start — sends a one-time code via '
                          'SMS to the user\'s phone.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  enabled: !_codeSent,
                  decoration: const InputDecoration(
                    labelText: 'Phone number (e.g. +15551234567)',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'One-time code',
                      isDense: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin_outlined, size: 20),
                    ),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                  ),
                ],
                const SizedBox(height: 12),
                _MfaToggle(
                  value: _enforceMfa,
                  onChanged: (v) => setState(() => _enforceMfa = v),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_codeSent)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                    _codeSent = false;
                                    _codeCtrl.clear();
                                    _result = null;
                                  }),
                          child: const Text('Back'),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed:
                          _loading ? null : (_codeSent ? _verifyCode : _sendCode),
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_codeSent ? Icons.check : Icons.send),
                      label: Text(_codeSent ? 'Verify Code' : 'Send Code'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 8),
          ResultBox(text: _result!, isError: _isError),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 5 — Passkeys (Limited Early Access)
// ---------------------------------------------------------------------------

class _PasskeysTab extends StatefulWidget {
  const _PasskeysTab();

  @override
  State<_PasskeysTab> createState() => _PasskeysTabState();
}

class _PasskeysTabState extends State<_PasskeysTab>
    with AutomaticKeepAliveClientMixin {
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _result;
  bool _isError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() {
        _result = 'Email is required.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
      _isError = false;
    });

    try {
      final passkeys = auth0.passkeys;
      if (passkeys == null) {
        setState(() {
          _result = 'Passkeys not enabled. Set enablePasskeys: true in Auth0ClientOptions.';
          _isError = true;
        });
        return;
      }

      final credentials = await passkeys.signup(
        email: _emailCtrl.text.trim(),
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        audience: 'https://${dotenv.env['AUTH0_DOMAIN']}/api/v2/',
        scopes: {'openid', 'profile', 'email', 'offline_access'},
      );

      _log('Passkey signup success');
      await _storeAndNavigate(credentials);
    } on PasskeyException catch (e) {
      _log('PasskeyException: code=${e.code}, message=${e.message}');
      if (!e.isCancelled) {
        setState(() {
          _result = '${e.message}\n\nCode: ${e.code}';
          _isError = true;
        });
      }
    } on ApiException catch (e) {
      _log('ApiException: ${e.errorCode} - ${e.message}');
      setState(() {
        _result = '${e.message}\n\nCode: ${e.errorCode}';
        _isError = true;
      });
    } catch (e) {
      _log('Unexpected error: $e');
      setState(() {
        _result = e.toString();
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _result = null;
      _isError = false;
    });

    try {
      final passkeys = auth0.passkeys;
      if (passkeys == null) {
        setState(() {
          _result = 'Passkeys not enabled. Set enablePasskeys: true in Auth0ClientOptions.';
          _isError = true;
        });
        return;
      }

      final credentials = await passkeys.login(
        audience: 'https://${dotenv.env['AUTH0_DOMAIN']}/api/v2/',
        scopes: {'openid', 'profile', 'email', 'offline_access'},
      );

      _log('Passkey login success');
      await _storeAndNavigate(credentials);
    } on PasskeyException catch (e) {
      _log('PasskeyException: code=${e.code}, message=${e.message}');
      if (!e.isCancelled) {
        setState(() {
          _result = '${e.message}\n\nCode: ${e.code}';
          _isError = true;
        });
      }
    } on ApiException catch (e) {
      _log('ApiException: ${e.errorCode} - ${e.message}');
      setState(() {
        _result = '${e.message}\n\nCode: ${e.errorCode}';
        _isError = true;
      });
    } catch (e) {
      _log('Unexpected error: $e');
      setState(() {
        _result = e.toString();
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Callout(
          icon: Icons.warning_amber_rounded,
          iconColor: theme.colorScheme.error,
          title: 'Limited Early Access',
          body: 'Native Passkeys is a Limited Early Access feature — this API '
              'is subject to change and not recommended for production until GA.\n\n'
              'Enable: Auth0 Dashboard \u2192 Authentication \u2192 Database '
              '\u2192 your connection \u2192 Authentication Methods \u2192 '
              'Passkey \u2192 toggle ON.',
          background: theme.colorScheme.errorContainer.withAlpha(50),
        ),
        _Callout(
          icon: Icons.devices,
          iconColor: theme.colorScheme.tertiary,
          title: 'Platform requirements',
          body: 'iOS 16+ / macOS 13+ / Android API 28+.\n\n'
              'iOS/macOS: Add an Associated Domains entitlement '
              '(webcredentials:your-tenant.auth0.com).\n'
              'Android: Host a .well-known/assetlinks.json on your '
              'relying party domain.',
          background: theme.colorScheme.tertiaryContainer.withAlpha(50),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sign Up with Passkey',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Creates a new account and registers a platform passkey. '
                  'Calls /passkey/register \u2192 OS prompt \u2192 /oauth/token.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Display name (optional)',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _signup,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.fingerprint),
                    label: const Text('Sign Up with Passkey'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sign In with Passkey',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'No fields needed — the OS shows an account picker. '
                  'Calls /passkey/challenge \u2192 OS prompt \u2192 /oauth/token.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Center(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _login,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.fingerprint),
                    label: const Text('Sign In with Passkey'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_result != null) ...[
          const SizedBox(height: 8),
          ResultBox(text: _result!, isError: _isError),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// DPoP Info Card — collapsible footer
// ---------------------------------------------------------------------------

class _DPoPInfoCard extends StatefulWidget {
  const _DPoPInfoCard();

  @override
  State<_DPoPInfoCard> createState() => _DPoPInfoCardState();
}

class _DPoPInfoCardState extends State<_DPoPInfoCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(8),
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'DPoP is not a login method — it\'s a token-binding mechanism',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Text(
                  'DPoP (Demonstration of Proof-of-Possession) binds access '
                  'tokens to a device key pair (Secure Enclave / Android Keystore) '
                  'so stolen tokens can\'t be replayed.\n\n'
                  'Enable: Auth0ClientOptions(enableDPoP: true), then call '
                  'dpop.initialize() + dpop.generateHeaders() on API calls.\n\n'
                  'Use for: high-security APIs, financial services, anywhere '
                  'token replay is a concern.\n\n'
                  'See the API Explorer tab \u2192 DPoP section for hands-on testing.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MFA toggle + info
// ---------------------------------------------------------------------------

class _MfaToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MfaToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(!value),
                child: Text('Handle native MFA challenge',
                    style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
        ),
        if (value)
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 4),
            child: Text(
              'When the login returns mfa_required, the app will prompt '
              'for the TOTP code using getMfaChallenge() + verifyMfaOtp(). '
              'Requires MFA to be enabled:\n\n'
              'Auth0 Dashboard → Security → Multi-factor Auth → '
              'enable One-time Password.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// MFA Dialog — challenge + verify
// ---------------------------------------------------------------------------

class _MfaDialog extends StatefulWidget {
  final String mfaToken;

  const _MfaDialog({required this.mfaToken});

  @override
  State<_MfaDialog> createState() => _MfaDialogState();
}

class _MfaDialogState extends State<_MfaDialog> {
  final _otpCtrl = TextEditingController();
  String? _challengeInfo;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requestChallenge();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestChallenge() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final challenge = await auth0.api.getMfaChallenge(
        mfaToken: widget.mfaToken,
      );
      _log('MFA challenge: type=${challenge.challengeType}, '
          'binding=${challenge.bindingMethod}');
      setState(() {
        _challengeInfo = 'Challenge type: ${challenge.challengeType}\n'
            'Binding: ${challenge.bindingMethod ?? 'n/a'}';
      });
    } catch (e) {
      _log('MFA challenge error: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter your OTP code.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credentials = await auth0.api.verifyMfaOtp(
        mfaToken: widget.mfaToken,
        otp: _otpCtrl.text.trim(),
      );
      _log('MFA verify success');
      if (mounted) Navigator.of(context).pop(credentials);
    } on ApiException catch (e) {
      _log('MFA verify error: ${e.errorCode}');
      setState(() {
        if (e.isMultifactorCodeInvalid) {
          _error = 'Invalid code. Check your authenticator app and try again.';
        } else if (e.isMultifactorTokenInvalid) {
          _error = 'MFA token expired. Close this dialog and log in again.';
        } else {
          _error = '${e.message}\n\nCode: ${e.errorCode}';
        }
      });
    } catch (e) {
      _log('MFA verify error: $e');
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Multi-Factor Authentication'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_challengeInfo != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_challengeInfo!,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12)),
              ),
              const SizedBox(height: 12),
            ],
            const Text('Enter the code from your authenticator app:'),
            const SizedBox(height: 10),
            TextField(
              controller: _otpCtrl,
              decoration: const InputDecoration(
                labelText: 'OTP Code',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.security, size: 20),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
              onSubmitted: (_) => _verifyOtp(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(
                      color: theme.colorScheme.error, fontSize: 13)),
            ],
            const SizedBox(height: 8),
            Text(
              'SDK calls:\n'
              '1. api.getMfaChallenge(mfaToken: ...)\n'
              '2. api.verifyMfaOtp(mfaToken: ..., otp: ...)',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _verifyOtp,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Verify'),
        ),
      ],
    );
  }
}
