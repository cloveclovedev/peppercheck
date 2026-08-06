import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/core/network/presigned_upload_client.dart';

/// Records the last request and returns a scripted response, mirroring the
/// `_FakeAdapter` used in `api_client_test.dart`.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }
}

ResponseBody _empty(int status) => ResponseBody.fromString('', status);

PresignedUploadClient _client(_FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return PresignedUploadClient(dio: dio);
}

void main() {
  test(
    'put issues a PUT to the exact uploadUrl with content headers and no Authorization',
    () async {
      final adapter = _FakeAdapter((o) => _empty(200));
      final client = _client(adapter);
      final bytes = List<int>.generate(10, (i) => i);
      const uploadUrl =
          'https://r2.example.com/bucket/key?X-Amz-Signature=secret';

      await client.put(
        uploadUrl: uploadUrl,
        bytes: bytes,
        contentType: 'image/jpeg',
      );

      final req = adapter.requests.single;
      expect(req.method, 'PUT');
      expect(req.uri.toString(), uploadUrl);
      expect(req.headers[Headers.contentTypeHeader], 'image/jpeg');
      expect(req.headers[Headers.contentLengthHeader], bytes.length);
      expect(req.headers.containsKey('Authorization'), isFalse);
    },
  );

  test('put succeeds on a 204 response', () async {
    final adapter = _FakeAdapter((o) => _empty(204));
    final client = _client(adapter);

    await client.put(
      uploadUrl: 'https://r2.example.com/bucket/key',
      bytes: [1, 2, 3],
      contentType: 'image/jpeg',
    );
  });

  test('throws UploadFailed on a non-2xx response', () async {
    final adapter = _FakeAdapter((o) => _empty(500));
    final client = _client(adapter);

    await expectLater(
      () => client.put(
        uploadUrl: 'https://r2.example.com/bucket/key',
        bytes: [1, 2, 3],
        contentType: 'image/jpeg',
      ),
      throwsA(isA<UploadFailed>()),
    );
  });

  test('throws UploadFailed on a transport failure', () async {
    final adapter = _FakeAdapter(
      (o) => throw DioException.connectionTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: o,
      ),
    );
    final client = _client(adapter);

    await expectLater(
      () => client.put(
        uploadUrl: 'https://r2.example.com/bucket/key',
        bytes: [1, 2, 3],
        contentType: 'image/jpeg',
      ),
      throwsA(isA<UploadFailed>()),
    );
  });
}
