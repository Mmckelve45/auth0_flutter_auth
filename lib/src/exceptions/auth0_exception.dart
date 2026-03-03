abstract class Auth0Exception implements Exception {
  final String message;
  final dynamic cause;

  Auth0Exception(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}
