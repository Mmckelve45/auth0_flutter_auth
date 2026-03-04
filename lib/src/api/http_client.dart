import 'dart:convert';
import 'package:http/http.dart' as http;
import '../exceptions/api_exception.dart';

class Auth0HttpClient {
  final String domain;
  final String clientId;
  final http.Client _httpClient;
  final Duration _timeout;

  late final Uri _baseUrl;

  Auth0HttpClient({
    required this.domain,
    required this.clientId,
    http.Client? httpClient,
    Duration? timeout,
  })  : _httpClient = httpClient ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 10) {
    _baseUrl = Uri.https(domain);
  }

  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Auth0-Client': _userAgent,
      };

  String get _userAgent {
    return base64Encode(utf8.encode(
      '{"name":"auth0_flutter_auth","version":"0.1.0"}',
    ));
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? extraHeaders,
  }) async {
    final url = _baseUrl.replace(path: path);
    try {
      final response = await _httpClient
          .post(
            url,
            headers: {..._defaultHeaders, ...?extraHeaders},
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.networkError(e);
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? extraHeaders,
  }) async {
    final url = _baseUrl.replace(path: path);
    try {
      final response = await _httpClient
          .get(
            url,
            headers: {
              ..._defaultHeaders,
              ...?extraHeaders,
            }..remove('Content-Type'),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException.networkError(e);
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final Map<String, dynamic> json;

    if (response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {};
      }
      throw ApiException(
        message: 'Empty response with status ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // Some Auth0 endpoints (e.g. /dbconnections/change_password) return
      // plain text on success. Treat non-JSON 2xx as an empty success.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {};
      }
      throw ApiException(
        message: 'Invalid JSON response',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    throw ApiException.fromResponse(response.statusCode, json);
  }

  void close() {
    _httpClient.close();
  }
}
