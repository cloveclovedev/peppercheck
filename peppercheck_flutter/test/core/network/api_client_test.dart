import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/core/network/api_client.dart';
import 'package:peppercheck_flutter/core/network/api_exception.dart';

/// Records the last request and returns a scripted response. `handler` lets a
/// test vary the response by attempt (for the 401-retry case).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options, int attempt) handler;
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
    return handler(options, requests.length);
  }
}

ResponseBody _json(
  int status,
  Map<String, dynamic> body, {
  Map<String, List<String>>? headers,
}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      ...?headers,
    },
  );
}

ApiClient _client(
  _FakeAdapter adapter, {
  Future<String?> Function({required bool forceRefresh})? tokens,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
    ..httpClientAdapter = adapter;
  return ApiClient(
    baseUrl: 'http://test.local',
    idTokenProvider: tokens ?? ({required bool forceRefresh}) async => 'tok-1',
    dio: dio,
  );
}

void main() {
  test('attaches Authorization bearer on authenticated GET', () async {
    final adapter = _FakeAdapter((o, _) => _json(200, {'ok': true}));
    final client = _client(adapter);

    await client.getJson('/api/v1/me');

    expect(adapter.requests.single.headers['Authorization'], 'Bearer tok-1');
  });

  test('attaches an X-Request-Id header', () async {
    final adapter = _FakeAdapter((o, _) => _json(200, {'ok': true}));
    final client = _client(adapter);

    await client.getJson('/api/v1/me');

    final reqId = adapter.requests.single.headers['X-Request-Id'];
    expect(reqId, isNotNull);
    expect((reqId as String).isNotEmpty, isTrue);
  });

  test('maps the server error envelope to ApiException', () async {
    final adapter = _FakeAdapter(
      (o, _) => _json(401, {
        'error': {
          'code': 'unauthenticated',
          'message': 'no token',
          'requestId': 'req-9',
        },
      }),
    );
    final client = _client(adapter);

    expect(
      () => client.getJson('/api/v1/me'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'unauthenticated')
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.requestId, 'requestId', 'req-9'),
      ),
    );
  });

  test('on 401 refreshes the token and retries the GET exactly once', () async {
    var forced = <bool>[];
    final adapter = _FakeAdapter((o, attempt) {
      if (attempt == 1) {
        return _json(401, {
          'error': {
            'code': 'unauthenticated',
            'message': 'expired',
            'requestId': 'r',
          },
        });
      }
      return _json(200, {
        'user': {'id': 'u1'},
      });
    });
    final client = _client(
      adapter,
      tokens: ({required bool forceRefresh}) async {
        forced.add(forceRefresh);
        return forceRefresh ? 'tok-2' : 'tok-1';
      },
    );

    final body = await client.getJson('/api/v1/me');

    expect(adapter.requests.length, 2, reason: 'one retry');
    expect(adapter.requests[0].headers['Authorization'], 'Bearer tok-1');
    expect(adapter.requests[1].headers['Authorization'], 'Bearer tok-2');
    expect(forced, [false, true]);
    expect(body['user']['id'], 'u1');
  });

  test('does not retry a second time — a 401 after refresh throws', () async {
    final adapter = _FakeAdapter(
      (o, _) => _json(401, {
        'error': {'code': 'unauthenticated', 'message': 'x', 'requestId': 'r'},
      }),
    );
    final client = _client(adapter);

    await expectLater(
      () => client.getJson('/api/v1/me'),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.requests.length, 2, reason: 'initial + exactly one retry');
  });

  test('maps a connection timeout to ApiException.timeout', () async {
    final adapter = _FakeAdapter(
      (o, _) => throw DioException.connectionTimeout(
        timeout: const Duration(seconds: 1),
        requestOptions: o,
      ),
    );
    final client = _client(adapter);

    expect(
      () => client.getJson('/api/v1/me'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'timeout')),
    );
  });

  test('maps ID-token provider failures to ApiException', () async {
    final adapter = _FakeAdapter((o, _) => _json(200, {'ok': true}));
    final client = _client(
      adapter,
      tokens: ({required bool forceRefresh}) async {
        throw Exception('provider-specific failure');
      },
    );

    await expectLater(
      () => client.getJson('/api/v1/me'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'token_unavailable')
            .having((e) => e.statusCode, 'statusCode', isNull),
      ),
    );
    expect(adapter.requests, isEmpty);
  });
}
