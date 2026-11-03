/// Expenses screen.
///
/// WHAT IT SHOWS:
///   Staff role:
///     - Own expense list with status badges.
///     - Can delete pending expenses.
///   Manager/admin role:
///     - All staff expenses with approve/reject actions.
///     - Status filter chips.
///
/// DATA FLOW:
///   ExpenseViewModel → ExpenseService → GET /expenses
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/ogera_widgets.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/state_views.dart';
import '../../models/expense.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/expense_view_model.dart';
import '../../view_models/session_view_model.dart';
import 'expense_detail_sheet.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ExpenseViewModel>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExpenseViewModel>();
    final session = context.watch<SessionViewModel>();
    final isHead = session.user?.isHead == true;

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(title: const Text('Expenses')),
      body: Column(
        children: [
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: vm.statusFilter == null,
                  onTap: () => vm.setStatusFilter(null),
                ),
                const SizedBox(width: 8),
                ...ExpenseStatus.values.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: s.label,
                      selected: vm.statusFilter == s,
                      onTap: () => vm.setStatusFilter(s),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Builder(
              builder: (_) {
                if (vm.isLoading) return const LoadingListView(itemHeight: 80);
                if (vm.error != null) {
                  return ErrorStateView(
                    message: vm.error!,
                    kind: vm.errorKind ?? FailureKind.server,
                    onRetry: vm.load,
                  );
                }
                if (vm.expenses.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No expenses',
                    message: 'No expense claims found.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: vm.load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    itemCount: vm.expenses.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      final expense = vm.expenses[i];
                      return _ExpenseCard(
                        expense: expense,
                        isHead: isHead,
                        onTap: () => showExpenseDetailSheet(ctx, expense),
                        onDelete:
                            expense.status == ExpenseStatus.pending && !isHead
                            ? () => _confirmDelete(ctx, vm, expense)
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ExpenseViewModel vm,
    Expense expense,
  ) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete expense?',
      message: 'This will permanently remove "${expense.title}".',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await vm.delete(expense.id);
    if (context.mounted) {
      showToast(
        context,
        ok ? 'Expense deleted' : (vm.error ?? 'Failed'),
        isError: !ok,
      );
    }
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.isHead,
    required this.onTap,
    this.onDelete,
  });

  final Expense expense;
  final bool isHead;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final statusTone = switch (expense.status) {
      ExpenseStatus.approved => StatusTone.success,
      ExpenseStatus.rejected => StatusTone.danger,
      _ => StatusTone.warning,
    };

    return OgeraCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    StatusChip(
                      label: expense.status.label,
                      tone: statusTone,
                      dense: true,
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: expense.category.label,
                      tone: StatusTone.neutral,
                      dense: true,
                    ),
                  ],
                ),
                if (isHead && expense.employeeName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    expense.employeeName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: OgeraColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${expense.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: OgeraColors.danger,
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? OgeraColors.blue : OgeraColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? OgeraColors.blue : OgeraColors.line,
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
