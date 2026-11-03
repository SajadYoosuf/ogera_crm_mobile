/// Bottom sheets for the pipeline lead screen: schedule a follow-up, and mark one done.
///
/// Both sheets follow the same pattern as the Home quick-action sheets:
///   1. Check the form locally, so the user sees the problem next to the field.
///   2. Call the view model, which calls the API.
///   3. On success, pop with `true` so the screen can show a confirmation.
///   4. On failure, stay open and show the message inline.
///
/// The sheets are only opened for leads the employee owns (see
/// [LeadWorkViewModel.canWrite]), and the view model checks that again.
library;

import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../models/activity_log.dart';
import '../../models/lead_work.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/lead_work_view_model.dart';

// ───────────────────────────────────────────────────────── schedule follow-up

/// Books one follow-up for the signed-in employee.
///
/// With no time chosen, the follow-up is due for the whole day (23:59), the
/// same default the web app uses.
class ScheduleFollowupSheet extends StatefulWidget {
  const ScheduleFollowupSheet({
    super.key,
    required this.viewModel,
    required this.contactName,
  });

  final LeadWorkViewModel viewModel;
  final String contactName;

  @override
  State<ScheduleFollowupSheet> createState() => _ScheduleFollowupSheetState();
}

class _ScheduleFollowupSheetState extends State<ScheduleFollowupSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  late final DateTime _today;
  late DateTime _date;
  TimeOfDay? _time;
  String _channel = 'phone_call';
  String? _error;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _date = _today;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Activity types a follow-up can use. Internal notes cannot be scheduled.
  Map<String, String> get _types => {
    for (final entry in widget.viewModel.activityTypeLabels.entries)
      if (entry.key != 'internal_note') entry.key: entry.value,
  };

  /// The selected type, or the first available one if the list has changed.
  String get _selectedChannel {
    final types = _types;
    if (types.containsKey(_channel)) return _channel;
    return types.isEmpty ? _channel : types.keys.first;
  }

  /// The due moment: the chosen date, at the chosen time or the end of the day.
  DateTime get _dueAt => DateTime(
    _date.year,
    _date.month,
    _date.day,
    _time?.hour ?? 23,
    _time?.minute ?? 59,
  );

  /// Why the chosen date or time cannot be used, or null when it is fine.
  String? _timingProblem(DateTime now) {
    if (_date.isBefore(_today)) return 'The due date cannot be in the past.';
    if (_time != null && _dueAt.isBefore(now)) {
      return 'That time has already passed today. Pick a later time.';
    }
    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 365 * 2)),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
  }

  Future<void> _save() async {
    final assignee = widget.viewModel.currentUserId;
    if (assignee == null) {
      setState(() => _error = 'Sign in again to schedule a follow-up.');
      return;
    }
    final problem = _timingProblem(DateTime.now());
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    final message = await widget.viewModel.scheduleFollowup(
      FollowupDraft(
        channel: _selectedChannel,
        dueAt: _dueAt,
        assignedTo: assignee,
        title: _titleController.text,
        notes: _notesController.text,
      ),
    );
    if (!mounted) return;
    if (message != null) {
      setState(() {
        _isSaving = false;
        _error = message;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final types = _types;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Schedule follow-up',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            widget.contactName,
            style: const TextStyle(fontSize: 13, color: OgeraColors.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            enabled: !_isSaving,
            decoration: const InputDecoration(
              labelText: 'Task name (optional)',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: types.containsKey(_selectedChannel)
                ? _selectedChannel
                : null,
            decoration: const InputDecoration(labelText: 'Activity type'),
            items: [
              for (final entry in types.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _isSaving
                ? null
                : (value) => setState(() => _channel = value ?? _channel),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickDate,
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(formatFullDate(_date)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _pickTime,
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(
                    _time == null ? 'Whole day' : _time!.format(context),
                  ),
                ),
              ),
              if (_time != null)
                IconButton(
                  tooltip: 'Clear time',
                  onPressed: _isSaving
                      ? null
                      : () => setState(() => _time = null),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: OgeraColors.muted,
              ),
              SizedBox(width: 8),
              Text(
                'Assigned to you',
                style: TextStyle(fontSize: 13.5, color: OgeraColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            enabled: !_isSaving,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: OgeraColors.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? 'Saving…' : 'Schedule follow-up'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── mark follow-up done

/// Closes one open follow-up with an outcome and a note of what happened.
/// The server writes the activity row, so it appears in the Activity log tab.
class CompleteFollowupSheet extends StatefulWidget {
  const CompleteFollowupSheet({
    super.key,
    required this.viewModel,
    required this.item,
    required this.typeLabel,
  });

  final LeadWorkViewModel viewModel;
  final FollowupEntry item;

  /// The label for the follow-up's activity type, e.g. "Phone call".
  final String typeLabel;

  @override
  State<CompleteFollowupSheet> createState() => _CompleteFollowupSheetState();
}

class _CompleteFollowupSheetState extends State<CompleteFollowupSheet> {
  final _notesController = TextEditingController();

  ActivityOutcome _outcome = ActivityOutcome.done;
  String? _error;
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_notesController.text.trim().isEmpty) {
      setState(() => _error = 'Write what happened.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final message = await widget.viewModel.completeFollowup(
      widget.item,
      outcome: _outcome.value,
      notes: _notesController.text,
    );
    if (!mounted) return;
    if (message != null) {
      setState(() {
        _isSaving = false;
        _error = message;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item.title?.trim();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Mark follow-up done',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            (title == null || title.isEmpty) ? widget.typeLabel : title,
            style: const TextStyle(fontSize: 13, color: OgeraColors.muted),
          ),
          const SizedBox(height: 16),
          const Text(
            'Outcome',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final outcome in ActivityOutcome.values)
                ChoiceChip(
                  label: Text(outcome.label),
                  selected: _outcome == outcome,
                  onSelected: _isSaving
                      ? null
                      : (_) => setState(() => _outcome = outcome),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            enabled: !_isSaving,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'What happened?',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: OgeraColors.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? 'Saving…' : 'Mark done'),
          ),
        ],
      ),
    );
  }
}
