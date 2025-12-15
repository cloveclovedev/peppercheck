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
    r'f9636614c43c0a20966866bd53e852f20fcc5a96';

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
