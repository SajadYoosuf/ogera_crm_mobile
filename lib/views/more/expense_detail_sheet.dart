/// Expense detail + approve/reject sheet.
///
/// WHAT IT SHOWS:
///   - Full expense details (title, amount, category, status, bill photo).
///   - For manager/admin: Approve and Reject (with reason) buttons.
///   - For staff: read-only view of their own pending expense.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/ogera_widgets.dart';
import '../../models/expense.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/expense_view_model.dart';
import '../../view_models/session_view_model.dart';

Future<void> showExpenseDetailSheet(BuildContext context, Expense expense) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: context.read<ExpenseViewModel>()),
        ChangeNotifierProvider.value(value: context.read<SessionViewModel>()),
      ],
      child: _ExpenseDetailSheet(expense: expense),
    ),
  );
}

class _ExpenseDetailSheet extends StatefulWidget {
  const _ExpenseDetailSheet({required this.expense});
  final Expense expense;

  @override
  State<_ExpenseDetailSheet> createState() => _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends State<_ExpenseDetailSheet> {
  final _reasonController = TextEditingController();
  bool _showReject = false;
  bool _saving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() => _saving = true);
    final vm = context.read<ExpenseViewModel>();
    final ok = await vm.approve(widget.expense.id);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      showToast(context, 'Expense approved');
    } else {
      setState(() => _saving = false);
      showToast(context, vm.error ?? 'Failed', isError: true);
    }
  }

  Future<void> _reject() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      showToast(context, 'Enter a rejection reason', isError: true);
      return;
    }
    setState(() => _saving = true);
    final vm = context.read<ExpenseViewModel>();
    final ok = await vm.reject(widget.expense.id, reason: reason);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      showToast(context, 'Expense rejected');
    } else {
      setState(() => _saving = false);
      showToast(context, vm.error ?? 'Failed', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final canReview =
        session.user?.isHead == true; // admin/manager only
    final expense = widget.expense;

    final statusTone = switch (expense.status) {
      ExpenseStatus.approved => StatusTone.success,
      ExpenseStatus.rejected => StatusTone.danger,
      _ => StatusTone.warning,
    };

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

              Row(
                children: [
                  Expanded(
                    child: Text(
                      expense.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusChip(
                    label: expense.status.label,
                    tone: statusTone,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _Row(label: 'Amount', value: '₹${expense.amount.toStringAsFixed(2)}'),
              _Row(label: 'Category', value: expense.category.label),
              if (expense.employeeName != null)
                _Row(label: 'Submitted by', value: expense.employeeName!),
              _Row(
                label: 'Date',
                value: '${expense.createdAt.day}/${expense.createdAt.month}/${expense.createdAt.year}',
              ),
              if (expense.rejectionReason != null)
                _Row(label: 'Rejection reason', value: expense.rejectionReason!),
              if (expense.reviewedByName != null)
                _Row(
                  label: expense.status == ExpenseStatus.approved
                      ? 'Approved by'
                      : 'Rejected by',
                  value: expense.reviewedByName!,
                ),

              // Bill photo placeholder
              if (expense.billPhotoUrl != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Receipt',
                  style: TextStyle(fontSize: 13, color: OgeraColors.muted),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    expense.billPhotoUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 80,
                      color: OgeraColors.canvas,
                      alignment: Alignment.center,
                      child: const Text(
                        'Image unavailable',
                        style: TextStyle(color: OgeraColors.muted),
                      ),
                    ),
                  ),
                ),
              ],

              // Manager/admin approve/reject buttons
              if (canReview &&
                  expense.status == ExpenseStatus.pending) ...[
                const SizedBox(height: 20),
                if (!_showReject) ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: OgeraColors.success,
                          ),
                          onPressed: _saving ? null : _approve,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Approve'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: OgeraColors.danger,
                            side: const BorderSide(color: OgeraColors.danger),
                          ),
                          onPressed: () => setState(() => _showReject = true),
                          child: const Text('Reject'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  TextField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Rejection reason *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _showReject = false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: OgeraColors.danger,
                          ),
                          onPressed: _saving ? null : _reject,
                          child: const Text('Confirm Reject'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: OgeraColors.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
