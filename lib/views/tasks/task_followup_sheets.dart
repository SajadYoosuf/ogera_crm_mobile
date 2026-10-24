/// The "schedule the next follow-up?" step that comes after a task is completed.
///
/// FLOW (contact-linked tasks only):
///   1. [showNextFollowupPrompt] — a small card: "Follow-up marked done.
///      Schedule the next follow-up?" with Yes / Skip. Designed to match the
///      web app's FollowupPrompt card.
///   2. [showScheduleNextFollowupSheet] — only after "Yes". The contact is
///      already known from the task. The employee only picks the task type.
///      The follow-up is assigned to them and due tomorrow at 23:59 (the web
///      app's default when no time is chosen).
///   Cancel or Skip at any step ends the flow. Nothing else pops up.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/state_views.dart';
import '../../services/tasks_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/tasks_view_model.dart';
import 'task_card.dart';

/// Asks whether to book the next follow-up with [contactName].
///
/// Returns true only on "Yes, schedule". Skip, Esc, or a tap outside the card returns false.
/// The card does not dismiss itself: a timer could close it in the middle of a tap.
Future<bool> showNextFollowupPrompt(
  BuildContext context, {
  required String contactName,
}) async {
  final choice = await showDialog<bool>(
    context: context,
    builder: (_) => _NextFollowupPrompt(contactName: contactName),
  );
  return choice ?? false;
}

class _NextFollowupPrompt extends StatelessWidget {
  const _NextFollowupPrompt({required this.contactName});

  final String contactName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: OgeraColors.successSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OgeraSpacing.cardRadius),
        side: const BorderSide(color: Color(0xFFBBE5CB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: OgeraColors.success,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Follow-up marked done',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF17703F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Schedule the next follow-up with $contactName?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF1F4D33)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: OgeraColors.success,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Yes, schedule'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF17703F),
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Skip'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet that books the next follow-up for [task]'s contact.
///
/// Returns true when it is saved, otherwise null (Cancel or dismiss).
Future<bool?> showScheduleNextFollowupSheet(
  BuildContext context, {
  required Task task,
  required TasksViewModel vm,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: OgeraColors.surface,
    shape: taskSheetShape,
    builder: (_) => _ScheduleNextFollowupSheet(task: task, vm: vm),
  );
}

/// The due time used for the next follow-up: tomorrow at 23:59 (local time).
///
/// Pure function so it can be tested. Tomorrow is used because a follow-up
/// due today would already count as due the moment it is booked.
DateTime defaultNextFollowupDue(DateTime now) {
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 23, 59);
}

class _ScheduleNextFollowupSheet extends StatefulWidget {
  const _ScheduleNextFollowupSheet({required this.task, required this.vm});

  final Task task;
  final TasksViewModel vm;

  @override
  State<_ScheduleNextFollowupSheet> createState() =>
      _ScheduleNextFollowupSheetState();
}

class _ScheduleNextFollowupSheetState
    extends State<_ScheduleNextFollowupSheet> {
  /// Task types from Settings, loaded once when the sheet opens. Null while loading.
  Map<String, String>? _types;
  String? _activityType;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The service falls back to the built-in list on failure, so this always completes.
    widget.vm.taskTypes().then((types) {
      if (!mounted) return;
      setState(() {
        _types = types;
        _activityType = _initialType(types);
      });
    });
  }

  /// The completed task's type when it is in the list, otherwise the first type.
  String _initialType(Map<String, String> types) {
    if (types.containsKey(widget.task.taskType)) return widget.task.taskType;
    return types.keys.first;
  }

  Future<void> _save(String activityType) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.vm.scheduleNextFollowup(
      contactId: widget.task.contactId!,
      activityType: activityType,
      dueAt: defaultNextFollowupDue(DateTime.now()),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final contactName = widget.task.contactName ?? 'this contact';
    final due = defaultNextFollowupDue(DateTime.now());
    final types = _types;

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
              const Text(
                'Schedule follow-up',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'With $contactName, assigned to you',
                style: const TextStyle(fontSize: 13, color: OgeraColors.muted),
              ),
              const SizedBox(height: 16),
              const Text(
                'Task type',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              if (types == null)
                const ShimmerBox(height: 44)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in types.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _activityType == entry.key,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _activityType = entry.key),
                        selectedColor: OgeraColors.blue,
                        labelStyle: TextStyle(
                          color: _activityType == entry.key
                              ? Colors.white
                              : null,
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.event_rounded,
                    size: 16,
                    color: OgeraColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Due ${DateFormat('d MMM yyyy').format(due)} at 23:59',
                      style: const TextStyle(
                        fontSize: 13,
                        color: OgeraColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: OgeraColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving || _activityType == null
                          ? null
                          : () => _save(_activityType!),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Schedule'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
