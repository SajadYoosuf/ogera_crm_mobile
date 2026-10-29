/// Task detail bottom sheet — opened by tapping a task on the Tasks tab or the Home tab.
///
/// WHAT IT SHOWS (top to bottom):
///   1. Task name, contact, scheduled date and time, priority, state.
///   2. Status: To Do / In Progress / Completed. Choosing Completed reveals
///    the completion fields below; To Do and In Progress use "Save status".
///   3. Completion (shown when Completed is selected):
///        - Outcome: Done / Not now / No answer (required)
///        - Task type actually used (required, pre-selected)
///        - What was done (required note)
///   4. Reschedule.
///
/// FLOW AFTER COMPLETING (see [openTaskDetail]):
///   The sheet closes → a toast confirms → for a contact-linked task the
///   "Schedule the next follow-up?" card appears (task_followup_sheets.dart).
///
/// WHY ONE ENTRY POINT:
///   Both screens call [openTaskDetail], so a task behaves the same way
///   wherever it is tapped.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../services/tasks_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/tasks_view_model.dart';
import 'task_card.dart';
import 'task_followup_sheets.dart';
import 'task_reschedule_sheet.dart';

/// What the user did in the detail sheet. The caller reacts to it.
enum TaskDetailAction { statusChanged, completed, reschedule }

/// Opens the detail sheet for [task] and runs the follow-up steps that come after it.
///
/// Returns the action taken, or null if the user just closed the sheet.
/// Callers can use the result to refresh their own lists.
Future<TaskDetailAction?> openTaskDetail(
  BuildContext context,
  Task task,
) async {
  final vm = context.read<TasksViewModel>();
  final action = await showModalBottomSheet<TaskDetailAction>(
    context: context,
    isScrollControlled: true,
    backgroundColor: OgeraColors.surface,
    shape: taskSheetShape,
    // Sheets live above the page's providers, so the view model is passed in explicitly.
    builder: (_) => ChangeNotifierProvider.value(
      value: vm,
      child: _TaskDetailSheet(task: task),
    ),
  );
  if (action == null || !context.mounted) return action;

  switch (action) {
    case TaskDetailAction.statusChanged:
      showToast(context, 'Status updated');
    case TaskDetailAction.reschedule:
      await showTaskRescheduleSheet(context, task);
    case TaskDetailAction.completed:
      showToast(context, 'Task completed');
      // Standalone tasks have no contact, so there is nothing to follow up with.
      if (task.contactId == null) break;
      final wantsNext = await showNextFollowupPrompt(
        context,
        contactName: task.contactName ?? 'this contact',
      );
      if (!wantsNext || !context.mounted) break;
      final booked = await showScheduleNextFollowupSheet(
        context,
        task: task,
        vm: vm,
      );
      if (booked == true && context.mounted) {
        showToast(context, 'Follow-up scheduled');
      }
  }
  return action;
}

class _TaskDetailSheet extends StatefulWidget {
  const _TaskDetailSheet({required this.task});

  final Task task;

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  /// Status the user has picked. Starts at the task's current status.
  late TaskStatus _status;

  TaskOutcome? _outcome;
  String? _outcomeError;

  /// Task types from Settings. Null while loading.
  Map<String, String>? _types;
  String? _activityType;

  final _noteController = TextEditingController();
  String? _noteError;

  /// True while a save is running. Disables the buttons so a double tap cannot send twice.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = widget.task.status == TaskStatus.completed
        ? TaskStatus.todo
        : widget.task.status;
    // Loads the Settings list once. The service falls back to the built-in list on failure.
    context.read<TasksViewModel>().taskTypes().then((types) {
      if (!mounted) return;
      setState(() {
        _types = types;
        _activityType = types.containsKey(widget.task.taskType)
            ? widget.task.taskType
            : types.keys.first;
      });
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveStatus() async {
    setState(() => _busy = true);
    final error = await context.read<TasksViewModel>().updateStatus(
      widget.task,
      _status,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, TaskDetailAction.statusChanged);
    } else {
      setState(() => _busy = false);
      showToast(context, error, isError: true);
    }
  }

  Future<void> _complete() async {
    final note = _noteController.text.trim();
    final outcome = _outcome;
    final activityType = _activityType;

    // Show every missing field at once rather than one per tap.
    setState(() {
      _outcomeError = outcome == null ? 'Pick what happened.' : null;
      _noteError = note.isEmpty ? 'Write what was done.' : null;
    });
    if (outcome == null || activityType == null || note.isEmpty) return;

    setState(() => _busy = true);
    final error = await context.read<TasksViewModel>().complete(
      widget.task,
      outcome: outcome,
      notes: note,
      activityType: activityType,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, TaskDetailAction.completed);
    } else {
      setState(() => _busy = false);
      showToast(context, error, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final statusChanged = _status != task.status;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              _Header(task: task),
              const SizedBox(height: 16),
              if (task.isDone)
                const _CompletedNotice()
              else ...[
                const _SectionTitle('Status'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<TaskStatus>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: TaskStatus.todo,
                        label: Text('To Do'),
                      ),
                      ButtonSegment(
                        value: TaskStatus.inProgress,
                        label: Text('In Progress'),
                      ),
                      ButtonSegment(
                        value: TaskStatus.completed,
                        label: Text('Completed'),
                      ),
                    ],
                    selected: {_status},
                    onSelectionChanged: _busy
                        ? null
                        : (picked) => setState(() => _status = picked.first),
                  ),
                ),
                if (_status == TaskStatus.completed) ...[
                  const Divider(height: 32),
                  const _SectionTitle('Mark as completed'),
                  const SizedBox(height: 12),
                  _outcomePicker(),
                  const SizedBox(height: 16),
                  _typePicker(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    enabled: !_busy,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) {
                      if (_noteError != null) setState(() => _noteError = null);
                    },
                    decoration: InputDecoration(
                      labelText: 'What was done?',
                      hintText: 'e.g. Spoke to the owner, quote by Friday',
                      errorText: _noteError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy || _activityType == null
                          ? null
                          : _complete,
                      child: _busy
                          ? const _Spinner()
                          : const Text('Mark completed'),
                    ),
                  ),
                ] else ...[
                  if (statusChanged) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _busy ? null : _saveStatus,
                        child: const Text('Save status'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => Navigator.pop(
                              context,
                              TaskDetailAction.reschedule,
                            ),
                      icon: const Icon(Icons.schedule_rounded, size: 18),
                      label: const Text('Reschedule'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Done / Not now / No answer. The backend only accepts these three.
  Widget _outcomePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('What happened?'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final outcome in TaskOutcome.values)
              ChoiceChip(
                label: Text(outcome.label),
                selected: _outcome == outcome,
                onSelected: _busy
                    ? null
                    : (_) => setState(() {
                        _outcome = outcome;
                        _outcomeError = null;
                      }),
                selectedColor: OgeraColors.blue,
                labelStyle: TextStyle(
                  color: _outcome == outcome ? Colors.white : null,
                ),
              ),
          ],
        ),
        if (_outcomeError != null) ...[
          const SizedBox(height: 6),
          Text(
            _outcomeError!,
            style: const TextStyle(
              fontSize: 12,
              color: OgeraColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  /// Task type actually used, from the Settings list.
  Widget _typePicker() {
    final types = _types;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Task type'),
        const SizedBox(height: 8),
        if (types == null)
          const ShimmerBox(height: 40)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in types.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _activityType == entry.key,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _activityType = entry.key),
                  selectedColor: OgeraColors.blue,
                  labelStyle: TextStyle(
                    color: _activityType == entry.key ? Colors.white : null,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

// ── Pieces ───────────────────────────────────────────────────────────────────

/// Task name, contact, when it is due, and the priority and state chips.
class _Header extends StatelessWidget {
  const _Header({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final stateColor = taskStateColor(task.taskState);
    final name = task.title?.isNotEmpty == true
        ? task.title!
        : humanizeSlug(task.taskType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                taskTypeIcon(task.taskType),
                size: 19,
                color: stateColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (task.contactName != null)
          _InfoRow(
            icon: Icons.person_outline_rounded,
            text: task.contactPhone == null
                ? task.contactName!
                : '${task.contactName} · ${task.contactPhone}',
          ),
        _InfoRow(icon: Icons.event_rounded, text: _whenLabel(task.scheduledAt)),
        if (task.notes?.isNotEmpty == true)
          _InfoRow(icon: Icons.notes_rounded, text: task.notes!),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            StatusChip(
              label: taskStateLabel(task.taskState, task.overdueDays),
              color: stateColor,
              dense: true,
            ),
            StatusChip(
              label: '${task.priority.label} priority',
              color: taskPriorityColor(task.priority),
              dense: true,
            ),
          ],
        ),
      ],
    );
  }

  /// "Mon, 26 Oct 2026 · 10:30"
  String _whenLabel(DateTime when) {
    return '${DateFormat('EEE, d MMM yyyy').format(when)} · ${formatTime(when)}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: OgeraColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: OgeraColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedNotice extends StatelessWidget {
  const _CompletedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OgeraColors.successSoft,
        borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: OgeraColors.success),
          SizedBox(width: 8),
          Text(
            'This task is completed.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}
