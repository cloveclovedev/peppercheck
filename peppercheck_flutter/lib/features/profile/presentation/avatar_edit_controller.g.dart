// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'avatar_edit_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AvatarEditController)
const avatarEditControllerProvider = AvatarEditControllerProvider._();

final class AvatarEditControllerProvider
    extends $AsyncNotifierProvider<AvatarEditController, void> {
  const AvatarEditControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'avatarEditControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$avatarEditControllerHash();

  @$internal
  @override
  AvatarEditController create() => AvatarEditController();
}

String _$avatarEditControllerHash() =>
    r'ba84b0e78953ccf0c194162314123cd203333300';

abstract class _$AvatarEditController extends $AsyncNotifier<void> {
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
