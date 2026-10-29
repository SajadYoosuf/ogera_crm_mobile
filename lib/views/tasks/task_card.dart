/// A single task list item card.
///
/// WHAT IT SHOWS:
///   - Task type icon in a coloured circle
///   - Title (or phone if no title), contact name
///   - Scheduled date + time, overdue badge
///   - Priority badge
///   - Tap to open the task detail sheet
///
/// The icon, colour and label helpers at the bottom are public so the detail
/// sheet and the home list show tasks the same way.
library;

import 'package:flutter/material.dart';

import '../../core/widgets/ogera_widgets.dart';
import '../../services/tasks_service.dart';
import '../../theme/ogera_colors.dart';

// ── Icon helpers ─────────────────────────────────────────────────────────────

/// Shape for task bottom sheets: rounded top corners on a solid white surface.
const taskSheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
);

/// Icon for a task type value such as "phone_call" or "field_visit".
IconData taskTypeIcon(String type) {
  switch (type) {
    case 'call':
    case 'phone_call':
      return Icons.phone_outlined;
    case 'visit':
    case 'site_visit':
      return Icons.map_outlined;
    case 'demo':
      return Icons.play_circle_outline_rounded;
    case 'follow_up':
      return Icons.repeat_rounded;
    default:
      return Icons.task_alt_rounded;
  }
}

/// Accent colour for a task state (overdue red, due today amber, ...).
Color taskStateColor(TaskState state) {
  switch (state) {
    case TaskState.overdue:
      return OgeraColors.danger;
    case TaskState.dueToday:
      return OgeraColors.warning;
    case TaskState.done:
      return OgeraColors.success;
    case TaskState.pending:
      return OgeraColors.blue;
  }
}

/// Short state text shown on chips, e.g. "Overdue 2 d".
String taskStateLabel(TaskState state, int overdueDays) {
  switch (state) {
    case TaskState.overdue:
      return 'Overdue $overdueDays d';
    case TaskState.dueToday:
      return 'Due today';
    case TaskState.done:
      return 'Done';
    case TaskState.pending:
      return 'Upcoming';
  }
}

/// Dot colour for a priority: high red, medium amber, low grey.
Color taskPriorityColor(TaskPriority p) {
  switch (p) {
    case TaskPriority.high:
      return OgeraColors.danger;
    case TaskPriority.medium:
      return OgeraColors.warning;
    case TaskPriority.low:
      return OgeraColors.muted;
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateColor = taskStateColor(task.taskState);
    final icon = taskTypeIcon(task.taskType);
    final displayTitle = task.title?.isNotEmpty == true
        ? task.title!
        : task.contactPhone ?? 'Task';

    return OgeraCard(
      accent: stateColor,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type icon bubble
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: stateColor),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (task.contactName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.contactName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: OgeraColors.muted,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    StatusChip(
                      label: taskStateLabel(task.taskState, task.overdueDays),
                      tone: task.taskState == TaskState.overdue
                          ? StatusTone.danger
                          : task.taskState == TaskState.dueToday
                          ? StatusTone.warning
                          : task.taskState == TaskState.done
                          ? StatusTone.success
                          : StatusTone.info,
                      dense: true,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: taskPriorityColor(task.priority),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.priority.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: taskPriorityColor(task.priority),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scheduled time on the right
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                task.scheduledDate,
                style: const TextStyle(fontSize: 11, color: OgeraColors.muted),
              ),
              Text(
                task.scheduledTime.length >= 5
                    ? task.scheduledTime.substring(0, 5)
                    : task.scheduledTime,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
