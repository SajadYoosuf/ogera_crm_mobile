import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/reference/crm_options.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../models/professional.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/professionals_view_model.dart';
import '../shared/location_capture_field.dart';

class ProfessionalFormScreen extends StatelessWidget {
  const ProfessionalFormScreen({super.key, this.existing});

  final Professional? existing;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ProfessionalFormViewModel(
        context.read<ProfessionalsService>(),
        existing: existing,
      ),
      child: const _ProfessionalFormView(),
    );
  }
}

class _ProfessionalFormView extends StatefulWidget {
  const _ProfessionalFormView();

  @override
  State<_ProfessionalFormView> createState() => _ProfessionalFormViewState();
}

class _ProfessionalFormViewState extends State<_ProfessionalFormView> {
  final _formKey = GlobalKey<FormState>();

  late final ProfessionalFormViewModel _viewModel = context
      .read<ProfessionalFormViewModel>();
  late final _nameController = TextEditingController(
    text: _viewModel.draft.name,
  );
  late final _phoneController = TextEditingController(
    text: _viewModel.draft.phone,
  );
  late final _placeController = TextEditingController(
    text: _viewModel.draft.place,
  );
  late final _addressController = TextEditingController(
    text: _viewModel.draft.address,
  );

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _placeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    _viewModel.draft
      ..name = _nameController.text
      ..phone = _phoneController.text
      ..place = _placeController.text
      ..address = _addressController.text;

    final saved = await _viewModel.save();
    if (!mounted) return;
    if (saved == null) {
      showToast(
        context,
        _viewModel.error ?? 'Could not save this professional.',
        isError: true,
      );
      return;
    }
    showToast(
      context,
      _viewModel.isEditing ? 'Professional updated.' : 'Professional added.',
    );
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProfessionalFormViewModel>();
    final draft = viewModel.draft;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          viewModel.isEditing ? 'Edit professional' : 'New professional',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            120,
          ),
          children: [
            const SectionHeader(
              title: 'Profession',
              icon: Icons.handyman_outlined,
            ),
            _TypeSelector(selected: draft.type, onChanged: viewModel.setType),

            const SectionHeader(
              title: 'Who',
              icon: Icons.person_outline_rounded,
            ),
            OgeraTextField(
              label: 'Name',
              controller: _nameController,
              icon: Icons.badge_outlined,
              maxLength: 150,
            ),
            OgeraTextField(
              label: 'Phone',
              controller: _phoneController,
              icon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
              required: true,
              maxLength: 20,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
              ],
              validator: viewModel.validatePhone,
            ),

            const SectionHeader(title: 'Where', icon: Icons.place_outlined),
            LocationCaptureField(
              latitude: draft.latitude,
              longitude: draft.longitude,
              address: draft.address,
              onChanged: (latitude, longitude, address) {
                viewModel.setLocation(latitude: latitude, longitude: longitude);
                if (address != null && _addressController.text.trim().isEmpty) {
                  _addressController.text = address;
                }
              },
            ),
            OgeraTextField(
              label: 'Place',
              controller: _placeController,
              icon: Icons.storefront_outlined,
              hint: 'Town or locality they work from',
              maxLength: 100,
            ),
            OgeraTextField(
              label: 'Address',
              controller: _addressController,
              icon: Icons.home_outlined,
              maxLines: 2,
              maxLength: 255,
            ),
            OgeraPickerField(
              label: 'District',
              icon: Icons.map_outlined,
              value: draft.district,
              onClear: () => setState(() => draft.district = null),
              onTap: () async {
                final picked = await showOptionPicker<String>(
                  context,
                  title: 'District',
                  options: CrmOptions.districts,
                  labelOf: (value) => value,
                  selected: draft.district,
                );
                if (picked != null) setState(() => draft.district = picked);
              },
            ),
            OgeraPickerField(
              label: 'Panchayath',
              icon: Icons.location_city_outlined,
              value: draft.panchayath,
              onClear: () => setState(() => draft.panchayath = null),
              onTap: () async {
                final picked = await showOptionPicker<String>(
                  context,
                  title: 'Panchayath',
                  options: CrmOptions.panchayaths,
                  labelOf: (value) => value,
                  selected: draft.panchayath,
                  searchHint: 'Search panchayath',
                );
                if (picked != null) setState(() => draft.panchayath = picked);
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          12,
          OgeraSpacing.screen,
          12 + MediaQuery.paddingOf(context).bottom,
        ),
        decoration: const BoxDecoration(
          color: OgeraColors.surface,
          border: Border(top: BorderSide(color: OgeraColors.line)),
        ),
        child: FilledButton(
          onPressed: viewModel.isSaving ? null : _save,
          child: viewModel.isSaving
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(viewModel.isEditing ? 'Save changes' : 'Add professional'),
        ),
      ),
    );
  }
}

/// Five professions, shown as a tappable grid — faster than a dropdown and it
/// makes the whole set visible at once.
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final ProfessionalType selected;
  final ValueChanged<ProfessionalType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final type in ProfessionalType.values)
            GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: type == selected
                      ? type.color.withValues(alpha: 0.13)
                      : OgeraColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: type == selected ? type.color : OgeraColors.line,
                    width: type == selected ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type.icon,
                      size: 18,
                      color: type == selected ? type.color : OgeraColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: type == selected ? type.color : OgeraColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
