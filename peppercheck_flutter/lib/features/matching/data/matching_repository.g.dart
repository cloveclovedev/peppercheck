// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matching_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(matchingRepository)
const matchingRepositoryProvider = MatchingRepositoryProvider._();

final class MatchingRepositoryProvider
    extends
        $FunctionalProvider<
          MatchingRepository,
          MatchingRepository,
          MatchingRepository
        >
    with $Provider<MatchingRepository> {
  const MatchingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'matchingRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$matchingRepositoryHash();

  @$internal
  @override
  $ProviderElement<MatchingRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MatchingRepository create(Ref ref) {
    return matchingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MatchingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MatchingRepository>(value),
    );
  }
}

String _$matchingRepositoryHash() =>
    r'1aa6e2d705af87a378ed18e75185e2fb09e77b3e';
