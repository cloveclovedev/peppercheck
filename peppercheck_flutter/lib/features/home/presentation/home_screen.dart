import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/features/authentication/data/authentication_repository.dart';
import 'package:peppercheck_flutter/features/home/presentation/home_controller.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PepperCheck'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                ref.read(authenticationRepositoryProvider).signOut();
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: t.home.myTasks),
              Tab(text: t.home.refereeTasks),
            ],
          ),
        ),
        body: const TabBarView(children: [_MyTasksList(), _RefereeTasksList()]),
      ),
    );
  }
}

class _MyTasksList extends ConsumerWidget {
  const _MyTasksList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksValue = ref.watch(activeUserTasksProvider);

    return tasksValue.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return Center(child: Text(t.home.noTasks));
        }
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return _TaskListItem(task: task, isMyTask: true);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _RefereeTasksList extends ConsumerWidget {
  const _RefereeTasksList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksValue = ref.watch(activeRefereeTasksProvider);

    return tasksValue.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return Center(child: Text(t.home.noTasks));
        }
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return _TaskListItem(task: task, isMyTask: false);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _TaskListItem extends StatelessWidget {
  final Task task;
  final bool isMyTask;

  const _TaskListItem({required this.task, required this.isMyTask});

  @override
  Widget build(BuildContext context) {
    // Determine subtitle based on context
    String subtitle = task.status;
    if (isMyTask) {
      if (task.refereeRequests.isNotEmpty) {
        // Show status of requests. For now, just showing count or first one's status.
        // Ideally, we show a summary like "1 Matched, 1 Pending"
        final requestStatuses = task.refereeRequests
            .map((r) => r.status)
            .join(', ');
        subtitle += ' • Referees: $requestStatuses';
      } else {
        subtitle += ' • No Referees';
      }
    } else {
      if (task.tasker != null) {
        subtitle += ' • Tasker: ${task.tasker!.username ?? "Unknown"}';
      }
    }

    return ListTile(
      title: Text(task.title),
      subtitle: Text(subtitle),
      trailing: isMyTask
          ? null
          : (task.tasker?.avatarUrl != null
                ? CircleAvatar(
                    backgroundImage: NetworkImage(task.tasker!.avatarUrl!),
                  )
                : const Icon(Icons.person)),
      onTap: () {
        // TODO: Navigate to detail
      },
    );
  }
}
