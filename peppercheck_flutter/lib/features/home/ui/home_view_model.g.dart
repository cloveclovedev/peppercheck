// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tasks the signed-in user owns and still acts on. Refreshed by pull-to-refresh
/// and on resume; the matching result is polled on the task detail screen, not
/// here.

@ProviderFor(activeUserTasks)
const activeUserTasksProvider = ActiveUserTasksProvider._();

/// Tasks the signed-in user owns and still acts on. Refreshed by pull-to-refresh
/// and on resume; the matching result is polled on the task detail screen, not
/// here.

final class ActiveUserTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          FutureOr<List<Task>>
        >
    with $FutureModifier<List<Task>>, $FutureProvider<List<Task>> {
  /// Tasks the signed-in user owns and still acts on. Refreshed by pull-to-refresh
  /// and on resume; the matching result is polled on the task detail screen, not
  /// here.
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

String _$activeUserTasksHash() => r'294983aba245df0e741fdb0e4a4361730a2a0124';

/// Tasks the signed-in user referees. `GET /me/assignments` reports every task
/// the caller has an accepted *or* closed request on, and a task stays open
/// while a sibling referee is still working, so the caller's own request — not
/// the task's status — decides whether the assignment is still live.

@ProviderFor(activeRefereeTasks)
const activeRefereeTasksProvider = ActiveRefereeTasksProvider._();

/// Tasks the signed-in user referees. `GET /me/assignments` reports every task
/// the caller has an accepted *or* closed request on, and a task stays open
/// while a sibling referee is still working, so the caller's own request — not
/// the task's status — decides whether the assignment is still live.

final class ActiveRefereeTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          FutureOr<List<Task>>
        >
    with $FutureModifier<List<Task>>, $FutureProvider<List<Task>> {
  /// Tasks the signed-in user referees. `GET /me/assignments` reports every task
  /// the caller has an accepted *or* closed request on, and a task stays open
  /// while a sibling referee is still working, so the caller's own request — not
  /// the task's status — decides whether the assignment is still live.
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
    r'1a918ef1cefc2e38e5a6f0656b2b3327f2f07026';
