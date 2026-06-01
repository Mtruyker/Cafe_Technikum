enum ApiErrorKind { network, timeout, server, client, unknown }

class ApiException implements Exception {
  const ApiException(this.message, {this.kind = ApiErrorKind.unknown});

  final String message;
  final ApiErrorKind kind;

  bool get isRetryable =>
      kind == ApiErrorKind.network ||
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.server;

  @override
  String toString() => message;
}
