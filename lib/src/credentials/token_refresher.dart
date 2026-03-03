import 'dart:async';
import '../api/auth_api.dart';
import '../models/credentials.dart';
import '../exceptions/credential_store_exception.dart';

class TokenRefresher {
  final AuthApi _api;
  Completer<Credentials>? _inflightRefresh;

  TokenRefresher({required AuthApi api}) : _api = api;

  /// Refreshes the token. If a refresh is already in-flight, returns the same future.
  Future<Credentials> refresh({
    required String refreshToken,
    Set<String> scopes = const {},
    Map<String, String>? parameters,
  }) async {
    if (_inflightRefresh != null) {
      return _inflightRefresh!.future;
    }

    _inflightRefresh = Completer<Credentials>();
    // Ensure the completer's future doesn't produce an unhandled error
    _inflightRefresh!.future.ignore();

    try {
      final credentials = await _api.renewTokens(
        refreshToken: refreshToken,
        scopes: scopes,
        parameters: parameters,
      );

      // Preserve the refresh token if the server didn't return a new one
      final result = credentials.refreshToken != null
          ? credentials
          : Credentials(
              accessToken: credentials.accessToken,
              tokenType: credentials.tokenType,
              idToken: credentials.idToken,
              refreshToken: refreshToken,
              expiresAt: credentials.expiresAt,
              scopes: credentials.scopes,
            );

      _inflightRefresh!.complete(result);
      return result;
    } catch (e) {
      final error = e is CredentialStoreException
          ? e
          : CredentialStoreException.refreshFailed(cause: e);
      _inflightRefresh!.completeError(error);
      throw error;
    } finally {
      _inflightRefresh = null;
    }
  }
}
