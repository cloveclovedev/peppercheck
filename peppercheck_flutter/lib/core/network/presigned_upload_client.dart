import 'package:dio/dio.dart';

/// Uploads avatar bytes directly to Cloudflare R2 via a presigned URL. This is
/// a bare Dio instance separate from [ApiClient]: no Firebase bearer, no API
/// interceptors, and the [uploadUrl] (its query string is a credential) is
/// never logged.
class PresignedUploadClient {
  PresignedUploadClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              // We validate status ourselves and map non-2xx to UploadFailed.
              validateStatus: (_) => true,
            ),
          ) {
    if (dio != null) {
      _dio.options
        ..connectTimeout ??= const Duration(seconds: 10)
        ..sendTimeout ??= const Duration(seconds: 30)
        ..receiveTimeout ??= const Duration(seconds: 30)
        ..validateStatus = (_) => true;
    }
  }

  final Dio _dio;

  /// PUTs [bytes] to [uploadUrl] with the given [contentType]. Throws
  /// [UploadFailed] on any non-2xx response or transport failure.
  Future<void> put({
    required String uploadUrl,
    required List<int> bytes,
    required String contentType,
  }) async {
    final Response<dynamic> res;
    try {
      res = await _dio.putUri<dynamic>(
        Uri.parse(uploadUrl),
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            Headers.contentTypeHeader: contentType,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );
    } on DioException catch (e) {
      throw UploadFailed(statusCode: e.response?.statusCode);
    }
    final status = res.statusCode;
    if (status == null || status < 200 || status >= 300) {
      throw UploadFailed(statusCode: status);
    }
  }
}

/// Thrown by [PresignedUploadClient.put] on a non-2xx response or transport
/// failure. Deliberately not an [ApiException]: this client never touches the
/// server error envelope.
class UploadFailed implements Exception {
  const UploadFailed({this.statusCode});

  final int? statusCode;

  @override
  String toString() => 'UploadFailed(statusCode: $statusCode)';
}
