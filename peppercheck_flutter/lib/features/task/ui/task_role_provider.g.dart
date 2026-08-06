// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_role_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How the signed-in user relates to one task. A thin composer only: it joins
/// the task with the current user and delegates to the pure
/// [TaskRoleX.viewerRole], so widgets can watch the role directly instead of
/// having it threaded down through constructors, and the rule itself stays
/// testable without a container.

@ProviderFor(taskRole)
const taskRoleProvider = TaskRoleFamily._();

/// How the signed-in user relates to one task. A thin composer only: it joins
/// the task with the current user and delegates to the pure
/// [TaskRoleX.viewerRole], so widgets can watch the role directly instead of
/// having it threaded down through constructors, and the rule itself stays
/// testable without a container.

final class TaskRoleProvider
    extends
        $FunctionalProvider<
          AsyncValue<TaskViewerRole>,
          TaskViewerRole,
          FutureOr<TaskViewerRole>
        >
    with $FutureModifier<TaskViewerRole>, $FutureProvider<TaskViewerRole> {
  /// How the signed-in user relates to one task. A thin composer only: it joins
  /// the task with the current user and delegates to the pure
  /// [TaskRoleX.viewerRole], so widgets can watch the role directly instead of
  /// having it threaded down through constructors, and the rule itself stays
  /// testable without a container.
  const TaskRoleProvider._({
    required TaskRoleFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'taskRoleProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskRoleHash();

  @override
  String toString() {
    return r'taskRoleProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TaskViewerRole> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TaskViewerRole> create(Ref ref) {
    final argument = this.argument as String;
    return taskRole(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskRoleProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskRoleHash() => r'675779b9727ba3177a9475b708fc299876410eda';

/// How the signed-in user relates to one task. A thin composer only: it joins
/// the task with the current user and delegates to the pure
/// [TaskRoleX.viewerRole], so widgets can watch the role directly instead of
/// having it threaded down through constructors, and the rule itself stays
/// testable without a container.

final class TaskRoleFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TaskViewerRole>, String> {
  const TaskRoleFamily._()
    : super(
        retry: null,
        name: r'taskRoleProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// How the signed-in user relates to one task. A thin composer only: it joins
  /// the task with the current user and delegates to the pure
  /// [TaskRoleX.viewerRole], so widgets can watch the role directly instead of
  /// having it threaded down through constructors, and the rule itself stays
  /// testable without a container.

  TaskRoleProvider call(String taskId) =>
      TaskRoleProvider._(argument: taskId, from: this);

  @override
  String toString() => r'taskRoleProvider';
}
