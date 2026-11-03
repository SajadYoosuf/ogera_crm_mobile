import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/reference/crm_options.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_fields.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/contacts_view_model.dart';

/// Source and date-range filters for the contacts list. Held in a sheet rather
/// than a filter bar so the list itself stays uncluttered on a phone.
Future<void> showContactFilters(BuildContext context) {
  final viewModel = context.read<ContactsViewModel>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: viewModel,
      child: const _ContactFiltersSheet(),
    ),
  );
}

class _ContactFiltersSheet extends StatefulWidget {
  const _ContactFiltersSheet();

  @override
  State<_ContactFiltersSheet> createState() => _ContactFiltersSheetState();
}

class _ContactFiltersSheetState extends State<_ContactFiltersSheet> {
  late String? _source = context.read<ContactsViewModel>().source;
  late String? _startDate = context.read<ContactsViewModel>().startDate;
  late String? _endDate = context.read<ContactsViewModel>().endDate;

  // Lead sources from the server, as {slug: name}. Null until they load, so the
  // picker waits instead of showing a made-up list.
  Map<String, String>? _sourceLabels;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  /// Fetches the active lead sources once when the sheet opens.
  Future<void> _loadSources() async {
    final labels = await context.read<ContactsService>().leadSourceOptions();
    if (!mounted) return;
    setState(() => _sourceLabels = labels);
  }

  /// The name for a stored slug. Uses the server's name when it is listed, and
  /// the built-in label for a slug the server no longer lists.
  String _sourceName(String slug) =>
      _sourceLabels?[slug] ?? CrmOptions.sourceLabel(slug);

  void _apply() {
    context.read<ContactsViewModel>().applyFilters(
      source: _source,
      startDate: _startDate,
      endDate: _endDate,
      clearSource: _source == null,
      clearDates: _startDate == null && _endDate == null,
    );
    Navigator.of(context).pop();
  }

  void _reset() {
    setState(() {
      _source = null;
      _startDate = null;
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
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
                    'Filter contacts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
            const SizedBox(height: 14),
            OgeraPickerField(
              label: 'Source',
              icon: Icons.input_rounded,
              value: _source == null ? null : _sourceName(_source!),
              placeholder: 'Any source',
              onClear: () => setState(() => _source = null),
              onTap: () async {
                final labels = _sourceLabels;
                // Still loading: nothing to pick yet.
                if (labels == null) return;
                final picked = await showOptionPicker<String>(
                  context,
                  title: 'Source',
                  options: labels.keys.toList(),
                  labelOf: _sourceName,
                  selected: _source,
                  searchable: false,
                );
                if (picked != null) setState(() => _source = picked);
              },
            ),
            Row(
              children: [
                Expanded(
                  child: OgeraDateField(
                    label: 'Added from',
                    value: _startDate,
                    lastDate: DateTime.now(),
                    onChanged: (value) => setState(() => _startDate = value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OgeraDateField(
                    label: 'Added until',
                    value: _endDate,
                    lastDate: DateTime.now(),
                    onChanged: (value) => setState(() => _endDate = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
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

/// The three ranges a sales head actually asks for, one tap each.
class _QuickRanges extends StatelessWidget {
  const _QuickRanges({required this.onPick});

  final void Function(String start, String end) onPick;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final ranges = <String, DateTime>{
      'Last 7 days': today.subtract(const Duration(days: 6)),
      'Last 30 days': today.subtract(const Duration(days: 29)),
      'This month': DateTime(today.year, today.month, 1),
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
