// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referee_blocked_dates_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The signed-in referee's blocked calendar days.

@ProviderFor(RefereeBlockedDatesViewModel)
const refereeBlockedDatesViewModelProvider =
    RefereeBlockedDatesViewModelProvider._();

/// The signed-in referee's blocked calendar days.
final class RefereeBlockedDatesViewModelProvider
    extends
        $AsyncNotifierProvider<
          RefereeBlockedDatesViewModel,
          List<RefereeBlockedDate>
        > {
  /// The signed-in referee's blocked calendar days.
  const RefereeBlockedDatesViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'refereeBlockedDatesViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$refereeBlockedDatesViewModelHash();

  @$internal
  @override
  RefereeBlockedDatesViewModel create() => RefereeBlockedDatesViewModel();
}

String _$refereeBlockedDatesViewModelHash() =>
    r'21def89cbdc543925434263b15e3efe281b273cd';

/// The signed-in referee's blocked calendar days.

abstract class _$RefereeBlockedDatesViewModel
    extends $AsyncNotifier<List<RefereeBlockedDate>> {
  FutureOr<List<RefereeBlockedDate>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<RefereeBlockedDate>>,
              List<RefereeBlockedDate>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<RefereeBlockedDate>>,
                List<RefereeBlockedDate>
              >,
              AsyncValue<List<RefereeBlockedDate>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
