// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_creation_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskCreationViewModel)
const taskCreationViewModelProvider = TaskCreationViewModelFamily._();

final class TaskCreationViewModelProvider
    extends $AsyncNotifierProvider<TaskCreationViewModel, TaskCreationState> {
  const TaskCreationViewModelProvider._({
    required TaskCreationViewModelFamily super.from,
    required Task? super.argument,
  }) : super(
         retry: null,
         name: r'taskCreationViewModelProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskCreationViewModelHash();

  @override
  String toString() {
    return r'taskCreationViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TaskCreationViewModel create() => TaskCreationViewModel();

  @override
  bool operator ==(Object other) {
    return other is TaskCreationViewModelProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskCreationViewModelHash() =>
    r'685abb0c533c9b574f7adc3f484efd5b0475e437';

final class TaskCreationViewModelFamily extends $Family
    with
        $ClassFamilyOverride<
          TaskCreationViewModel,
          AsyncValue<TaskCreationState>,
          TaskCreationState,
          FutureOr<TaskCreationState>,
          Task?
        > {
  const TaskCreationViewModelFamily._()
    : super(
        retry: null,
        name: r'taskCreationViewModelProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TaskCreationViewModelProvider call(Task? initialTask) =>
      TaskCreationViewModelProvider._(argument: initialTask, from: this);

  @override
  String toString() => r'taskCreationViewModelProvider';
}

abstract class _$TaskCreationViewModel
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
