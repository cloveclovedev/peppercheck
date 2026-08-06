import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/core/network/api_client.dart';
import 'package:peppercheck_flutter/core/network/paginated_fetch.dart';

import 'paginated_fetch_test.mocks.dart';

@GenerateNiceMocks([MockSpec<ApiClient>()])
void main() {
  late MockApiClient api;

  setUp(() => api = MockApiClient());

  test('returns the single page when there is no next cursor', () async {
    when(api.getJson('/api/v1/me/tasks')).thenAnswer(
      (_) async => {
        'tasks': [
          {'id': 'a'},
        ],
        'nextCursor': null,
      },
    );

    final items = await fetchAllPages(
      api,
      '/api/v1/me/tasks',
      itemsKey: 'tasks',
    );

    expect(items, [
      {'id': 'a'},
    ]);
    verify(api.getJson('/api/v1/me/tasks')).called(1);
  });

  test('follows the cursor and URI-encodes it as an opaque value', () async {
    when(api.getJson('/api/v1/me/tasks')).thenAnswer(
      (_) async => {
        'tasks': [
          {'id': 'a'},
        ],
        'nextCursor': 'a+b/c==',
      },
    );
    when(api.getJson('/api/v1/me/tasks?cursor=a%2Bb%2Fc%3D%3D')).thenAnswer(
      (_) async => {
        'tasks': [
          {'id': 'b'},
        ],
        'nextCursor': null,
      },
    );

    final items = await fetchAllPages(
      api,
      '/api/v1/me/tasks',
      itemsKey: 'tasks',
    );

    expect(items, [
      {'id': 'a'},
      {'id': 'b'},
    ]);
    verify(api.getJson('/api/v1/me/tasks')).called(1);
    verify(api.getJson('/api/v1/me/tasks?cursor=a%2Bb%2Fc%3D%3D')).called(1);
  });

  test('appends the cursor to a path that already has a query', () async {
    when(api.getJson('/api/v1/me/tasks?status=open')).thenAnswer(
      (_) async => {'tasks': <Map<String, dynamic>>[], 'nextCursor': 'c1'},
    );
    when(api.getJson('/api/v1/me/tasks?status=open&cursor=c1')).thenAnswer(
      (_) async => {'tasks': <Map<String, dynamic>>[], 'nextCursor': null},
    );

    await fetchAllPages(api, '/api/v1/me/tasks?status=open', itemsKey: 'tasks');

    verify(api.getJson('/api/v1/me/tasks?status=open&cursor=c1')).called(1);
  });

  test('tolerates a missing items key', () async {
    when(
      api.getJson('/api/v1/me/tasks'),
    ).thenAnswer((_) async => <String, dynamic>{});

    expect(
      await fetchAllPages(api, '/api/v1/me/tasks', itemsKey: 'tasks'),
      isEmpty,
    );
  });
}
