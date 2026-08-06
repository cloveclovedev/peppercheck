// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presigned_upload_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app-wide [PresignedUploadClient] used to PUT avatar bytes directly to
/// R2. Separate from the `apiClient` provider: no Firebase bearer, no
/// interceptors.

@ProviderFor(presignedUploadClient)
const presignedUploadClientProvider = PresignedUploadClientProvider._();

/// The app-wide [PresignedUploadClient] used to PUT avatar bytes directly to
/// R2. Separate from the `apiClient` provider: no Firebase bearer, no
/// interceptors.

final class PresignedUploadClientProvider
    extends
        $FunctionalProvider<
          PresignedUploadClient,
          PresignedUploadClient,
          PresignedUploadClient
        >
    with $Provider<PresignedUploadClient> {
  /// The app-wide [PresignedUploadClient] used to PUT avatar bytes directly to
  /// R2. Separate from the `apiClient` provider: no Firebase bearer, no
  /// interceptors.
  const PresignedUploadClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'presignedUploadClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$presignedUploadClientHash();

  @$internal
  @override
  $ProviderElement<PresignedUploadClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PresignedUploadClient create(Ref ref) {
    return presignedUploadClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PresignedUploadClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PresignedUploadClient>(value),
    );
  }
}

String _$presignedUploadClientHash() =>
    r'0d00fb718156deccf667b2be782848d502af8bf0';
