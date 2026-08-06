// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'username_edit_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UsernameEditViewModel)
const usernameEditViewModelProvider = UsernameEditViewModelProvider._();

final class UsernameEditViewModelProvider
    extends $AsyncNotifierProvider<UsernameEditViewModel, void> {
  const UsernameEditViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usernameEditViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usernameEditViewModelHash();

  @$internal
  @override
  UsernameEditViewModel create() => UsernameEditViewModel();
}

String _$usernameEditViewModelHash() =>
    r'a6f3462592eb707f91873f64a849c5cdda5d0839';

abstract class _$UsernameEditViewModel extends $AsyncNotifier<void> {
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
