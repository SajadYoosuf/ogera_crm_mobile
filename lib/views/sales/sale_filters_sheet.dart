import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/reference/crm_options.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_fields.dart';
import '../../models/sale.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/sales_view_model.dart';

/// Ledger filters. Applying them also recomputes the summary totals, because
/// the API derives revenue and tanks from the same WHERE clause.
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
  late final _wardController = TextEditingController(
    text: context.read<SalesViewModel>().ward,
  );

  late String? _panchayath = context.read<SalesViewModel>().panchayath;
  late String? _waterSource = context.read<SalesViewModel>().waterSource;
  late String? _sourceOfSale = context.read<SalesViewModel>().sourceOfSale;
  late String? _startDate = context.read<SalesViewModel>().startDate;
  late String? _endDate = context.read<SalesViewModel>().endDate;

  @override
  void dispose() {
    _wardController.dispose();
    super.dispose();
  }

  void _apply() {
    final ward = _wardController.text.trim();
    context.read<SalesViewModel>().applyFilters(
      panchayath: _panchayath,
      ward: ward.isEmpty ? null : ward,
      waterSource: _waterSource,
      sourceOfSale: _sourceOfSale,
      startDate: _startDate,
      endDate: _endDate,
    );
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _panchayath = null;
      _waterSource = null;
      _sourceOfSale = null;
      _startDate = null;
      _endDate = null;
      _wardController.clear();
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
            OgeraPickerField(
              label: 'Panchayath',
              icon: Icons.location_city_outlined,
              value: _panchayath,
              placeholder: 'Any panchayath',
              onClear: () => setState(() => _panchayath = null),
              onTap: () async {
                final picked = await showOptionPicker<String>(
                  context,
                  title: 'Panchayath',
                  options: CrmOptions.panchayaths,
                  labelOf: (value) => value,
                  selected: _panchayath,
                  searchHint: 'Search panchayath',
                );
                if (picked != null) setState(() => _panchayath = picked);
              },
            ),
            OgeraTextField(
              label: 'Ward',
              controller: _wardController,
              icon: Icons.numbers_rounded,
              maxLength: 100,
            ),
            OgeraPickerField(
              label: 'Water source',
              icon: Icons.water_rounded,
              value: _waterSource == null
                  ? null
                  : SaleOptions.label(SaleOptions.waterSources, _waterSource),
              placeholder: 'Any water source',
              onClear: () => setState(() => _waterSource = null),
              onTap: () async {
                final picked = await showOptionPicker<String>(
                  context,
                  title: 'Water source',
                  options: SaleOptions.waterSources.keys.toList(
                    growable: false,
                  ),
                  labelOf: (key) => SaleOptions.waterSources[key] ?? key,
                  selected: _waterSource,
                  searchable: false,
                );
                if (picked != null) setState(() => _waterSource = picked);
              },
            ),
            OgeraPickerField(
              label: 'Source of sale',
              icon: Icons.input_rounded,
              value: _sourceOfSale == null
                  ? null
                  : SaleOptions.label(SaleOptions.sourcesOfSale, _sourceOfSale),
              placeholder: 'Any source',
              onClear: () => setState(() => _sourceOfSale = null),
              onTap: () async {
                final picked = await showOptionPicker<String>(
                  context,
                  title: 'Source of sale',
                  options: SaleOptions.sourcesOfSale.keys.toList(
                    growable: false,
                  ),
                  labelOf: (key) => SaleOptions.sourcesOfSale[key] ?? key,
                  selected: _sourceOfSale,
                  searchable: false,
                );
                if (picked != null) setState(() => _sourceOfSale = picked);
              },
            ),
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
