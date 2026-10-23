/// Bottom sheet to reschedule a task.
///
/// WHAT IT DOES:
///   - Shows a date picker and a time picker.
///   - Calls view model reschedule() with the combined ISO datetime.
///
/// BACKEND RULE:
///   due_at must not be in the past (within 5 minutes grace period).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/ogera_widgets.dart';
import '../../services/tasks_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/tasks_view_model.dart';

Future<void> showTaskRescheduleSheet(BuildContext context, Task task) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<TasksViewModel>(),
      child: _TaskRescheduleSheet(task: task),
    ),
  );
}

class _TaskRescheduleSheet extends StatefulWidget {
  const _TaskRescheduleSheet({required this.task});
  final Task task;

  @override
  State<_TaskRescheduleSheet> createState() => _TaskRescheduleSheetState();
}

class _TaskRescheduleSheetState extends State<_TaskRescheduleSheet> {
  late DateTime _date;
  late TimeOfDay _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final at = widget.task.scheduledAt;
    _date = DateTime(at.year, at.month, at.day);
    _time = TimeOfDay(hour: at.hour, minute: at.minute);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _date.isBefore(now) ? now : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  String get _isoDateTime {
    final dt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    return dt.toIso8601String();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final vm = context.read<TasksViewModel>();
    final ok = await vm.reschedule(widget.task.id, _isoDateTime);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      showToast(context, 'Task rescheduled');
    } else {
      setState(() => _saving = false);
      showToast(context, vm.error ?? 'Failed to reschedule', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${_date.day.toString().padLeft(2, '0')} / ${_date.month.toString().padLeft(2, '0')} / ${_date.year}';
    final timeStr = _time.format(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
              'Reschedule task',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),

            // Date row
            OgeraCard(
              onTap: _pickDate,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: OgeraColors.blue,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Date',
                    style: TextStyle(color: OgeraColors.muted, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: OgeraColors.muted,
                    size: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Time row
            OgeraCard(
              onTap: _pickTime,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: OgeraColors.blue,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Time',
                    style: TextStyle(color: OgeraColors.muted, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: OgeraColors.muted,
                    size: 18,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Reschedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
