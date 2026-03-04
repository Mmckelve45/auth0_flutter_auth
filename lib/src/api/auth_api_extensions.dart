import '../dpop/dpop.dart';
import 'auth_api.dart';
import 'http_client.dart';

/// Extensions to add DPoP header generation to AuthApi requests.
/// When DPoP is enabled, the token_type returned will be 'DPoP' instead of 'Bearer'.
class DPoPAuthApi {
  final AuthApi _api;
  final Auth0HttpClient _client;
  final DPoP? _dpop;
  final String _clientId;

  DPoPAuthApi({
    required Auth0HttpClient client,
    required String clientId,
    DPoP? dpop,
  })  : _client = client,
        _clientId = clientId,
        _dpop = dpop,
        _api = AuthApi(client: client, clientId: clientId);

  /// Wraps a token request, injecting DPoP proof header if DPoP is enabled.
  Future<Map<String, String>> dpopHeaders(String url, String method) async {
    if (_dpop == null) return {};
    return _dpop.generateHeaders(url: url, method: method);
  }

  AuthApi get api => _api;
  Auth0HttpClient get client => _client;
  String get clientId => _clientId;

  DPoP? get dpop => _dpop;
}
