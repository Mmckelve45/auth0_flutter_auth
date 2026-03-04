import 'package:flutter/services.dart';
import '../exceptions/passkey_exception.dart';

class PasskeysPlatform {
  static const _channel = MethodChannel('com.auth0.flutter_auth/passkeys');

  Future<String> register(String optionsJson) async {
    try {
      final result =
          await _channel.invokeMethod<String>('register', {'optionsJson': optionsJson});

      if (result == null) {
        throw PasskeyException.registrationFailed();
      }

      return result;
    } on PlatformException catch (e) {
      throw _mapException(e, isRegistration: true);
    }
  }

  Future<String> authenticate(String optionsJson) async {
    try {
      final result = await _channel
          .invokeMethod<String>('authenticate', {'optionsJson': optionsJson});

      if (result == null) {
        throw PasskeyException.assertionFailed();
      }

      return result;
    } on PlatformException catch (e) {
      throw _mapException(e, isRegistration: false);
    }
  }

  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  PasskeyException _mapException(PlatformException e,
      {required bool isRegistration}) {
    switch (e.code) {
      case 'CANCELLED':
        return PasskeyException.cancelled(cause: e);
      case 'NOT_AVAILABLE':
        return PasskeyException.notAvailable(cause: e);
      default:
        if (isRegistration) {
          return PasskeyException.registrationFailed(cause: e);
        }
        return PasskeyException.assertionFailed(cause: e);
    }
  }
}
