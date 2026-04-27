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
    r'7a61d4d2e8f55f1b8aa4de628718b45b460c2526';

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
