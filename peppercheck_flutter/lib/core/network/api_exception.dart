/// A stable, provider-neutral error surfaced by [ApiClient]. Dio and Firebase
/// exceptions are mapped to this at the network boundary and never reach the
/// domain or UI layers directly.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.requestId,
    this.statusCode,
  });

  /// A transport failure (no HTTP response received).
  const ApiException.network()
    : code = 'network',
      message = 'network error',
      requestId = null,
      statusCode = null;

  /// A connect/receive/send timeout.
  const ApiException.timeout()
    : code = 'timeout',
      message = 'request timed out',
      requestId = null,
      statusCode = null;

  /// The authentication provider could not supply an ID token.
  const ApiException.tokenUnavailable()
    : code = 'token_unavailable',
      message = 'authentication token unavailable',
      requestId = null,
      statusCode = null;

  /// Stable machine-readable code (server envelope `error.code`, or
  /// `network`/`timeout`/`token_unavailable`/`unknown` for client-side
  /// failures).
  final String code;

  /// Human-readable detail. Not for control flow — branch on [code].
  final String message;

  /// Correlates with the server log line (`X-Request-Id`), when available.
  final String? requestId;

  /// HTTP status when a response was received; null for transport failures.
  final int? statusCode;

  @override
  String toString() =>
      'ApiException(code: $code, status: $statusCode, requestId: $requestId, message: $message)';
}
