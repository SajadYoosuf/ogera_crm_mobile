// sale_form_screen.dart
//
// Create or edit a sale record.
//
// FIELDS:
//   - Customer name (required)
//   - Phone
//   - Product purchased (dropdown from past sales suggestions)
//   - Branch (dropdown: malappuram / kottakkal / perinthalmanna)
//   - Purchase date (date picker)
//   - Address
//
// Created-by is auto-set to the signed-in employee — not shown.
// Alt. phone is removed (not needed at point of sale).

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sale.dart';
import '../../services/products_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/sales_view_model.dart';
import '../../view_models/session_view_model.dart';

const _branches = ['malappuram', 'kottakkal', 'perinthalmanna'];

class SaleFormScreen extends StatefulWidget {
  /// Pass an existing sale to edit it. Pass null to create a new one.
  const SaleFormScreen({super.key, this.existing});

  final Sale? existing;

  @override
  State<SaleFormScreen> createState() => _SaleFormScreenState();
}

class _SaleFormScreenState extends State<SaleFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final SaleDraft _draft;
  bool _isSaving = false;
  bool _isLoadingProducts = true;
  String? _error;
  List<String> _productSuggestions = const [];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _productCtrl;
  late final TextEditingController _addressCtrl;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _draft = _isEditing ? SaleDraft.fromSale(widget.existing!) : SaleDraft();

    // Load product options when the sale form is opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProducts();
      }
    });

    // Auto-set created_by to the signed-in employee on new records.
    if (!_isEditing) {
      final session = context.read<SessionViewModel>();
      _draft.createdByEmployeeId = session.userId == 0 ? null : session.userId;
    }

    _nameCtrl = TextEditingController(text: _draft.name);
    _phoneCtrl = TextEditingController(text: _draft.phone ?? '');
    _productCtrl = TextEditingController(text: _draft.purchasedProduct ?? '');
    _addressCtrl = TextEditingController(text: _draft.address ?? '');
  }

  Future<void> _loadProducts() async {
    try {
      final products = await context.read<ProductsService>().list(limit: 200);
      if (!mounted) return;
      setState(() {
        _productSuggestions = products
            .map((product) => product.name.trim())
            .where((name) => name.isNotEmpty)
            .toList(growable: false);
        _isLoadingProducts = false;
      });
    } on Exception {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _productCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _productSuggestions;

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        backgroundColor: OgeraColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(_isEditing ? 'Edit sale' : 'Add sale'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            if (_error != null)
              _ErrorBanner(message: _error!),

            // Customer name (required)
            _Field(
              label: 'Customer name *',
              child: TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'Full name'),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Customer name is required.' : null,
                onChanged: (v) => _draft.name = v,
              ),
            ),

            // Phone
            _Field(
              label: 'Phone',
              child: TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(hintText: '10-digit number'),
                keyboardType: TextInputType.phone,
                onChanged: (v) =>
                    _draft.phone = v.trim().isEmpty ? null : v.trim(),
              ),
            ),

            // Product purchased — dropdown from past sales
            _Field(
              label: 'Product purchased',
              child: _ProductField(
                controller: _productCtrl,
                suggestions: suggestions,
                enabled: !_isLoadingProducts,
                onChanged: (value) => _draft.purchasedProduct =
                    value.trim().isEmpty ? null : value.trim(),
              ),
            ),

            // Branch
            _Field(
              label: 'Branch',
              child: DropdownButtonFormField<String>(
                initialValue: _branches.contains(_draft.branch) ? _draft.branch : null,
                hint: const Text('Select branch'),
                isExpanded: true,
                decoration: const InputDecoration(),
                items: _branches
                    .map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(
                            b[0].toUpperCase() + b.substring(1),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _draft.branch = v),
              ),
            ),

            // Purchase date
            _Field(
              label: 'Purchase date',
              child: _DatePicker(
                value: _draft.purchaseDate,
                onChanged: (date) => setState(() => _draft.purchaseDate = date),
              ),
            ),

            // Address
            _Field(
              label: 'Address',
              child: TextFormField(
                controller: _addressCtrl,
                decoration:
                    const InputDecoration(hintText: 'Installation address'),
                maxLines: 2,
                onChanged: (v) =>
                    _draft.address = v.trim().isEmpty ? null : v.trim(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    _draft.name = _nameCtrl.text.trim();
    _draft.phone =
        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim();
    _draft.address =
        _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim();

    final vm = context.read<SalesViewModel>();
    final error = _isEditing
        ? await vm.update(widget.existing!.id, _draft)
        : await vm.create(_draft);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isSaving = false;
        _error = error;
      });
    } else {
      Navigator.of(context).pop();
    }
  }
}

// ── Shared label + field wrapper ───────────────────────────────────────────

class _ProductField extends StatelessWidget {
  const _ProductField({
    required this.controller,
    required this.suggestions,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        final availableSuggestions = suggestions;
        if (query.isEmpty) return availableSuggestions;
        return availableSuggestions
            .where(
              (suggestion) =>
                  suggestion.toLowerCase().contains(query),
            )
            .toList(growable: false);
      },
      fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
        return TextFormField(
          controller: ctrl,
          focusNode: focus,
          enabled: enabled,
          decoration: const InputDecoration(
            hintText: 'Tank model or product name',
          ),
          onChanged: onChanged,
        );
      },
      onSelected: (value) {
        controller.text = value;
        onChanged(value);
      },
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: OgeraColors.muted,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: OgeraColors.dangerSoft,
        borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
        border: Border.all(color: OgeraColors.danger.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: OgeraColors.danger, fontSize: 13.5),
      ),
    );
  }
}

// ── Date picker ─────────────────────────────────────────────────────────────

class _DatePicker extends StatelessWidget {
  const _DatePicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final date = value != null ? DateTime.tryParse(value!) : null;
    final label = date != null
        ? '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/'
            '${date.year}'
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          onChanged(
            '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}',
          );
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: 'Tap to select',
          suffixIcon: date != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          label ?? 'Tap to select',
          style: label == null
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }
}
