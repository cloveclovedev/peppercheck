import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/core/network/api_exception.dart';
import 'package:peppercheck_flutter/core/network/presigned_upload_client.dart';
import 'package:peppercheck_flutter/core/network/presigned_upload_client_provider.dart';
import 'package:peppercheck_flutter/features/profile/data/avatar_upload_dto.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_repository.dart';
import 'package:peppercheck_flutter/features/profile/ui/avatar_edit_view_model.dart';

import 'avatar_edit_view_model_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<ProfileRepository>(),
  MockSpec<PresignedUploadClient>(),
])
void main() {
  late MockProfileRepository mockProfileRepository;
  late MockPresignedUploadClient mockPresignedUploadClient;

  setUp(() {
    mockProfileRepository = MockProfileRepository();
    mockPresignedUploadClient = MockPresignedUploadClient();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        profileRepositoryProvider.overrideWithValue(mockProfileRepository),
        presignedUploadClientProvider.overrideWithValue(
          mockPresignedUploadClient,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  final upload = AvatarUploadDto(
    uploadUrl: 'https://r2.example.com/upload?sig=abc',
    publicUrl: 'https://cdn.example.com/avatar.jpg',
    expiresAt: '2026-07-25T00:05:00Z',
  );

  test('happy path calls request -> put -> commit in order', () async {
    final container = makeContainer();
    final bytes = List<int>.filled(1024, 1);

    when(
      mockProfileRepository.requestAvatarUpload(
        contentType: 'image/jpeg',
        fileSizeBytes: bytes.length,
      ),
    ).thenAnswer((_) async => upload);
    when(
      mockPresignedUploadClient.put(
        uploadUrl: upload.uploadUrl,
        bytes: bytes,
        contentType: 'image/jpeg',
      ),
    ).thenAnswer((_) async {});
    when(
      mockProfileRepository.commitAvatar(upload.publicUrl),
    ).thenAnswer((_) async {});

    var successCalled = false;
    await container
        .read(avatarEditViewModelProvider.notifier)
        .uploadAvatarBytes(
          bytes,
          onSuccess: () => successCalled = true,
          onError: (_) {},
        );

    verifyInOrder([
      mockProfileRepository.requestAvatarUpload(
        contentType: 'image/jpeg',
        fileSizeBytes: bytes.length,
      ),
      mockPresignedUploadClient.put(
        uploadUrl: upload.uploadUrl,
        bytes: bytes,
        contentType: 'image/jpeg',
      ),
      mockProfileRepository.commitAvatar(upload.publicUrl),
    ]);
    expect(successCalled, isTrue);
  });

  test('an oversized file is rejected before any request', () async {
    final container = makeContainer();
    final bytes = List<int>.filled(5 * 1024 * 1024 + 1, 1);

    String? errorKey;
    await container
        .read(avatarEditViewModelProvider.notifier)
        .uploadAvatarBytes(
          bytes,
          onSuccess: () {},
          onError: (key) => errorKey = key,
        );

    expect(errorKey, 'tooLarge');
    verifyNever(
      mockProfileRepository.requestAvatarUpload(
        contentType: anyNamed('contentType'),
        fileSizeBytes: anyNamed('fileSizeBytes'),
      ),
    );
  });

  test('rate_limited surfaces the retry message', () async {
    final container = makeContainer();
    final bytes = List<int>.filled(1024, 1);

    when(
      mockProfileRepository.requestAvatarUpload(
        contentType: 'image/jpeg',
        fileSizeBytes: bytes.length,
      ),
    ).thenThrow(
      const ApiException(
        code: 'rate_limited',
        message: 'avatar upload rate limit exceeded',
        statusCode: 429,
      ),
    );

    String? errorKey;
    await container
        .read(avatarEditViewModelProvider.notifier)
        .uploadAvatarBytes(
          bytes,
          onSuccess: () {},
          onError: (key) => errorKey = key,
        );

    expect(errorKey, 'rateLimited');
  });
}
