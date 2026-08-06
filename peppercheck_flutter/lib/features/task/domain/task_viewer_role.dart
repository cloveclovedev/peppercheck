import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';

/// How the current viewer relates to a task: its tasker, one of its assigned
/// referees (then [myRequest] is the viewer's referee request), or neither.
class TaskViewerRole {
  const TaskViewerRole({required this.isTasker, required this.myRequest});

  final bool isTasker;
  final RefereeRequest? myRequest;

  bool get isAssignedReferee => myRequest != null;
}

extension TaskRoleX on Task {
  /// Pure role derivation from the internal user id (`AppUser.internalUserId`).
  /// A null id (signed out, or the user record not resolved yet) is neither.
  TaskViewerRole viewerRole(String? internalUserId) {
    if (internalUserId == null) {
      return const TaskViewerRole(isTasker: false, myRequest: null);
    }
    RefereeRequest? mine;
    for (final r in refereeRequests) {
      if (r.matchedRefereeId == internalUserId) {
        mine = r;
        break;
      }
    }
    return TaskViewerRole(
      isTasker: taskerId == internalUserId,
      myRequest: mine,
    );
  }
}
