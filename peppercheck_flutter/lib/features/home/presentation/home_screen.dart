import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peppercheck_flutter/app/theme/app_colors.dart';
import 'package:peppercheck_flutter/app/theme/app_sizes.dart';
import 'package:peppercheck_flutter/common_widgets/app_background.dart';
import 'package:peppercheck_flutter/common_widgets/app_scaffold.dart';
import 'package:peppercheck_flutter/common_widgets/base_section.dart';
import 'package:peppercheck_flutter/features/home/presentation/home_controller.dart';
import 'package:peppercheck_flutter/features/home/presentation/widgets/task_card.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';
import 'package:peppercheck_flutter/gen/slang/strings.g.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  AppLifecycleListener? _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () {
        ref.invalidate(activeUserTasksProvider);
        ref.invalidate(activeRefereeTasksProvider);
      },
    );
  }

  @override
  void dispose() {
    _listener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: AppScaffold.scrollable(
        title: t.home.title,
        currentIndex: 0,
        onRefresh: () async {
          ref.invalidate(activeUserTasksProvider);
          ref.invalidate(activeRefereeTasksProvider);
        },
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              // Your Tasks Section
              _TaskSection(
                title: t.home.myTasks,
                tasksValue: ref.watch(activeUserTasksProvider),
              ),
              const SizedBox(height: AppSizes.sectionGap),

              // Referee Tasks Section
              _TaskSection(
                title: t.home.refereeTasks,
                tasksValue: ref.watch(activeRefereeTasksProvider),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TaskSection extends StatelessWidget {
  final String title;
  final AsyncValue<List<Task>> tasksValue;

  const _TaskSection({required this.title, required this.tasksValue});

  @override
  Widget build(BuildContext context) {
    return BaseSection(
      title: title,
      child: tasksValue.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return Text(
              t.home.noTasks,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            );
          }
          return Column(
            children: [
              for (int i = 0; i < tasks.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSizes.baseCardGap),
                TaskCard(task: tasks[i]),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Text(
          'Error: $e',
          style: const TextStyle(color: AppColors.textError),
        ),
      ),
    );
  }
}
