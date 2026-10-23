/// Tasks tab — shows the user's scheduled follow-up tasks.
///
/// WHAT IT SHOWS:
///   - A horizontal 7-day calendar strip: tap a day to filter.
///   - Status chips: Open · In Progress · Completed (tapping filters).
///   - Priority chips: Low · Medium · High.
///   - A list of task cards (each tappable to change status or reschedule).
///   - Summary counts badge (overdue, today, upcoming) in the app bar.
///
/// DATA FLOW:
///   TasksViewModel (loaded here) → TasksService → GET /tasks
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/state_views.dart';
import '../../services/tasks_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/tasks_view_model.dart';
import 'task_card.dart';
import 'task_reschedule_sheet.dart';
import 'task_status_sheet.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  @override
  void initState() {
    super.initState();
    // Load after first frame so the Provider tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TasksViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TasksViewModel>();

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          if (vm.summary != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _SummaryBadge(summary: vm.summary!),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CalendarStrip(
                    selected: vm.selectedDate,
                    onTap: vm.selectDate,
                  ),
                  const SizedBox(height: 8),
                  _FilterBar(vm: vm),
                  const SizedBox(height: 4),
                ],
              ),
            ),

            if (vm.isLoading)
              const SliverFillRemaining(
                child: LoadingListView(itemHeight: 84),
              )
            else if (vm.error != null)
              SliverFillRemaining(
                child: ErrorStateView(
                  message: vm.error!,
                  onRetry: vm.load,
                ),
              )
            else if (vm.tasks.isEmpty)
              const SliverFillRemaining(
                child: EmptyStateView(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'No tasks',
                  message: 'No tasks for this date and filter.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final task = vm.tasks[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TaskCard(
                          task: task,
                          onTap: () => _onTaskTap(ctx, task),
                        ),
                      );
                    },
                    childCount: vm.tasks.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onTaskTap(BuildContext context, Task task) {
    if (task.taskState == TaskState.done) {
      // Completed tasks can only be rescheduled (not status-changed).
      showTaskRescheduleSheet(context, task);
    } else {
      _showActionMenu(context, task);
    }
  }

  void _showActionMenu(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<TasksViewModel>(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: OgeraColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded, color: OgeraColors.blue),
                  title: const Text('Change status'),
                  onTap: () {
                    Navigator.pop(context);
                    showTaskStatusSheet(context, task);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.schedule_rounded, color: OgeraColors.info),
                  title: const Text('Reschedule'),
                  onTap: () {
                    Navigator.pop(context);
                    showTaskRescheduleSheet(context, task);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Calendar strip ────────────────────────────────────────────────────────────

class _CalendarStrip extends StatelessWidget {
  const _CalendarStrip({required this.selected, required this.onTap});

  final DateTime selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    // Show 7 days starting from 3 days ago so context is clear.
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 3));
    final days = List.generate(14, (i) => start.add(Duration(days: i)));

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        separatorBuilder: (context, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final day = days[i];
          final isSelected = isoDate(day) == isoDate(selected);
          final isToday = isoDate(day) == isoDate(today);

          return GestureDetector(
            onTap: () => onTap(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? OgeraColors.blue
                    : isToday
                        ? OgeraColors.blueSoft
                        : OgeraColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isToday && !isSelected
                      ? OgeraColors.blue
                      : Colors.transparent,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayShort(day.weekday),
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white70 : OgeraColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _weekdayShort(int weekday) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[(weekday - 1) % 7];
  }
}

// ── Filter chips bar ──────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.vm});
  final TasksViewModel vm;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Status filters
          _Chip(
            label: 'Open',
            selected: vm.statusFilter == null || vm.statusFilter == 'open',
            onTap: () => vm.setStatusFilter(null),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'In Progress',
            selected: vm.statusFilter == 'inprogress',
            onTap: () => vm.setStatusFilter('inprogress'),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Completed',
            selected: vm.statusFilter == 'completed',
            onTap: () => vm.setStatusFilter('completed'),
          ),
          const SizedBox(width: 16),
          // Priority filters
          ...TaskPriority.values.map(
            (p) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Chip(
                label: p.label,
                selected: vm.priorityFilter == p,
                onTap: () => vm.setPriorityFilter(p),
                color: p == TaskPriority.high
                    ? OgeraColors.danger
                    : p == TaskPriority.medium
                        ? OgeraColors.warning
                        : OgeraColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? OgeraColors.blue;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? activeColor : OgeraColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : OgeraColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : null,
          ),
        ),
      ),
    );
  }
}

// ── Summary badge ─────────────────────────────────────────────────────────────

class _SummaryBadge extends StatelessWidget {
  const _SummaryBadge({required this.summary});
  final TaskSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.overdue == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: OgeraColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${summary.overdue} overdue',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: OgeraColors.danger,
        ),
      ),
    );
  }
}
