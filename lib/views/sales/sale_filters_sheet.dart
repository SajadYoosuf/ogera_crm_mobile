import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/form_fields.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/sales_view_model.dart';

/// Ledger filters: the register can be narrowed by sale date.
Future<void> showSaleFilters(BuildContext context) {
  final viewModel = context.read<SalesViewModel>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: viewModel,
      child: const _SaleFiltersSheet(),
    ),
  );
}

class _SaleFiltersSheet extends StatefulWidget {
  const _SaleFiltersSheet();

  @override
  State<_SaleFiltersSheet> createState() => _SaleFiltersSheetState();
}

class _SaleFiltersSheetState extends State<_SaleFiltersSheet> {
  late String? _startDate = context.read<SalesViewModel>().startDate;
  late String? _endDate = context.read<SalesViewModel>().endDate;

  void _apply() {
    context.read<SalesViewModel>().applyFilters(
      startDate: _startDate,
      endDate: _endDate,
    );
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter sales',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OgeraDateField(
                    label: 'Sold from',
                    value: _startDate,
                    lastDate: DateTime.now(),
                    onChanged: (value) => setState(() => _startDate = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OgeraDateField(
                    label: 'Sold until',
                    value: _endDate,
                    lastDate: DateTime.now(),
                    onChanged: (value) => setState(() => _endDate = value),
                  ),
                ),
              ],
            ),
            _QuickRanges(
              onPick: (start, end) => setState(() {
                _startDate = start;
                _endDate = end;
              }),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _apply, child: const Text('Apply filters')),
          ],
        ),
      ),
    );
  }
}

class _QuickRanges extends StatelessWidget {
  const _QuickRanges({required this.onPick});

  final void Function(String start, String end) onPick;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final ranges = <String, DateTime>{
      'This month': DateTime(today.year, today.month, 1),
      'Last 90 days': today.subtract(const Duration(days: 89)),
      'This year': DateTime(today.year, 1, 1),
    };
    return Wrap(
      spacing: 8,
      children: [
        for (final entry in ranges.entries)
          ActionChip(
            label: Text(entry.key),
            onPressed: () => onPick(isoDate(entry.value), isoDate(today)),
            backgroundColor: OgeraColors.canvas,
          ),
      ],
    );
  }
}
