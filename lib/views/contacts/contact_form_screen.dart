import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/reference/crm_options.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../models/contact.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/contacts_view_model.dart';
import '../shared/location_capture_field.dart';
import 'referral_picker_sheet.dart';

/// Create or edit a contact. Every field the web form writes is present, in the
/// order a field user fills them: who, where, what they have, how they arrived.
class ContactFormScreen extends StatelessWidget {
  const ContactFormScreen({super.key, this.existing});

  final Contact? existing;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ContactFormViewModel(
        context.read<ContactsService>(),
        existing: existing,
      ),
      child: const _ContactFormView(),
    );
  }
}

class _ContactFormView extends StatefulWidget {
  const _ContactFormView();

  @override
  State<_ContactFormView> createState() => _ContactFormViewState();
}

class _ContactFormViewState extends State<_ContactFormView> {
  final _formKey = GlobalKey<FormState>();

  late final ContactFormViewModel _viewModel = context
      .read<ContactFormViewModel>();
  late final _nameController = TextEditingController(
    text: _viewModel.draft.name,
  );
  late final _phoneController = TextEditingController(
    text: _viewModel.draft.phone,
  );
  late final _addressController = TextEditingController(
    text: _viewModel.draft.address,
  );
  late final _remarksController = TextEditingController(
    text: _viewModel.draft.remarks,
  );

  ReferralChoice? _referral;

  @override
  void initState() {
    super.initState();
    // House stages come from Settings; the default list shows until they load.
    _viewModel.loadHouseStages();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    _viewModel.draft
      ..name = _nameController.text
      ..phone = _phoneController.text
      ..address = _addressController.text
      ..remarks = _remarksController.text;

    final saved = await _viewModel.save();
    if (!mounted) return;
    if (saved == null) {
      showToast(
        context,
        _viewModel.error ?? 'Could not save this contact.',
        isError: true,
      );
      return;
    }
    showToast(
      context,
      _viewModel.isEditing ? 'Contact updated.' : 'Contact added.',
    );
    Navigator.of(context).pop(saved);
  }

  Future<void> _pickReferral() async {
    final choice = await showReferralPicker(context);
    if (choice == null) return;
    setState(() => _referral = choice);

    switch (choice.source) {
      case ReferralSource.contact:
        _viewModel.setContactReferral(choice.contact!.id);
      case ReferralSource.professional:
        // A professional is a partner contact, so it is referred by id.
        _viewModel.setContactReferral(choice.professional!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ContactFormViewModel>();
    final draft = viewModel.draft;

    return Scaffold(
      appBar: AppBar(
        title: Text(viewModel.isEditing ? 'Edit contact' : 'New contact'),
      ),
      body: Form(
        key: _formKey,
        // A Column, not a lazy ListView: every field must exist for the
        // form's validators to run, including the ones below the fold.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            120,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OgeraSegmentedField<ContactType>(
                label: 'Contact type',
                values: ContactType.values,
                selected: draft.contactType,
                labelOf: (type) => type.label,
                iconOf: (type) => type == ContactType.lead
                    ? Icons.trending_up_rounded
                    : Icons.campaign_outlined,
                onChanged: viewModel.setType,
              ),

              const SectionHeader(
                title: 'Who',
                icon: Icons.person_outline_rounded,
              ),
              OgeraTextField(
                label: 'Name',
                controller: _nameController,
                icon: Icons.badge_outlined,
                hint: 'Full name',
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
              OgeraPickerField(
                label: 'Source',
                icon: Icons.input_rounded,
                value: draft.source == null
                    ? null
                    : CrmOptions.sourceLabel(draft.source!),
                placeholder: 'Not recorded',
                onClear: () => setState(() => draft.source = null),
                onTap: () async {
                  final picked = await showOptionPicker<String>(
                    context,
                    title: 'Source',
                    options: CrmOptions.contactSources,
                    labelOf: CrmOptions.sourceLabel,
                    selected: draft.source,
                    searchable: false,
                  );
                  if (picked != null) setState(() => draft.source = picked);
                },
              ),

              const SectionHeader(title: 'Where', icon: Icons.place_outlined),
              OgeraPickerField(
                label: 'District',
                icon: Icons.map_outlined,
                required: true,
                value: draft.district,
                placeholder: 'Select district',
                onClear: () => setState(() => draft.district = null),
                onTap: () async {
                  final picked = await showOptionPicker<String>(
                    context,
                    title: 'District',
                    options: CrmOptions.districts,
                    labelOf: (value) => value,
                    selected: draft.district,
                    searchHint: 'Search district',
                  );
                  if (picked != null) setState(() => draft.district = picked);
                },
              ),
              LocationCaptureField(
                latitude: draft.latitude,
                longitude: draft.longitude,
                address: draft.address,
                onChanged: (latitude, longitude, address) {
                  viewModel.setLocation(
                    latitude: latitude,
                    longitude: longitude,
                  );
                  // A resolved address only fills an empty field; it never
                  // overwrites something the user typed.
                  if (address != null &&
                      _addressController.text.trim().isEmpty) {
                    _addressController.text = address;
                  }
                },
              ),
              OgeraTextField(
                label: 'Address',
                controller: _addressController,
                icon: Icons.home_outlined,
                required: true,
                maxLines: 2,
                maxLength: 255,
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter the address.' : null,
              ),
              OgeraPickerField(
                label: 'House stage',
                icon: Icons.home_work_outlined,
                // The draft holds the stored value ("under_construction"); show its label.
                value: draft.houseStage == null
                    ? null
                    : CrmOptions.houseStageLabel(
                        draft.houseStage,
                        viewModel.houseStages,
                      ),
                placeholder: 'Not recorded',
                onClear: () => setState(() => draft.houseStage = null),
                onTap: () async {
                  final current = draft.houseStage;
                  // A stage hidden in Settings stays pickable on the record that already has it.
                  final options = [
                    ...viewModel.houseStages.keys,
                    if (current != null &&
                        current.isNotEmpty &&
                        !viewModel.houseStages.containsKey(current))
                      current,
                  ];
                  final picked = await showOptionPicker<String>(
                    context,
                    title: 'House stage',
                    options: options,
                    labelOf: (value) => CrmOptions.houseStageLabel(
                      value,
                      viewModel.houseStages,
                    ),
                    selected: current,
                    searchable: false,
                  );
                  if (picked != null) {
                    setState(() => draft.houseStage = picked);
                  }
                },
              ),

              const SectionHeader(
                title: 'Referral',
                icon: Icons.share_outlined,
              ),
              _ReferralField(
                label: _referralLabel(draft),
                onPick: _pickReferral,
                onClear: () {
                  setState(() => _referral = null);
                  viewModel.clearReferral();
                },
              ),

              const SectionHeader(title: 'Notes', icon: Icons.notes_rounded),
              OgeraTextField(
                label: 'Remarks',
                controller: _remarksController,
                maxLines: 4,
                maxLength: 2000,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _SaveBar(
        isSaving: viewModel.isSaving,
        label: viewModel.isEditing ? 'Save changes' : 'Add contact',
        onSave: _save,
      ),
    );
  }

  String? _referralLabel(ContactDraft draft) {
    if (_referral != null) return _referral!.label;
    if (draft.professionalName != null) {
      return '${draft.professionalType ?? 'Professional'} · ${draft.professionalName}';
    }
    if (draft.referredByContactId != null) {
      return 'Contact #${draft.referredByContactId}';
    }
    return null;
  }
}

class _ReferralField extends StatelessWidget {
  const _ReferralField({
    required this.label,
    required this.onPick,
    required this.onClear,
  });

  final String? label;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.add_link_rounded, size: 18),
          label: const Text('Add a referral source'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OgeraCard(
        onTap: onPick,
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        accent: OgeraColors.blue,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Referred by',
                    style: TextStyle(fontSize: 11.5, color: OgeraColors.muted),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove referral',
              icon: const Icon(Icons.close_rounded, size: 19),
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky save bar: the primary action stays reachable without scrolling back
/// through a long form.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.isSaving,
    required this.label,
    required this.onSave,
  });

  final bool isSaving;
  final String label;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        onPressed: isSaving ? null : onSave,
        child: isSaving
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
