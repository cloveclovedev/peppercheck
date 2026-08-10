// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_detail_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Owns the task detail screen's copy of a task, including the short poll that
/// turns a freshly published task from "matching" into its matched referees.
///
/// Matching runs asynchronously on the server, so the client polls rather than
/// subscribing: push notifications only tell the user something happened, and
/// every screen update is API-sourced.

@ProviderFor(TaskDetail)
const taskDetailProvider = TaskDetailFamily._();

/// Owns the task detail screen's copy of a task, including the short poll that
/// turns a freshly published task from "matching" into its matched referees.
///
/// Matching runs asynchronously on the server, so the client polls rather than
/// subscribing: push notifications only tell the user something happened, and
/// every screen update is API-sourced.
final class TaskDetailProvider
    extends $AsyncNotifierProvider<TaskDetail, Task> {
  /// Owns the task detail screen's copy of a task, including the short poll that
  /// turns a freshly published task from "matching" into its matched referees.
  ///
  /// Matching runs asynchronously on the server, so the client polls rather than
  /// subscribing: push notifications only tell the user something happened, and
  /// every screen update is API-sourced.
  const TaskDetailProvider._({
    required TaskDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'taskDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskDetailHash();

  @override
  String toString() {
    return r'taskDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TaskDetail create() => TaskDetail();

  @override
  bool operator ==(Object other) {
    return other is TaskDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskDetailHash() => r'e9bfa33e972df65fbae4ff9b62b220db7a04703d';

/// Owns the task detail screen's copy of a task, including the short poll that
/// turns a freshly published task from "matching" into its matched referees.
///
/// Matching runs asynchronously on the server, so the client polls rather than
/// subscribing: push notifications only tell the user something happened, and
/// every screen update is API-sourced.

final class TaskDetailFamily extends $Family
    with
        $ClassFamilyOverride<
          TaskDetail,
          AsyncValue<Task>,
          Task,
          FutureOr<Task>,
          String
        > {
  const TaskDetailFamily._()
    : super(
        retry: null,
        name: r'taskDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Owns the task detail screen's copy of a task, including the short poll that
  /// turns a freshly published task from "matching" into its matched referees.
  ///
  /// Matching runs asynchronously on the server, so the client polls rather than
  /// subscribing: push notifications only tell the user something happened, and
  /// every screen update is API-sourced.

  TaskDetailProvider call(String taskId) =>
      TaskDetailProvider._(argument: taskId, from: this);

  @override
  String toString() => r'taskDetailProvider';
}

/// Owns the task detail screen's copy of a task, including the short poll that
/// turns a freshly published task from "matching" into its matched referees.
///
/// Matching runs asynchronously on the server, so the client polls rather than
/// subscribing: push notifications only tell the user something happened, and
/// every screen update is API-sourced.

abstract class _$TaskDetail extends $AsyncNotifier<Task> {
  late final _$args = ref.$arg as String;
  String get taskId => _$args;

  FutureOr<Task> build(String taskId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<Task>, Task>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Task>, Task>,
              AsyncValue<Task>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
