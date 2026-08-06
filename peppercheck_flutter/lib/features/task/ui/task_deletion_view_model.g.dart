// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_deletion_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskDeletionViewModel)
const taskDeletionViewModelProvider = TaskDeletionViewModelProvider._();

final class TaskDeletionViewModelProvider
    extends $AsyncNotifierProvider<TaskDeletionViewModel, void> {
  const TaskDeletionViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskDeletionViewModelProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskDeletionViewModelHash();

  @$internal
  @override
  TaskDeletionViewModel create() => TaskDeletionViewModel();
}

String _$taskDeletionViewModelHash() =>
    r'729ef67e96d0ae9abdf1cf3076bf885e48f144b7';

abstract class _$TaskDeletionViewModel extends $AsyncNotifier<void> {
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
