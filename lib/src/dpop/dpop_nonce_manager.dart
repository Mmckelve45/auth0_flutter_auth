class DPoPNonceManager {
  final Map<String, String> _nonces = {};

  /// Updates the nonce for a given server (extracted from DPoP-Nonce header).
  void updateNonce(String server, String nonce) {
    _nonces[server] = nonce;
  }

  /// Updates nonce from any source (convenience for single-server use).
  void update(String? nonce) {
    if (nonce != null) {
      _nonces['default'] = nonce;
    }
  }

  /// Gets the current nonce for a given URL.
  String? getNonce(String url) {
    final uri = Uri.parse(url);
    return _nonces[uri.host] ?? _nonces['default'];
  }

  void clear() {
    _nonces.clear();
  }
}
