/// Recent Tasks section for the Home tab.
///
/// WHAT IT DOES:
///   Shows up to 10 tasks due in the selected period (Today / This Week /
///   This Month). Each card shows the task title, due time, linked contact,
///   and priority badge. Tapping opens the existing [TaskStatusSheet] so the
///   user can mark it done or update its status without leaving the home tab.
///
/// STATE:
///   Reads [HomeViewModel.homeTasks], [HomeViewModel.homeTasksRange], and
///   [HomeViewModel.isHomeTasksLoading]. Calls
///   [HomeViewModel.setHomeTasksRange] when the user switches periods.
///
///   NOTE: The task status actions call [TasksViewModel], which must be
///   registered in the provider tree (it is, via [main.dart]).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../services/tasks_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/home_view_model.dart';
import '../tasks/task_status_sheet.dart';

class RecentTasksSection extends StatelessWidget {
  const RecentTasksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterChipBar<KpiRange>(
          values: KpiRange.values,
          selected: home.homeTasksRange,
          labelOf: (r) => r.label,
          onSelected: home.setHomeTasksRange,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        _body(context, home),
      ],
    );
  }

  Widget _body(BuildContext context, HomeViewModel home) {
    if (home.isHomeTasksLoading) {
      return const Column(
        children: [
          ShimmerBox(height: 64),
          SizedBox(height: 10),
          ShimmerBox(height: 64),
          SizedBox(height: 10),
          ShimmerBox(height: 64),
        ],
      );
    }

    if (home.homeTasksError != null) {
      return ErrorStateView(
        message: 'Could not load tasks.',
        onRetry: () => home.setHomeTasksRange(home.homeTasksRange),
      );
    }

    if (home.homeTasks.isEmpty) {
      return const _EmptyTasks();
    }

    return Column(
      children: [
        for (final task in home.homeTasks) ...[
          _TaskRow(task: task),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// One task card in the home list.
///
/// Shows: title, due time, contact name, and a priority + state badge.
/// Tapping opens [TaskStatusSheet] which can mark the task done.
class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(task.priority);
    final stateColor = _stateColor(task.taskState);

    return OgeraCard(
      accent: stateColor,
      padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
      onTap: () => showTaskStatusSheet(context, task),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left icon badge
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _stateIcon(task.taskState),
              size: 18,
              color: stateColor,
            ),
          ),
          const SizedBox(width: 12),
          // Center: title + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + priority chip
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title ?? humanizeSlug(task.taskType),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    StatusChip(
                      label: task.priority.label,
                      color: priorityColor,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                // Due time + contact name
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: OgeraColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _dueLabel(task),
                      style: TextStyle(
                        fontSize: 13,
                        color: task.taskState == TaskState.overdue
                            ? OgeraColors.danger
                            : OgeraColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (task.contactName != null) ...[
                      const SizedBox(width: 8),
                      const Text(
                        '·',
                        style: TextStyle(color: OgeraColors.muted),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.contactName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: OgeraColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: OgeraColors.muted),
        ],
      ),
    );
  }

  /// "10:30 AM" when scheduled time is set, otherwise the date.
  String _dueLabel(Task task) {
    try {
      return formatTime(task.scheduledAt);
    } catch (_) {
      return task.scheduledDate;
    }
  }

  Color _priorityColor(TaskPriority p) => switch (p) {
    TaskPriority.high => OgeraColors.danger,
    TaskPriority.medium => OgeraColors.warning,
    TaskPriority.low => OgeraColors.muted,
  };

  Color _stateColor(TaskState s) => switch (s) {
    TaskState.overdue => OgeraColors.danger,
    TaskState.dueToday => OgeraColors.warning,
    TaskState.done => OgeraColors.success,
    TaskState.pending => OgeraColors.info,
  };

  IconData _stateIcon(TaskState s) => switch (s) {
    TaskState.overdue => Icons.error_outline_rounded,
    TaskState.dueToday => Icons.today_rounded,
    TaskState.done => Icons.check_circle_outline_rounded,
    TaskState.pending => Icons.pending_outlined,
  };
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 36,
              color: OgeraColors.muted,
            ),
            SizedBox(height: 8),
            Text(
              'No tasks in this period',
              style: TextStyle(fontSize: 14, color: OgeraColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
