import 'package:flutter/services.dart';
import '../exceptions/dpop_exception.dart';

class DPoPPlatform {
  static const _channel = MethodChannel('com.auth0.flutter_auth/dpop');

  Future<void> generateKeyPair() async {
    try {
      await _channel.invokeMethod<void>('generateKeyPair');
    } on PlatformException catch (e) {
      throw DPoPException.keyGenerationFailed(cause: e);
    }
  }

  Future<String> signProof({
    required String url,
    required String method,
    String? accessToken,
    String? nonce,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('signProof', {
        'url': url,
        'method': method,
        if (accessToken != null) 'accessToken': accessToken,
        if (nonce != null) 'nonce': nonce,
      });

      if (result == null) {
        throw DPoPException.signingFailed();
      }

      return result;
    } on PlatformException catch (e) {
      throw DPoPException.signingFailed(cause: e);
    }
  }

  Future<void> clearKeyPair() async {
    try {
      await _channel.invokeMethod<void>('clearKeyPair');
    } on PlatformException catch (e) {
      throw DPoPException.platformError('Failed to clear key pair', cause: e);
    }
  }

  Future<bool> hasKeyPair() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasKeyPair');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
