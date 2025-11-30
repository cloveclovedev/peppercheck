// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activeUserTasks)
const activeUserTasksProvider = ActiveUserTasksProvider._();

final class ActiveUserTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          FutureOr<List<Task>>
        >
    with $FutureModifier<List<Task>>, $FutureProvider<List<Task>> {
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

String _$activeUserTasksHash() => r'ccb79a2846592c2b704d7ba3f609efd105d7990b';

@ProviderFor(activeRefereeTasks)
const activeRefereeTasksProvider = ActiveRefereeTasksProvider._();

final class ActiveRefereeTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          FutureOr<List<Task>>
        >
    with $FutureModifier<List<Task>>, $FutureProvider<List<Task>> {
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
    r'a2f3b2f82c82cd2ef81d0e7fe6fef1c761e5ed45';
