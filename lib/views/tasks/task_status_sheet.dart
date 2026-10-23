/// Bottom sheet to change a task's status.
///
/// WHAT IT DOES:
///   - Shows three status options: To Do, In Progress, Completed.
///   - When "Completed" is selected, shows an outcome dropdown (required
///     by the backend to log the activity correctly).
///   - Calls the view model on save and closes on success.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/ogera_widgets.dart';
import '../../services/tasks_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/tasks_view_model.dart';

// Common outcome options the team uses — backend accepts any non-empty string.
const _outcomes = [
  'Connected',
  'No answer',
  'Busy',
  'Call back later',
  'Interested',
  'Not interested',
  'Visited',
  'Demo done',
  'Other',
];

Future<void> showTaskStatusSheet(BuildContext context, Task task) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<TasksViewModel>(),
      child: _TaskStatusSheet(task: task),
    ),
  );
}

class _TaskStatusSheet extends StatefulWidget {
  const _TaskStatusSheet({required this.task});
  final Task task;

  @override
  State<_TaskStatusSheet> createState() => _TaskStatusSheetState();
}

class _TaskStatusSheetState extends State<_TaskStatusSheet> {
  late TaskStatus _selected;
  String? _outcome;
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.task.status;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _requiresOutcome => _selected == TaskStatus.completed;
  bool get _canSave =>
      !_saving && (!_requiresOutcome || (_outcome?.isNotEmpty == true));

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);

    final vm = context.read<TasksViewModel>();
    bool ok;

    if (_selected == TaskStatus.completed) {
      ok = await vm.complete(
        widget.task.id,
        outcome: _outcome!,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
    } else {
      ok = await vm.toggleStatus(widget.task.id, _selected);
    }

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      showToast(context, 'Task updated');
    } else {
      setState(() => _saving = false);
      showToast(context, vm.error ?? 'Failed to update task', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Drag handle
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
                'Change status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),

              // Status options
              ...TaskStatus.values.map(
                (s) => InkWell(
                  onTap: () => setState(() => _selected = s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selected == s
                                  ? OgeraColors.blue
                                  : OgeraColors.line,
                              width: 2,
                            ),
                          ),
                          child: _selected == s
                              ? Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: OgeraColors.blue,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(s.label, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),

              // Outcome picker (only for Completed)
              if (_requiresOutcome) ...[
                const SizedBox(height: 12),
                const Text(
                  'Outcome *',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _outcomes.map((o) {
                    final selected = _outcome == o;
                    return ChoiceChip(
                      label: Text(o, style: const TextStyle(fontSize: 13)),
                      selected: selected,
                      onSelected: (_) => setState(() => _outcome = o),
                      selectedColor: OgeraColors.blue,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
