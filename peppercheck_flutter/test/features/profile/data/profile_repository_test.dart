import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/core/network/api_client.dart';
import 'package:peppercheck_flutter/core/network/api_exception.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_errors.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_repository.dart';

import 'profile_repository_test.mocks.dart';

Map<String, dynamic> _profileJson({
  String username = 'tanaka',
  String? avatarUrl = 'https://cdn.example.com/avatar.jpg',
  String timezone = 'Asia/Tokyo',
}) => {
  'username': username,
  'avatarUrl': avatarUrl,
  'timezone': timezone,
  'createdAt': '2026-07-25T00:00:00Z',
  'updatedAt': '2026-07-25T00:00:00Z',
};

@GenerateNiceMocks([MockSpec<ApiClient>()])
void main() {
  late MockApiClient api;
  late ProfileRepository repo;

  setUp(() {
    api = MockApiClient();
    repo = ProfileRepository(api);
  });

  group('fetchOwn', () {
    test('maps GET /api/v1/me/profile to Profile (no id field)', () async {
      when(
        api.getJson('/api/v1/me/profile'),
      ).thenAnswer((_) async => _profileJson());

      final profile = await repo.fetchOwn();

      expect(profile.username, 'tanaka');
      expect(profile.avatarUrl, 'https://cdn.example.com/avatar.jpg');
      expect(profile.timezone, 'Asia/Tokyo');
    });
  });

  group('updateUsername', () {
    test('PATCHes /api/v1/me/profile with the username', () async {
      when(
        api.patchJson('/api/v1/me/profile', body: {'username': 'tanaka'}),
      ).thenAnswer((_) async => _profileJson(username: 'tanaka'));

      await repo.updateUsername('tanaka');

      verify(
        api.patchJson('/api/v1/me/profile', body: {'username': 'tanaka'}),
      ).called(1);
    });

    test(
      'rethrows ApiException(username_taken) as UsernameAlreadyTakenException',
      () async {
        when(
          api.patchJson('/api/v1/me/profile', body: {'username': 'taken'}),
        ).thenThrow(
          const ApiException(
            code: 'username_taken',
            message: 'username already in use',
            statusCode: 409,
          ),
        );

        await expectLater(
          () => repo.updateUsername('taken'),
          throwsA(isA<UsernameAlreadyTakenException>()),
        );
      },
    );

    test('propagates other ApiExceptions unchanged', () async {
      when(
        api.patchJson('/api/v1/me/profile', body: {'username': 'tanaka'}),
      ).thenThrow(const ApiException.network());

      await expectLater(
        () => repo.updateUsername('tanaka'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'network')),
      );
    });
  });

  group('updateTimezone', () {
    test('PATCHes /api/v1/me/profile with the timezone', () async {
      when(
        api.patchJson(
          '/api/v1/me/profile',
          body: {'timezone': 'America/New_York'},
        ),
      ).thenAnswer((_) async => _profileJson(timezone: 'America/New_York'));

      await repo.updateTimezone('America/New_York');

      verify(
        api.patchJson(
          '/api/v1/me/profile',
          body: {'timezone': 'America/New_York'},
        ),
      ).called(1);
    });
  });

  group('requestAvatarUpload', () {
    test('maps the POST response to AvatarUploadDto', () async {
      when(
        api.postJson(
          '/api/v1/me/avatar/request-upload-url',
          body: {'contentType': 'image/jpeg', 'fileSizeBytes': 1024},
        ),
      ).thenAnswer(
        (_) async => {
          'uploadUrl': 'https://r2.example.com/upload?sig=abc',
          'publicUrl': 'https://cdn.example.com/avatar.jpg',
          'expiresAt': '2026-07-25T00:05:00Z',
        },
      );

      final dto = await repo.requestAvatarUpload(
        contentType: 'image/jpeg',
        fileSizeBytes: 1024,
      );

      expect(dto.uploadUrl, 'https://r2.example.com/upload?sig=abc');
      expect(dto.publicUrl, 'https://cdn.example.com/avatar.jpg');
      expect(dto.expiresAt, '2026-07-25T00:05:00Z');
    });
  });

  group('commitAvatar', () {
    test('PATCHes /api/v1/me/profile with the avatarUrl', () async {
      when(
        api.patchJson(
          '/api/v1/me/profile',
          body: {'avatarUrl': 'https://cdn.example.com/avatar.jpg'},
        ),
      ).thenAnswer(
        (_) async =>
            _profileJson(avatarUrl: 'https://cdn.example.com/avatar.jpg'),
      );

      await repo.commitAvatar('https://cdn.example.com/avatar.jpg');

      verify(
        api.patchJson(
          '/api/v1/me/profile',
          body: {'avatarUrl': 'https://cdn.example.com/avatar.jpg'},
        ),
      ).called(1);
    });
  });
}
