import 'package:flutter/services.dart';
import '../exceptions/web_auth_exception.dart';

class BrowserPlatform {
  static const _channel = MethodChannel('com.auth0.flutter_auth/browser');

  /// Launches the system browser for authentication.
  /// Returns the callback URL string containing the authorization code.
  Future<String> launchAuth({
    required String url,
    required String callbackScheme,
    bool preferEphemeral = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('launchAuth', {
        'url': url,
        'callbackScheme': callbackScheme,
        'preferEphemeral': preferEphemeral,
      });

      if (result == null) {
        throw WebAuthException.noCallbackUrl();
      }

      return result;
    } on PlatformException catch (e) {
      if (e.code == 'USER_CANCELLED' || e.code == 'CANCELLED') {
        throw WebAuthException.cancelled();
      }
      throw WebAuthException.unknown(cause: e);
    }
  }

  /// Cancels any in-progress authentication session (iOS only).
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException {
      // Ignore — cancel is best-effort
    }
  }
}
