// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_creation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskCreationController)
const taskCreationControllerProvider = TaskCreationControllerProvider._();

final class TaskCreationControllerProvider
    extends
        $AsyncNotifierProvider<TaskCreationController, TaskCreationRequest> {
  const TaskCreationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskCreationControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskCreationControllerHash();

  @$internal
  @override
  TaskCreationController create() => TaskCreationController();
}

String _$taskCreationControllerHash() =>
    r'8417f8b918276480e6b5ff3985123b448da58d41';

abstract class _$TaskCreationController
    extends $AsyncNotifier<TaskCreationRequest> {
  FutureOr<TaskCreationRequest> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<TaskCreationRequest>, TaskCreationRequest>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<TaskCreationRequest>, TaskCreationRequest>,
              AsyncValue<TaskCreationRequest>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
