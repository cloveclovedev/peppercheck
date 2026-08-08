// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referee_availability_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The signed-in referee's weekly availability. Every call is scoped to the
/// bearer, so the list reloads from the server after each edit rather than
/// being patched locally.
///
/// Only active slots are exposed: the API returns disabled slots too, but the
/// cards render no enabled/disabled state, so showing one would read as normal
/// availability that matching silently skips. They come back with the toggle
/// UI.

@ProviderFor(RefereeAvailabilityViewModel)
const refereeAvailabilityViewModelProvider =
    RefereeAvailabilityViewModelProvider._();

/// The signed-in referee's weekly availability. Every call is scoped to the
/// bearer, so the list reloads from the server after each edit rather than
/// being patched locally.
///
/// Only active slots are exposed: the API returns disabled slots too, but the
/// cards render no enabled/disabled state, so showing one would read as normal
/// availability that matching silently skips. They come back with the toggle
/// UI.
final class RefereeAvailabilityViewModelProvider
    extends
        $AsyncNotifierProvider<
          RefereeAvailabilityViewModel,
          List<RefereeAvailableTimeSlot>
        > {
  /// The signed-in referee's weekly availability. Every call is scoped to the
  /// bearer, so the list reloads from the server after each edit rather than
  /// being patched locally.
  ///
  /// Only active slots are exposed: the API returns disabled slots too, but the
  /// cards render no enabled/disabled state, so showing one would read as normal
  /// availability that matching silently skips. They come back with the toggle
  /// UI.
  const RefereeAvailabilityViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'refereeAvailabilityViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$refereeAvailabilityViewModelHash();

  @$internal
  @override
  RefereeAvailabilityViewModel create() => RefereeAvailabilityViewModel();
}

String _$refereeAvailabilityViewModelHash() =>
    r'510cd0f5d6b3a8cefdb604949c67e169a5747ac9';

/// The signed-in referee's weekly availability. Every call is scoped to the
/// bearer, so the list reloads from the server after each edit rather than
/// being patched locally.
///
/// Only active slots are exposed: the API returns disabled slots too, but the
/// cards render no enabled/disabled state, so showing one would read as normal
/// availability that matching silently skips. They come back with the toggle
/// UI.

abstract class _$RefereeAvailabilityViewModel
    extends $AsyncNotifier<List<RefereeAvailableTimeSlot>> {
  FutureOr<List<RefereeAvailableTimeSlot>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<RefereeAvailableTimeSlot>>,
              List<RefereeAvailableTimeSlot>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<RefereeAvailableTimeSlot>>,
                List<RefereeAvailableTimeSlot>
              >,
              AsyncValue<List<RefereeAvailableTimeSlot>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
