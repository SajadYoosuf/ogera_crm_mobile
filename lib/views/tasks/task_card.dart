/// A single task list item card.
///
/// WHAT IT SHOWS:
///   - Task type icon in a coloured circle
///   - Title (or phone if no title), contact name
///   - Scheduled date + time, overdue badge
///   - Priority badge
///   - Tap to open the status-change sheet
library;

import 'package:flutter/material.dart';

import '../../core/widgets/ogera_widgets.dart';
import '../../services/tasks_service.dart';
import '../../theme/ogera_colors.dart';

// ── Icon helpers ─────────────────────────────────────────────────────────────

IconData _typeIcon(String type) {
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

Color _stateColor(TaskState state) {
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

String _stateLabel(TaskState state, int overdueDays) {
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

Color _priorityColor(TaskPriority p) {
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
  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
  });

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stateColor = _stateColor(task.taskState);
    final icon = _typeIcon(task.taskType);
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
                      label: _stateLabel(task.taskState, task.overdueDays),
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
                        color: _priorityColor(task.priority),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.priority.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: _priorityColor(task.priority),
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
