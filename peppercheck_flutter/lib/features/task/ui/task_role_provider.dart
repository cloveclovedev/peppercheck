import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../auth/application/auth_state.dart';
import '../domain/task_viewer_role.dart';
import 'task_detail_view_model.dart';

part 'task_role_provider.g.dart';

/// How the signed-in user relates to one task. A thin composer only: it joins
/// the task with the current user and delegates to the pure
/// [TaskRoleX.viewerRole], so widgets can watch the role directly instead of
/// having it threaded down through constructors, and the rule itself stays
/// testable without a container.
@riverpod
Future<TaskViewerRole> taskRole(Ref ref, String taskId) async {
  final task = await ref.watch(taskDetailProvider(taskId).future);
  final me = await ref.watch(currentAppUserProvider.future);
  return task.viewerRole(me?.internalUserId);
}
