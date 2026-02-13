// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_creation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskCreationController)
const taskCreationControllerProvider = TaskCreationControllerFamily._();

final class TaskCreationControllerProvider
    extends $AsyncNotifierProvider<TaskCreationController, TaskCreationState> {
  const TaskCreationControllerProvider._({
    required TaskCreationControllerFamily super.from,
    required Task? super.argument,
  }) : super(
         retry: null,
         name: r'taskCreationControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskCreationControllerHash();

  @override
  String toString() {
    return r'taskCreationControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TaskCreationController create() => TaskCreationController();

  @override
  bool operator ==(Object other) {
    return other is TaskCreationControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskCreationControllerHash() =>
    r'f611bd92a117cd066db0ce05de5f04c7fe149e2c';

final class TaskCreationControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          TaskCreationController,
          AsyncValue<TaskCreationState>,
          TaskCreationState,
          FutureOr<TaskCreationState>,
          Task?
        > {
  const TaskCreationControllerFamily._()
    : super(
        retry: null,
        name: r'taskCreationControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TaskCreationControllerProvider call(Task? initialTask) =>
      TaskCreationControllerProvider._(argument: initialTask, from: this);

  @override
  String toString() => r'taskCreationControllerProvider';
}

abstract class _$TaskCreationController
    extends $AsyncNotifier<TaskCreationState> {
  late final _$args = ref.$arg as Task?;
  Task? get initialTask => _$args;

  FutureOr<TaskCreationState> build(Task? initialTask);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref as $Ref<AsyncValue<TaskCreationState>, TaskCreationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TaskCreationState>, TaskCreationState>,
              AsyncValue<TaskCreationState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
