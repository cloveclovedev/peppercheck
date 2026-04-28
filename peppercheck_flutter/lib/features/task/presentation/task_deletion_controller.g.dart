// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_deletion_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskDeletionController)
const taskDeletionControllerProvider = TaskDeletionControllerProvider._();

final class TaskDeletionControllerProvider
    extends $AsyncNotifierProvider<TaskDeletionController, void> {
  const TaskDeletionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskDeletionControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskDeletionControllerHash();

  @$internal
  @override
  TaskDeletionController create() => TaskDeletionController();
}

String _$taskDeletionControllerHash() =>
    r'1ce91f877a5d01d1217f950e1e4c8ab83ac0cefd';

abstract class _$TaskDeletionController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
