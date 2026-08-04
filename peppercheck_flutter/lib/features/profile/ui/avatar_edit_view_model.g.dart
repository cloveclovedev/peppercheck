// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatar_edit_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AvatarEditViewModel)
const avatarEditViewModelProvider = AvatarEditViewModelProvider._();

final class AvatarEditViewModelProvider
    extends $AsyncNotifierProvider<AvatarEditViewModel, void> {
  const AvatarEditViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'avatarEditViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$avatarEditViewModelHash();

  @$internal
  @override
  AvatarEditViewModel create() => AvatarEditViewModel();
}

String _$avatarEditViewModelHash() =>
    r'362c6513564af5eb9bda2f2458ac7a402a6927bb';

abstract class _$AvatarEditViewModel extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
