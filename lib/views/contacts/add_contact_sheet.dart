/// Premium bottom sheet for adding a new contact.
///
/// Opened from the shell FAB — no navigation, stays in the same view.
/// Step 1: pick a contact type. Step 2: fill in the form.
/// Only mobile number is required. All other fields are optional.
///
/// Fields shown per type:
///   All types : name, phone, district, address, lead source,
///               referred by, note.
///   GPS       : the "Use my location" / "Pick on map" capture is shown only
///               when the lead source is a field visit (see [_isGpsSource]).
///   Consumer  : house stage, tank type, tank capacity, tank age,
///               products interested.
///   Partner   : partner/profession type, work area.
///   Dealer    : owner name, email.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/reference/crm_options.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/phone_numbers.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../models/contact.dart';
import '../../models/product.dart';
import '../../services/crm_services.dart';
import '../../services/products_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/contacts_view_model.dart';
import '../contacts/referral_picker_sheet.dart';
import '../shell_scope.dart';
import '../shared/location_capture_field.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Opens the add-contact sheet. On success the contacts list is refreshed.
Future<void> showAddContactSheet(BuildContext context) async {
  final contacts = context.read<ContactsViewModel>();
  final created = await showShellSheet<Contact>(
    context,
    (_) => const AddContactSheet(),
  );
  if (created == null || !context.mounted) return;
  showToast(context, 'Contact added successfully');
  contacts.refresh();
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet widget
// ─────────────────────────────────────────────────────────────────────────────

class AddContactSheet extends StatefulWidget {
  const AddContactSheet({super.key, this.existing});

  /// When set, the sheet edits this contact instead of creating one. The
  /// type cannot change in edit mode, and the save calls PUT, not POST.
  final Contact? existing;

  @override
  State<AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<AddContactSheet> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _workAreaController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _tankCapController = TextEditingController();
  final _tankAgeController = TextEditingController();

  ContactKind _type = ContactKind.consumer;
  String? _district;
  String? _latitude;
  String? _longitude;
  String? _selectedSource;
  String? _selectedSourceName;
  String? _houseStage;
  String? _tankType;
  String? _professionType;
  String? _professionLabel;
  ReferralChoice? _referral;
  final List<Product> _selectedProducts = [];

  bool _isSaving = false;
  String? _saveError;

  // Loaded from the API
  List<_LeadSource> _sources = [];
  Map<String, String> _houseStages = {};
  Map<String, String> _tankTypes = {};
  List<Product> _allProducts = [];
  Map<String, String> _professionTypes = {};
  bool _loadingOptions = true;

  bool get _isEditing => widget.existing != null;

  /// True when the selected lead source is a field visit, so GPS is needed.
  ///
  /// Beginner note: the server only stores coordinates for field-visit leads.
  /// `offline` is an older name for the same thing, so both count (this matches
  /// the rule in `ContactsService._body`). Everything else needs no GPS.
  bool get _isGpsSource {
    final slug = _selectedSource;
    if (slug == null || slug.isEmpty) return false;
    final normalised = LeadSourceCatalog.normalise(slug);
    return normalised == 'field_visit' || normalised == 'offline';
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) _prefill(existing);
    _loadOptions();
  }

  /// Copies a saved contact into the form controls, so an edit starts from the
  /// current values. Products and referral are not prefilled: when they stay
  /// empty, the save leaves the saved values unchanged.
  void _prefill(Contact contact) {
    _type = contact.contactType;
    _nameController.text = contact.name ?? '';
    _phoneController.text = contact.phone;
    _addressController.text = contact.address ?? '';
    _notesController.text = contact.notes ?? '';
    _district = contact.district;
    _latitude = contact.latitude?.toString();
    _longitude = contact.longitude?.toString();
    final slug = contact.leadSource?.slug;
    _selectedSource = (slug == null || slug.isEmpty) ? null : slug;
    _selectedSourceName = contact.leadSource?.name;
    final consumer = contact.consumerProfile;
    _houseStage = consumer?.houseStage;
    _tankType = consumer?.currentTankType;
    _tankCapController.text = consumer?.currentTankCapacity?.toString() ?? '';
    _tankAgeController.text = consumer?.currentTankAge?.toString() ?? '';
    final partner = contact.partnerProfile;
    _professionType = partner?.professionType;
    _professionLabel = partner == null
        ? null
        : humanizeSlug(partner.professionType);
    _workAreaController.text = partner?.workArea ?? '';
    final dealer = contact.dealerProfile;
    _ownerNameController.text = dealer?.ownerName ?? '';
    _emailController.text = dealer?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _workAreaController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _tankCapController.dispose();
    _tankAgeController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final api = context.read<ApiClient>();
    final contacts = context.read<ContactsService>();
    final products = context.read<ProductsService>();
    final catalog = SettingsOptionsCatalog.of(api);

    try {
      final results = await Future.wait([
        _fetchSources(api),
        contacts.houseStages(),
        _productsOrEmpty(products),
        catalog.options(
          'profession_type',
          fallback: const {
            'plumber': 'Plumber',
            'electrician': 'Electrician',
            'interior_designer': 'Interior Designer',
            'architect': 'Architect',
            'contractor': 'Contractor',
            'other': 'Other',
          },
        ),
        catalog.options('tank_type', fallback: CrmOptions.defaultTankTypes),
      ]);
      if (!mounted) return;
      setState(() {
        _sources = results[0] as List<_LeadSource>;
        _houseStages = results[1] as Map<String, String>;
        _allProducts = results[2] as List<Product>;
        _professionTypes = results[3] as Map<String, String>;
        _tankTypes = results[4] as Map<String, String>;
        _loadingOptions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOptions = false);
    }
  }

  /// Products are optional on this form. A failure here must not blank the
  /// other pickers, which load in the same batch.
  Future<List<Product>> _productsOrEmpty(ProductsService products) async {
    try {
      return await products.list(limit: 200);
    } on Exception {
      return const [];
    }
  }

  Future<List<_LeadSource>> _fetchSources(ApiClient api) async {
    try {
      final data = asList(await api.get('/lead-sources'));
      return [
        for (final row in data)
          if (asInt(row['id']) != null && asText(row['name']) != null)
            _LeadSource(
              id: asInt(row['id'])!,
              name: asText(row['name'])!,
              slug: asText(row['slug']) ?? '',
            ),
      ];
    } catch (_) {
      // Return the static fallback list so the picker is never empty.
      return [
        for (final slug in CrmOptions.contactSources)
          _LeadSource(id: 0, name: CrmOptions.sourceLabel(slug), slug: slug),
      ];
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final draft = ContactDraft(
      contactType: _type,
      name: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      district: _district,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      source: _selectedSource,
      // A professional is a partner contact, so both referral kinds are sent by id.
      referredByContactId:
          _referral?.contact?.id ?? _referral?.professional?.id,
      // Consumer
      houseStage: _type == ContactKind.consumer ? _houseStage : null,
      currentTank: _type == ContactKind.consumer ? _tankType : null,
      tankCapacity: _type == ContactKind.consumer
          ? int.tryParse(_tankCapController.text)
          : null,
      tankAge: _type == ContactKind.consumer
          ? int.tryParse(_tankAgeController.text)
          : null,
      interestedProductIds:
          _type == ContactKind.consumer && _selectedProducts.isNotEmpty
          ? [for (final p in _selectedProducts) p.id]
          : null,
      // Partner
      professionType: _type == ContactKind.partner ? _professionType : null,
      workArea: _type == ContactKind.partner
          ? (_workAreaController.text.trim().isEmpty
                ? null
                : _workAreaController.text.trim())
          : null,
      // Dealer
      ownerName: _type == ContactKind.dealer
          ? (_ownerNameController.text.trim().isEmpty
                ? null
                : _ownerNameController.text.trim())
          : null,
      email: _type == ContactKind.dealer
          ? (_emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim())
          : null,
    );

    try {
      final service = context.read<ContactsService>();
      final existing = widget.existing;
      final contact = existing == null
          ? await service.create(draft)
          : await service.update(existing.id, draft);
      if (!mounted) return;
      Navigator.of(context).pop(contact);
    } on ApiException catch (e) {
      // The backend's message is the one to show, e.g. the field-visit GPS rule.
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = 'Could not save contact. Please try again.';
      });
    }
  }

  // ── Referral ──────────────────────────────────────────────────────────────

  Future<void> _pickReferral() async {
    final choice = await showReferralPicker(context);
    if (choice == null) return;
    setState(() => _referral = choice);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    // The modal bottom sheet (see showShellSheet) already draws the sheet
    // surface and handles drag-to-close, so this widget only draws its content.
    return Container(
      decoration: const BoxDecoration(
        color: OgeraColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _DragHandle(),
          _SheetHeader(
            type: _type,
            isEditing: _isEditing,
            onTypeChanged: _onTypeChanged,
          ),
          const Divider(height: 1),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  OgeraSpacing.screen,
                  16,
                  OgeraSpacing.screen,
                  16 + bottom,
                ),
                children: [
                  if (_loadingOptions)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  _buildIdentitySection(),
                  _buildLeadInfoSection(),
                  _buildLocationSection(),
                  if (_type == ContactKind.consumer) _buildConsumerSection(),
                  if (_type == ContactKind.partner) _buildPartnerSection(),
                  if (_type == ContactKind.dealer) _buildDealerSection(),
                  _buildNotesSection(),
                  if (_saveError != null) ...[
                    const SizedBox(height: 8),
                    _ErrorBanner(message: _saveError!),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          _SubmitBar(isSaving: _isSaving, onSave: _save),
        ],
      ),
    );
  }

  void _onTypeChanged(ContactKind type) {
    // The type of a saved contact is fixed; changing it would leave the old profile behind.
    if (_isEditing) return;
    if (_type == type) return;
    setState(() {
      _type = type;
      _saveError = null;
    });
  }

  // ── Form sections ─────────────────────────────────────────────────────────

  Widget _buildIdentitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          title: 'Identity',
          icon: Icons.person_outline_rounded,
        ),
        OgeraTextField(
          label: 'Full name',
          controller: _nameController,
          icon: Icons.badge_outlined,
          hint: 'Enter name',
          maxLength: 150,
          textCapitalization: TextCapitalization.words,
        ),
        OgeraTextField(
          label: 'Mobile number',
          controller: _phoneController,
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          required: true,
          maxLength: 20,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
          ],
          validator: (v) {
            // The same parser the dialer and WhatsApp use, so a number that
            // passes here will call and message correctly.
            final trimmed = (v ?? '').trim();
            if (trimmed.isEmpty) return 'Mobile number is required';
            return validateContactPhone(trimmed);
          },
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(title: 'Location', icon: Icons.place_outlined),
        OgeraPickerField(
          label: 'District',
          icon: Icons.map_outlined,
          value: _district,
          placeholder: 'Select district',
          onClear: () => setState(() => _district = null),
          onTap: () async {
            final picked = await showOptionPicker<String>(
              context,
              title: 'Select district',
              options: CrmOptions.districts,
              labelOf: (v) => v,
              selected: _district,
              searchHint: 'Search district',
            );
            if (picked != null) setState(() => _district = picked);
          },
        ),
        // GPS is only asked for on a field visit. Other sources skip it.
        if (_isGpsSource)
          LocationCaptureField(
            latitude: _latitude,
            longitude: _longitude,
            address: _addressController.text.isEmpty
                ? null
                : _addressController.text,
            onChanged: (lat, lng, address) {
              setState(() {
                _latitude = lat;
                _longitude = lng;
              });
              if (address != null && _addressController.text.trim().isEmpty) {
                _addressController.text = address;
              }
            },
          ),
        OgeraTextField(
          label: 'Address',
          controller: _addressController,
          icon: Icons.home_outlined,
          maxLines: 2,
          maxLength: 255,
        ),
      ],
    );
  }

  Widget _buildLeadInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(title: 'Lead info', icon: Icons.input_rounded),
        OgeraPickerField(
          label: 'Lead source',
          icon: Icons.campaign_outlined,
          value: _selectedSourceName,
          placeholder: 'Select source',
          onClear: () => setState(() {
            _selectedSource = null;
            _selectedSourceName = null;
            _clearGpsIfNotNeeded();
          }),
          onTap: () {
            if (!_loadingOptions) _pickSource();
          },
        ),
        _ReferralField(
          choice: _referral,
          onPick: _pickReferral,
          onClear: () => setState(() => _referral = null),
        ),
      ],
    );
  }

  Widget _buildConsumerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          title: 'Property details',
          icon: Icons.home_work_outlined,
        ),
        OgeraPickerField(
          label: 'House stage',
          icon: Icons.construction_outlined,
          value: _houseStage == null
              ? null
              : CrmOptions.houseStageLabel(_houseStage, _houseStages),
          placeholder: 'Select stage',
          onClear: () => setState(() => _houseStage = null),
          onTap: () async {
            if (_loadingOptions) return;
            final picked = await showOptionPicker<String>(
              context,
              title: 'House stage',
              options: _houseStages.keys.toList(),
              labelOf: (v) => CrmOptions.houseStageLabel(v, _houseStages),
              selected: _houseStage,
              searchable: false,
            );
            if (picked != null) setState(() => _houseStage = picked);
          },
        ),
        OgeraPickerField(
          label: 'Current tank type',
          icon: Icons.water_outlined,
          value: _tankType == null
              ? null
              : CrmOptions.houseStageLabel(_tankType, _tankTypes),
          placeholder: 'Select type',
          onClear: () => setState(() => _tankType = null),
          onTap: () async {
            if (_loadingOptions) return;
            final picked = await showOptionPicker<String>(
              context,
              title: 'Tank type',
              options: _tankTypes.keys.toList(),
              labelOf: (v) => CrmOptions.houseStageLabel(v, _tankTypes),
              selected: _tankType,
              searchable: false,
            );
            if (picked != null) setState(() => _tankType = picked);
          },
        ),
        OgeraTextField(
          label: 'Tank capacity (litres)',
          controller: _tankCapController,
          icon: Icons.opacity_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          hint: 'e.g. 1000',
        ),
        OgeraTextField(
          label: 'Tank age (years)',
          controller: _tankAgeController,
          icon: Icons.schedule_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 3,
          hint: 'e.g. 5',
        ),
        if (_allProducts.isNotEmpty)
          _ProductsField(
            allProducts: _allProducts,
            selected: _selectedProducts,
            onChanged: (products) => setState(() {
              _selectedProducts
                ..clear()
                ..addAll(products);
            }),
          ),
      ],
    );
  }

  Widget _buildPartnerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          title: 'Partner details',
          icon: Icons.handyman_outlined,
        ),
        OgeraPickerField(
          label: 'Partner type',
          icon: Icons.work_outline_rounded,
          value: _professionLabel,
          placeholder: 'Select type',
          onClear: () => setState(() {
            _professionType = null;
            _professionLabel = null;
          }),
          onTap: () async {
            if (_loadingOptions) return;
            final options = _professionTypes.keys.toList();
            final picked = await showOptionPicker<String>(
              context,
              title: 'Partner type',
              options: options,
              labelOf: (v) => _professionTypes[v] ?? v,
              selected: _professionType,
              searchable: options.length > 6,
            );
            if (picked != null) {
              setState(() {
                _professionType = picked;
                _professionLabel = _professionTypes[picked] ?? picked;
              });
            }
          },
        ),
        OgeraTextField(
          label: 'Work area',
          controller: _workAreaController,
          icon: Icons.location_city_outlined,
          hint: 'e.g. Kozhikode',
          maxLength: 255,
        ),
      ],
    );
  }

  Widget _buildDealerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(
          title: 'Dealer details',
          icon: Icons.storefront_outlined,
        ),
        OgeraTextField(
          label: 'Owner name',
          controller: _ownerNameController,
          icon: Icons.manage_accounts_outlined,
          hint: 'Name of the owner',
          maxLength: 150,
          textCapitalization: TextCapitalization.words,
        ),
        OgeraTextField(
          label: 'Email',
          controller: _emailController,
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          maxLength: 150,
          hint: 'owner@example.com',
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(t)) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(title: 'Notes', icon: Icons.notes_rounded),
        OgeraTextField(
          label: 'Notes',
          controller: _notesController,
          maxLines: 3,
          maxLength: 2000,
          hint: 'Any additional info about this contact',
        ),
      ],
    );
  }

  // ── Source picker ─────────────────────────────────────────────────────────

  Future<void> _pickSource() async {
    final picked = await showOptionPicker<_LeadSource>(
      context,
      title: 'Lead source',
      options: _sources,
      labelOf: (s) => s.name,
      selected: _sources.where((s) => s.slug == _selectedSource).isEmpty
          ? null
          : _sources.firstWhere((s) => s.slug == _selectedSource),
      searchable: false,
    );
    if (picked != null) {
      setState(() {
        _selectedSource = picked.slug;
        _selectedSourceName = picked.name;
        _clearGpsIfNotNeeded();
      });
    }
  }

  /// Drops a captured GPS point when the source no longer needs one, so a
  /// hidden location is never left behind. Call it inside setState after the
  /// source has changed.
  void _clearGpsIfNotNeeded() {
    if (_isGpsSource) return;
    _latitude = null;
    _longitude = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: OgeraColors.line,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.type,
    required this.isEditing,
    required this.onTypeChanged,
  });

  final ContactKind type;
  final bool isEditing;
  final ValueChanged<ContactKind> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OgeraSpacing.screen,
        0,
        OgeraSpacing.screen,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OgeraColors.blueSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 20,
                  color: OgeraColors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Edit Contact' : 'Add Contact',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    isEditing
                        ? 'Type cannot be changed after saving'
                        : 'Only mobile number is required',
                    style: const TextStyle(
                      fontSize: 12,
                      color: OgeraColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Contact type selector
          Row(
            children: [
              for (final kind in ContactKind.values) ...[
                if (kind.index > 0) const SizedBox(width: 8),
                Expanded(
                  child: _TypeChip(
                    kind: kind,
                    selected: type == kind,
                    onTap: () => onTypeChanged(kind),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final ContactKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (kind) {
      ContactKind.consumer => Icons.home_outlined,
      ContactKind.partner => Icons.handyman_outlined,
      ContactKind.dealer => Icons.storefront_outlined,
    };
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? OgeraColors.blue : OgeraColors.canvas,
          borderRadius: BorderRadius.circular(OgeraSpacing.chipRadius + 2),
          border: Border.all(
            color: selected ? OgeraColors.blue : OgeraColors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : OgeraColors.muted,
            ),
            const SizedBox(height: 4),
            Text(
              kind.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? Colors.white : OgeraColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: OgeraColors.blue),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: OgeraColors.blue,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _ReferralField extends StatelessWidget {
  const _ReferralField({
    required this.choice,
    required this.onPick,
    required this.onClear,
  });

  final ReferralChoice? choice;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (choice == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.add_link_rounded, size: 18),
          label: const Text('Add referred by'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: OgeraColors.blue,
            side: const BorderSide(color: OgeraColors.line),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: OgeraCard(
        onTap: onPick,
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        accent: OgeraColors.blue,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Referred by',
                    style: TextStyle(fontSize: 11, color: OgeraColors.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    choice!.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onClear,
              color: OgeraColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-select product picker row. Tapping opens a picker sheet; selected
/// products show as removable chips below.
class _ProductsField extends StatelessWidget {
  const _ProductsField({
    required this.allProducts,
    required this.selected,
    required this.onChanged,
  });

  final List<Product> allProducts;
  final List<Product> selected;
  final ValueChanged<List<Product>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: () => _pick(context),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Products interested'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: OgeraColors.blue,
              side: const BorderSide(color: OgeraColors.line),
            ),
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final product in selected)
                  _ProductChip(
                    product: product,
                    onRemove: () {
                      final updated = [...selected]..remove(product);
                      onChanged(updated);
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showOptionPicker<Product>(
      context,
      title: 'Products interested',
      options: allProducts,
      labelOf: (p) => p.name,
      selected: selected.isNotEmpty ? selected.first : null,
      searchable: true,
      searchHint: 'Search product',
    );
    if (picked == null) return;
    if (selected.any((p) => p.id == picked.id)) return;
    onChanged([...selected, picked]);
  }
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({required this.product, required this.onRemove});

  final Product product;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: OgeraColors.blueSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OgeraColors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            product.name,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: OgeraColors.blue,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: OgeraColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OgeraColors.dangerSoft,
        borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
        border: Border.all(color: OgeraColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: OgeraColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: OgeraColors.danger,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.isSaving, required this.onSave});

  final bool isSaving;
  final VoidCallback onSave;

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
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: OgeraColors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
          ),
        ),
        child: isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Save Contact',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers
// ─────────────────────────────────────────────────────────────────────────────

class _LeadSource {
  const _LeadSource({required this.id, required this.name, required this.slug});

  final int id;
  final String name;
  final String slug;
}

/// Opens the same form in edit mode for a saved contact. Returns the updated
/// contact when the user saves, or null when they cancel.
Future<Contact?> showEditContactSheet(BuildContext context, Contact contact) {
  return showShellSheet<Contact>(
    context,
    (_) => AddContactSheet(existing: contact),
  );
}
