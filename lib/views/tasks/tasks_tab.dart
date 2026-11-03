/// Tasks tab — shows the signed-in user's follow-up tasks.
///
/// WHAT IT SHOWS:
///   - A horizontal 14-day calendar strip (3 days back, 10 forward). Tap a day to filter.
///   - Two dropdowns: Status (All active · To Do · In Progress · Completed)
///     and Priority (All · Low · Medium · High).
///   - A list of task cards. Tap one to open the task detail sheet
///     (task_detail_sheet.dart), where you change status or complete it.
///   - An overdue count badge in the app bar.
///
/// ONLY YOUR TASKS:
///   The list is always filtered to the signed-in employee (see TasksService.list).
///
/// DATA FLOW:
///   TasksTab → TasksViewModel → TasksService → GET /tasks
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/state_views.dart';
import '../../services/tasks_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/tasks_view_model.dart';
import 'task_card.dart';
import 'task_detail_sheet.dart';

class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  @override
  void initState() {
    super.initState();
    // Load after the first frame so the Provider tree is ready.
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
        onRefresh: () => vm.load(),
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
            ..._bodySlivers(context, vm),
          ],
        ),
      ),
    );
  }

  /// The list area. Shows exactly one of: loading, error, empty, or the tasks.
  List<Widget> _bodySlivers(BuildContext context, TasksViewModel vm) {
    if (vm.isLoading) {
      return const [
        SliverFillRemaining(child: LoadingListView(itemHeight: 84)),
      ];
    }

    // A failed load only replaces the list when there is nothing to show.
    // If tasks are already on screen, keep them and show a banner instead.
    if (vm.error != null && vm.tasks.isEmpty) {
      return [
        SliverFillRemaining(
          child: ErrorStateView(message: vm.error!, onRetry: () => vm.load()),
        ),
      ];
    }

    if (vm.tasks.isEmpty) {
      return const [
        SliverFillRemaining(
          child: EmptyStateView(
            icon: Icons.check_circle_outline_rounded,
            title: 'No tasks',
            message: 'No tasks for this date and filter.',
          ),
        ),
      ];
    }

    return [
      if (vm.error != null)
        SliverToBoxAdapter(child: _RefreshErrorBanner(message: vm.error!)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((ctx, i) {
            final task = vm.tasks[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TaskCard(
                task: task,
                onTap: () => openTaskDetail(ctx, task),
              ),
            );
          }, childCount: vm.tasks.length),
        ),
      ),
    ];
  }
}

// ── Calendar strip ────────────────────────────────────────────────────────────

class _CalendarStrip extends StatelessWidget {
  const _CalendarStrip({required this.selected, required this.onTap});

  final DateTime selected;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    // Show 14 days, starting 3 days ago so context is clear.
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

// ── Filter dropdowns ─────────────────────────────────────────────────────────

/// The Status and Priority dropdowns, side by side.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.vm});

  final TasksViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _FilterDropdown<TaskStatusFilter>(
              label: 'Status',
              value: vm.statusFilter,
              items: [
                for (final filter in TaskStatusFilter.values)
                  DropdownMenuItem(value: filter, child: Text(filter.label)),
              ],
              onChanged: (filter) {
                if (filter != null) vm.setStatusFilter(filter);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FilterDropdown<TaskPriority?>(
              label: 'Priority',
              value: vm.priorityFilter,
              items: [
                const DropdownMenuItem<TaskPriority?>(
                  value: null,
                  child: Text('All priorities'),
                ),
                for (final priority in TaskPriority.values)
                  DropdownMenuItem<TaskPriority?>(
                    value: priority,
                    child: Text(priority.label),
                  ),
              ],
              onChanged: vm.setPriorityFilter,
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled dropdown in the app's card style.
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: OgeraColors.muted),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: OgeraColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OgeraColors.line),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: OgeraColors.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Banners and badges ───────────────────────────────────────────────────────

/// Shown above the list when a background refresh fails but old tasks are still on screen.
class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: OgeraColors.dangerSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: OgeraColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: OgeraColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

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
