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
    extends $NotifierProvider<TaskCreationController, TaskCreationRequest> {
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

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskCreationRequest value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskCreationRequest>(value),
    );
  }

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
    r'48745a77e8c83a94f376b729be769359253d63c4';

final class TaskCreationControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          TaskCreationController,
          TaskCreationRequest,
          TaskCreationRequest,
          TaskCreationRequest,
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

abstract class _$TaskCreationController extends $Notifier<TaskCreationRequest> {
  late final _$args = ref.$arg as Task?;
  Task? get initialTask => _$args;

  TaskCreationRequest build(Task? initialTask);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<TaskCreationRequest, TaskCreationRequest>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TaskCreationRequest, TaskCreationRequest>,
              TaskCreationRequest,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
