import 'dart:math';

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'id_token_provider.dart';

/// The single configured HTTP client for the Go API. Features must not build
/// their own Dio. Responsibilities: base URL by build env, bearer-token
/// injection (via [IdTokenProvider], not a direct Firebase call), request-id
/// propagation, bounded timeouts, and mapping the server error envelope to a
/// stable [ApiException]. Non-idempotent mutations are never auto-retried.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required IdTokenProvider idTokenProvider,
    Dio? dio,
  }) : _idTokenProvider = idTokenProvider,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 10),
               sendTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(seconds: 20),
               // We handle status validation ourselves so the interceptor can
               // observe 401s; never throw on non-2xx here.
               validateStatus: (_) => true,
             ),
           ) {
    if (dio != null) {
      _dio.options
        ..baseUrl = baseUrl
        ..connectTimeout ??= const Duration(seconds: 10)
        ..receiveTimeout ??= const Duration(seconds: 20)
        ..sendTimeout ??= const Duration(seconds: 20)
        ..validateStatus = (_) => true;
    }
  }

  final Dio _dio;
  final IdTokenProvider _idTokenProvider;

  static const _requestIdHeader = 'X-Request-Id';
  final _rng = Random();

  String _newRequestId() {
    // 16 hex chars is enough to correlate a client call with a server log line.
    final bytes = List<int>.generate(8, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// GET [path] and decode a JSON object. On 401 for this idempotent GET, the
  /// token is force-refreshed and the request retried exactly once.
  Future<Map<String, dynamic>> getJson(
    String path, {
    bool authenticated = true,
  }) async {
    Response<dynamic> res;
    try {
      res = await _send(
        path,
        authenticated: authenticated,
        forceRefresh: false,
      );
      if (res.statusCode == 401 && authenticated) {
        res = await _send(
          path,
          authenticated: authenticated,
          forceRefresh: true,
        );
      }
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
    if (res.statusCode != null &&
        res.statusCode! >= 200 &&
        res.statusCode! < 300) {
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{};
    }
    throw _mapErrorResponse(res);
  }

  Future<Response<dynamic>> _send(
    String path, {
    required bool authenticated,
    required bool forceRefresh,
  }) async {
    final headers = <String, dynamic>{_requestIdHeader: _newRequestId()};
    if (authenticated) {
      final token = await _idTokenProvider(forceRefresh: forceRefresh);
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return _dio.get<dynamic>(path, options: Options(headers: headers));
  }

  ApiException _mapErrorResponse(Response<dynamic> res) {
    final status = res.statusCode;
    final data = res.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        code: (err['code'] as String?) ?? 'unknown',
        message: (err['message'] as String?) ?? 'request failed',
        requestId: err['requestId'] as String?,
        statusCode: status,
      );
    }
    return ApiException(
      code: 'unknown',
      message: 'request failed',
      statusCode: status,
    );
  }

  ApiException _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException.timeout();
      case DioExceptionType.connectionError:
        return const ApiException.network();
      case DioExceptionType.badResponse:
        if (e.response != null) return _mapErrorResponse(e.response!);
        return const ApiException.network();
      default:
        return const ApiException.network();
    }
  }
}
