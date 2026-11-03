// sale_form_screen.dart
//
// Create or edit a sale record.
//
// WHAT IT DOES:
//   - Shows a form with all sale fields: name, phone, alt phone, product,
//     purchase date, address, and which employee recorded it.
//   - Validates the name (required) before saving.
//   - Calls SalesViewModel.create() or SalesViewModel.update() on save.
//   - If the device is offline, the view model queues the action and returns null
//     (treated as success). A banner reminds the user the change will sync later.
//
// HOW TO OPEN:
//   Navigator.of(context).push(MaterialPageRoute(
//     builder: (_) => ChangeNotifierProvider.value(
//       value: context.read<SalesViewModel>(),
//       child: SaleFormScreen(existing: sale), // null = create
//     ),
//   ));

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sale.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/sales_view_model.dart';

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
  String? _error;

  // Text controllers — needed so we can pre-fill the form when editing.
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _altPhoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _productCtrl;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _draft = _isEditing
        ? SaleDraft.fromSale(widget.existing!)
        : SaleDraft();

    _nameCtrl = TextEditingController(text: _draft.name);
    _phoneCtrl = TextEditingController(text: _draft.phone ?? '');
    _altPhoneCtrl = TextEditingController(text: _draft.altPhone ?? '');
    _addressCtrl = TextEditingController(text: _draft.address ?? '');
    _productCtrl = TextEditingController(text: _draft.purchasedProduct ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _productCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: OgeraColors.danger),
                ),
              ),

            // Name (required)
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Customer name *',
                hintText: 'Full name',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return 'Customer name is required.';
                return null;
              },
              onChanged: (v) => _draft.name = v,
            ),
            const SizedBox(height: 16),

            // Phone
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone',
                hintText: '10-digit number',
              ),
              keyboardType: TextInputType.phone,
              onChanged: (v) => _draft.phone = v.trim().isEmpty ? null : v.trim(),
            ),
            const SizedBox(height: 16),

            // Alt phone
            TextFormField(
              controller: _altPhoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Alt. phone',
                hintText: 'Optional second number',
              ),
              keyboardType: TextInputType.phone,
              onChanged: (v) => _draft.altPhone = v.trim().isEmpty ? null : v.trim(),
            ),
            const SizedBox(height: 16),

            // Product purchased — autocomplete from past sales
            _ProductField(
              controller: _productCtrl,
              onChanged: (v) =>
                  _draft.purchasedProduct = v.trim().isEmpty ? null : v.trim(),
            ),
            const SizedBox(height: 16),

            // Purchase date
            _DateField(
              label: 'Purchase date',
              value: _draft.purchaseDate,
              onChanged: (date) => setState(() => _draft.purchaseDate = date),
            ),
            const SizedBox(height: 16),

            // Address
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'Installation address',
              ),
              maxLines: 2,
              onChanged: (v) =>
                  _draft.address = v.trim().isEmpty ? null : v.trim(),
            ),
            const SizedBox(height: 32),
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
    _draft.phone = _phoneCtrl.text.trim().isEmpty
        ? null
        : _phoneCtrl.text.trim();
    _draft.altPhone = _altPhoneCtrl.text.trim().isEmpty
        ? null
        : _altPhoneCtrl.text.trim();
    _draft.address = _addressCtrl.text.trim().isEmpty
        ? null
        : _addressCtrl.text.trim();
    _draft.purchasedProduct = _productCtrl.text.trim().isEmpty
        ? null
        : _productCtrl.text.trim();

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

// ── Product autocomplete field ─────────────────────────────────────────────

class _ProductField extends StatelessWidget {
  const _ProductField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final suggestions = context.watch<SalesViewModel>().productSuggestions;

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        if (query.isEmpty) return suggestions;
        return suggestions.where((s) => s.toLowerCase().contains(query));
      },
      fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
        return TextFormField(
          controller: ctrl,
          focusNode: focus,
          decoration: const InputDecoration(
            labelText: 'Product purchased',
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

// ── Date picker field ──────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final date = value != null ? DateTime.tryParse(value!) : null;
    final dateStr = date != null
        ? '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/'
            '${date.year}'
        : '';

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          final iso =
              '${picked.year.toString().padLeft(4, '0')}-'
              '${picked.month.toString().padLeft(2, '0')}-'
              '${picked.day.toString().padLeft(2, '0')}';
          onChanged(iso);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: date != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today),
        ),
        child: Text(
          dateStr.isEmpty ? 'Tap to select' : dateStr,
          style: dateStr.isEmpty
              ? TextStyle(color: Theme.of(context).hintColor)
              : null,
        ),
      ),
    );
  }
}
