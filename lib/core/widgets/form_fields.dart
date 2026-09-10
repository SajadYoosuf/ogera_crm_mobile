import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/ogera_colors.dart';
import '../utils/formatters.dart';
import 'ogera_widgets.dart';

/// Form primitives shared by the contact, professional, and sale forms.

class OgeraTextField extends StatelessWidget {
  const OgeraTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.required = false,
    this.inputFormatters,
    this.textInputAction,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool required;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        maxLines: maxLines,
        maxLength: maxLength,
        enabled: enabled,
        validator: validator,
        onChanged: onChanged,
        inputFormatters: inputFormatters,
        textInputAction: textInputAction,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          counterText: '',
          alignLabelWithHint: maxLines > 1,
          prefixIcon: icon == null ? null : Icon(icon, size: 19),
        ),
      ),
    );
  }
}

/// A tap-to-open field. Used for anything with more than a handful of options,
/// or where the value is produced by a sheet rather than typed.
class OgeraPickerField extends StatelessWidget {
  const OgeraPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.placeholder = 'Select',
    this.onClear,
    this.required = false,
    this.errorText,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final IconData? icon;
  final String placeholder;
  final VoidCallback? onClear;
  final bool required;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasValue = (value ?? '').trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: required ? '$label *' : label,
            errorText: errorText,
            prefixIcon: icon == null ? null : Icon(icon, size: 19),
            suffixIcon: hasValue && onClear != null
                ? IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: onClear,
                  )
                : const Icon(Icons.expand_more_rounded, size: 22),
          ),
          isEmpty: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              hasValue ? value! : placeholder,
              style: TextStyle(
                fontSize: 15,
                color: hasValue ? OgeraColors.ink : const Color(0xFF9BAAB8),
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two or three mutually exclusive choices, shown inline rather than hidden
/// behind a dropdown.
class OgeraSegmentedField<T> extends StatelessWidget {
  const OgeraSegmentedField({
    super.key,
    required this.label,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.iconOf,
  });

  final String label;
  final List<T> values;
  final String Function(T) labelOf;
  final IconData? Function(T)? iconOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: OgeraColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
              border: Border.all(color: OgeraColors.line),
            ),
            child: Row(
              children: [
                for (final value in values)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: value == selected
                              ? OgeraColors.blue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (iconOf?.call(value) != null) ...[
                              Icon(
                                iconOf!(value),
                                size: 16,
                                color: value == selected
                                    ? Colors.white
                                    : OgeraColors.muted,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                labelOf(value),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: value == selected
                                      ? Colors.white
                                      : OgeraColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OgeraDateField extends StatelessWidget {
  const OgeraDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.allowClear = true,
    this.icon = Icons.event_rounded,
  });

  /// ISO `YYYY-MM-DD`, the only date format that crosses the API.
  final String? value;
  final String label;
  final ValueChanged<String?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool allowClear;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final parsed = value == null ? null : DateTime.tryParse(value!);
    return OgeraPickerField(
      label: label,
      icon: icon,
      placeholder: 'Select a date',
      value: parsed == null ? null : formatFullDate(parsed),
      onClear: allowClear && parsed != null ? () => onChanged(null) : null,
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: parsed ?? DateTime.now(),
          firstDate: firstDate ?? DateTime(2015),
          lastDate:
              lastDate ?? DateTime.now().add(const Duration(days: 365 * 3)),
        );
        if (picked != null) onChanged(isoDate(picked));
      },
    );
  }
}

/// A searchable single-select sheet. Long option lists (panchayaths, districts)
/// are unusable as dropdowns on a phone, so they open this instead.
Future<T?> showOptionPicker<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  T? selected,
  String searchHint = 'Search',
  bool searchable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _OptionPickerSheet<T>(
      title: title,
      options: options,
      labelOf: labelOf,
      selected: selected,
      searchHint: searchHint,
      searchable: searchable,
    ),
  );
}

class _OptionPickerSheet<T> extends StatefulWidget {
  const _OptionPickerSheet({
    required this.title,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.searchHint,
    required this.searchable,
  });

  final String title;
  final List<T> options;
  final String Function(T) labelOf;
  final T? selected;
  final String searchHint;
  final bool searchable;

  @override
  State<_OptionPickerSheet<T>> createState() => _OptionPickerSheetState<T>();
}

class _OptionPickerSheetState<T> extends State<_OptionPickerSheet<T>> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<T> get _filtered {
    if (_query.isEmpty) return widget.options;
    final needle = _query.toLowerCase();
    return widget.options
        .where(
          (option) => widget.labelOf(option).toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: OgeraSearchField(
                controller: _controller,
                hint: widget.searchHint,
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nothing matches that search.',
                        style: TextStyle(color: OgeraColors.muted),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: results.length,
                    separatorBuilder: (_, _) =>
                        const Divider(indent: 20, endIndent: 20),
                    itemBuilder: (context, index) {
                      final option = results[index];
                      final isSelected = option == widget.selected;
                      return ListTile(
                        title: Text(
                          widget.labelOf(option),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? OgeraColors.blue
                                : OgeraColors.ink,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: OgeraColors.blue,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(option),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
