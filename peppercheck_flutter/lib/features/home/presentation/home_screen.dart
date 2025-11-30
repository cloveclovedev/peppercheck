import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/home/presentation/home_controller.dart';
import 'package:peppercheck_flutter/features/home/presentation/widgets/task_card.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBackground(
      child: AppScaffold(
        title: t.home.title,
        currentIndex: 0,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              // Refresh both providers
              ref.invalidate(activeUserTasksProvider);
              ref.invalidate(activeRefereeTasksProvider);
            },
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Header removed (moved to AppScaffold)

                      // Your Tasks Section
                      _TaskSection(
                        title: t.home.myTasks,
                        tasksValue: ref.watch(activeUserTasksProvider),
                        isMyTask: true,
                      ),
                      const SizedBox(height: 16),

                      // Referee Tasks Section
                      _TaskSection(
                        title: t.home.refereeTasks,
                        tasksValue: ref.watch(activeRefereeTasksProvider),
                        isMyTask: false,
                      ),
                      // Add extra padding at the bottom to avoid overlap with floating bottom bar
                      const SizedBox(height: 80),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskSection extends StatelessWidget {
  final String title;
  final AsyncValue<List<Task>> tasksValue;
  final bool isMyTask;

  const _TaskSection({
    required this.title,
    required this.tasksValue,
    required this.isMyTask,
  });

  @override
  Widget build(BuildContext context) {
    return BaseSection(
      title: title,
      child: tasksValue.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                t.home.noTasks,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            );
          }
          return Column(
            children: tasks
                .map((task) => TaskCard(task: task, isMyTask: isMyTask))
                .toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) =>
            Text('Error: $e', style: const TextStyle(color: Colors.red)),
      ),
    );
  }
}
