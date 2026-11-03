/// Phone input with a country-code picker, used by the add-contact sheet.
///
/// Beginner note: this is two controls side by side. The left button shows the
/// selected country (flag and `+91`). Tapping it opens a searchable list, so the
/// user never types a country code. The right box takes only the national
/// number, digits only, at most 10 digits. The rules for each country live in
/// `core/utils/country_codes.dart`.
///
/// Flutter state in one line: the parent sheet owns the selected country. When
/// the user picks a new one, [onCountryChanged] tells the parent, the parent
/// calls setState, and this widget rebuilds with the new country.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/ogera_colors.dart';
import '../utils/country_codes.dart';
import 'ogera_widgets.dart';

/// A phone field made of a country-code button and a national-number box.
class PhoneNumberField extends StatelessWidget {
  const PhoneNumberField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.label = 'Mobile number',
    this.textInputAction,
  });

  /// Holds only the national number, e.g. `9876543210`. No country code.
  final TextEditingController controller;

  /// The selected country, or null when none is chosen yet.
  final DialCountry? country;

  final ValueChanged<DialCountry> onCountryChanged;
  final String label;
  final TextInputAction? textInputAction;

  Future<void> _pickCountry(BuildContext context) async {
    final picked = await showCountryCodePicker(context, selected: country);
    if (picked != null) onCountryChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final maxDigits = country?.maxDigits ?? kMaxNationalDigits;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CountryCodeButton(
            country: country,
            onTap: () => _pickCountry(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              textInputAction: textInputAction,
              style: const TextStyle(fontSize: 15, letterSpacing: 0.4),
              inputFormatters: [_NationalNumberFormatter(country)],
              validator: (value) =>
                  validateNationalNumber(country, (value ?? '').trim()),
              decoration: InputDecoration(
                labelText: '$label *',
                hintText: country == null
                    ? 'Choose a code first'
                    : 'Enter $maxDigits digits',
                counterText: '',
                prefixIcon: const Icon(Icons.phone_outlined, size: 19),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The country button at the left of the field. It shows the flag and dial
/// code, and turns red when no country is chosen.
class _CountryCodeButton extends StatelessWidget {
  const _CountryCodeButton({required this.country, required this.onTap});

  final DialCountry? country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = country;
    final borderColor = selected == null
        ? OgeraColors.danger
        : OgeraColors.line;
    return Semantics(
      button: true,
      label: selected == null
          ? 'Choose country code'
          : 'Country code ${selected.name} ${selected.dialLabel}',
      child: InkWell(
        borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selected?.flag ?? '🌐',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 6),
              Text(
                selected?.dialLabel ?? 'Code',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected == null
                      ? OgeraColors.danger
                      : OgeraColors.ink,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: OgeraColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps the number box to digits only and within the country's length.
/// It runs on every change, including pastes. See [cleanNationalInput].
class _NationalNumberFormatter extends TextInputFormatter {
  const _NationalNumberFormatter(this.country);

  final DialCountry? country;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = cleanNationalInput(newValue.text, country);
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Country picker sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Opens the country-code picker. Returns the chosen country, or null when the
/// user closes the sheet without choosing.
Future<DialCountry?> showCountryCodePicker(
  BuildContext context, {
  DialCountry? selected,
}) {
  return showModalBottomSheet<DialCountry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: OgeraColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CountryCodeSheet(selected: selected),
  );
}

/// Returns the countries whose name, ISO code or dial code matches [query].
/// A leading `+` in the query is ignored, so `+91` finds India.
List<DialCountry> filterCountries(String query) {
  final needle = query.trim().toLowerCase().replaceFirst('+', '');
  if (needle.isEmpty) return dialCountries;
  return [
    for (final country in dialCountries)
      if (country.name.toLowerCase().contains(needle) ||
          country.iso.toLowerCase() == needle ||
          country.dialCode.startsWith(needle))
        country,
  ];
}

class _CountryCodeSheet extends StatefulWidget {
  const _CountryCodeSheet({required this.selected});

  final DialCountry? selected;

  @override
  State<_CountryCodeSheet> createState() => _CountryCodeSheetState();
}

class _CountryCodeSheetState extends State<_CountryCodeSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = filterCountries(_query);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: OgeraColors.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Country code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: OgeraSearchField(
              controller: _searchController,
              hint: 'Search country or code',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Text(
                      'No country matches that search.',
                      style: TextStyle(color: OgeraColors.muted),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final country = results[index];
                      return _CountryRow(
                        country: country,
                        isSelected: country.iso == widget.selected?.iso,
                        onTap: () => Navigator.of(context).pop(country),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.country,
    required this.isSelected,
    required this.onTap,
  });

  final DialCountry country;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? OgeraColors.blueSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(OgeraSpacing.chipRadius + 4),
        ),
        child: Row(
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                country.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? OgeraColors.blue : OgeraColors.ink,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: OgeraColors.canvas,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                country.dialLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OgeraColors.inkSoft,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 20,
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: OgeraColors.blue,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
