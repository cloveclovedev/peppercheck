// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tasks the signed-in user owns. Refreshed by pull-to-refresh and on resume;
/// the matching result is polled on the task detail screen, not here.

@ProviderFor(activeUserTasks)
const activeUserTasksProvider = ActiveUserTasksProvider._();

/// Tasks the signed-in user owns. Refreshed by pull-to-refresh and on resume;
/// the matching result is polled on the task detail screen, not here.

final class ActiveUserTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          FutureOr<List<Task>>
        >
    with $FutureModifier<List<Task>>, $FutureProvider<List<Task>> {
  /// Tasks the signed-in user owns. Refreshed by pull-to-refresh and on resume;
  /// the matching result is polled on the task detail screen, not here.
  const ActiveUserTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeUserTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeUserTasksHash();

  @$internal
  @override
  $FutureProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Task>> create(Ref ref) {
    return activeUserTasks(ref);
  }
}

String _$activeUserTasksHash() => r'ba1e2bac67b026cc99eecdb48455433b793f2e5f';

/// Tasks the signed-in user referees. Each row carries the caller's real
/// referee request as served by `GET /me/assignments`.

@ProviderFor(activeRefereeTasks)
const activeRefereeTasksProvider = ActiveRefereeTasksProvider._();

/// Tasks the signed-in user referees. Each row carries the caller's real
/// referee request as served by `GET /me/assignments`.

final class ActiveRefereeTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          FutureOr<List<Task>>
        >
    with $FutureModifier<List<Task>>, $FutureProvider<List<Task>> {
  /// Tasks the signed-in user referees. Each row carries the caller's real
  /// referee request as served by `GET /me/assignments`.
  const ActiveRefereeTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeRefereeTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeRefereeTasksHash();

  @$internal
  @override
  $FutureProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Task>> create(Ref ref) {
    return activeRefereeTasks(ref);
  }
}

String _$activeRefereeTasksHash() =>
    r'43d837f0d18cecbfa02d1b20e25da3a71d704916';
