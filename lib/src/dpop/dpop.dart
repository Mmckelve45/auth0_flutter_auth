import 'dpop_platform.dart';
import 'dpop_nonce_manager.dart';
import '../exceptions/dpop_exception.dart';

class DPoP {
  final DPoPPlatform _platform;
  final DPoPNonceManager _nonceManager;
  bool _initialized = false;

  DPoP({DPoPPlatform? platform})
      : _platform = platform ?? DPoPPlatform(),
        _nonceManager = DPoPNonceManager();

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await _platform.generateKeyPair();
    _initialized = true;
  }

  Future<Map<String, String>> generateHeaders({
    required String url,
    required String method,
    String? accessToken,
  }) async {
    if (!_initialized) {
      throw DPoPException.notInitialized();
    }

    final nonce = _nonceManager.getNonce(url);

    final proof = await _platform.signProof(
      url: url,
      method: method,
      accessToken: accessToken,
      nonce: nonce,
    );

    return {'DPoP': proof};
  }

  void updateNonce(String? nonce) {
    _nonceManager.update(nonce);
  }

  void updateNonceForServer(String server, String nonce) {
    _nonceManager.updateNonce(server, nonce);
  }

  Future<void> clear() async {
    await _platform.clearKeyPair();
    _nonceManager.clear();
    _initialized = false;
  }
}
