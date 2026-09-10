import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/reference/crm_options.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../models/sale.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/sales_view_model.dart';

/// Record or amend a sale. Every column on the `sales` table is represented,
/// and the three ENUM columns only ever offer values the column accepts.
class SaleFormScreen extends StatelessWidget {
  const SaleFormScreen({super.key, this.existing});

  final Sale? existing;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          SaleFormViewModel(context.read<SalesService>(), existing: existing)
            ..loadProducts(),
      child: const _SaleFormView(),
    );
  }
}

class _SaleFormView extends StatefulWidget {
  const _SaleFormView();

  @override
  State<_SaleFormView> createState() => _SaleFormViewState();
}

class _SaleFormViewState extends State<_SaleFormView> {
  final _formKey = GlobalKey<FormState>();

  late final SaleFormViewModel _viewModel = context.read<SaleFormViewModel>();
  late final _buyerNameController = TextEditingController(
    text: _viewModel.draft.buyerName,
  );
  late final _buyerPhoneController = TextEditingController(
    text: _viewModel.draft.buyerPhone,
  );
  late final _addressController = TextEditingController(
    text: _viewModel.draft.address,
  );
  late final _wardController = TextEditingController(
    text: _viewModel.draft.ward,
  );
  late final _tankSizeController = TextEditingController(
    text: _viewModel.draft.tankSize,
  );
  late final _quantityController = TextEditingController(
    text: _viewModel.draft.quantity?.toString(),
  );
  late final _unitPriceController = TextEditingController(
    text: _viewModel.draft.unitPrice?.toStringAsFixed(0),
  );
  late final _engineerNameController = TextEditingController(
    text: _viewModel.draft.engineerName,
  );
  late final _engineerPhoneController = TextEditingController(
    text: _viewModel.draft.engineerPhone,
  );
  late final _plumberNameController = TextEditingController(
    text: _viewModel.draft.plumberName,
  );
  late final _plumberPhoneController = TextEditingController(
    text: _viewModel.draft.plumberPhone,
  );
  late final _remarksController = TextEditingController(
    text: _viewModel.draft.remarks,
  );

  @override
  void dispose() {
    for (final controller in [
      _buyerNameController,
      _buyerPhoneController,
      _addressController,
      _wardController,
      _tankSizeController,
      _quantityController,
      _unitPriceController,
      _engineerNameController,
      _engineerPhoneController,
      _plumberNameController,
      _plumberPhoneController,
      _remarksController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    _viewModel.draft
      ..buyerName = _buyerNameController.text
      ..buyerPhone = _buyerPhoneController.text
      ..address = _addressController.text
      ..ward = _wardController.text
      ..tankSize = _tankSizeController.text
      ..engineerName = _engineerNameController.text
      ..engineerPhone = _engineerPhoneController.text
      ..plumberName = _plumberNameController.text
      ..plumberPhone = _plumberPhoneController.text
      ..remarks = _remarksController.text;

    final saved = await _viewModel.save();
    if (!mounted) return;
    if (saved == null) {
      showToast(
        context,
        _viewModel.error ?? 'Could not save this sale.',
        isError: true,
      );
      return;
    }
    showToast(
      context,
      _viewModel.isEditing ? 'Sale updated.' : 'Sale recorded.',
    );
    Navigator.of(context).pop(saved);
  }

  /// Choosing a catalogue product fills the size and price; both stay editable
  /// because a real sale is often discounted.
  Future<void> _pickProduct() async {
    final products = _viewModel.products;
    if (products.isEmpty) {
      showToast(context, 'The product catalogue is not available right now.');
      return;
    }
    final picked = await showOptionPicker<ProductOption>(
      context,
      title: 'Product catalogue',
      options: products,
      labelOf: (product) => product.price == null
          ? product.name
          : '${product.name} — ${formatCurrency(product.price!)}',
      searchHint: 'Search products',
    );
    if (picked == null || !mounted) return;
    _viewModel.applyProduct(picked);
    _tankSizeController.text = _viewModel.draft.tankSize ?? '';
    if (_viewModel.draft.unitPrice != null) {
      _unitPriceController.text = _viewModel.draft.unitPrice!.toStringAsFixed(
        0,
      );
    }
    if (_quantityController.text.trim().isEmpty) {
      _quantityController.text = '${_viewModel.draft.quantity ?? 1}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SaleFormViewModel>();
    final draft = viewModel.draft;

    return Scaffold(
      appBar: AppBar(
        title: Text(viewModel.isEditing ? 'Edit sale' : 'New sale'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            140,
          ),
          children: [
            const SectionHeader(
              title: 'Buyer',
              icon: Icons.person_outline_rounded,
            ),
            OgeraTextField(
              label: 'Buyer name',
              controller: _buyerNameController,
              icon: Icons.badge_outlined,
              required: true,
              maxLength: 200,
              validator: viewModel.validateBuyerName,
            ),
            OgeraTextField(
              label: 'Buyer phone',
              controller: _buyerPhoneController,
              icon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
              required: true,
              maxLength: 20,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
              ],
              validator: viewModel.validateBuyerPhone,
            ),
            OgeraDateField(
              label: 'Sale date',
              value: draft.saleDate,
              allowClear: false,
              lastDate: DateTime.now(),
              onChanged: (value) =>
                  setState(() => draft.saleDate = value ?? todayIso()),
            ),

            const SectionHeader(title: 'Where', icon: Icons.place_outlined),
            OgeraTextField(
              label: 'Address',
              controller: _addressController,
              icon: Icons.home_outlined,
              maxLines: 2,
              maxLength: 2000,
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
            OgeraTextField(
              label: 'Ward',
              controller: _wardController,
              icon: Icons.numbers_rounded,
              maxLength: 100,
            ),

            const SectionHeader(
              title: 'Product',
              icon: Icons.inventory_2_outlined,
            ),
            _ProductPicker(
              productCount: viewModel.products.length,
              onPick: _pickProduct,
            ),
            OgeraTextField(
              label: 'Tank size',
              controller: _tankSizeController,
              icon: Icons.straighten_rounded,
              hint: 'e.g. 1000 Ltr',
              maxLength: 100,
            ),
            Row(
              children: [
                Expanded(
                  child: OgeraTextField(
                    label: 'Quantity',
                    controller: _quantityController,
                    icon: Icons.tag_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) =>
                        viewModel.setQuantity(int.tryParse(value.trim())),
                    validator: (value) {
                      final text = (value ?? '').trim();
                      if (text.isEmpty) return null;
                      final quantity = int.tryParse(text);
                      // quantity is a TINYINT UNSIGNED on the sales table.
                      if (quantity == null || quantity < 1 || quantity > 255) {
                        return '1 to 255';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OgeraTextField(
                    label: 'Unit price',
                    controller: _unitPriceController,
                    icon: Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) =>
                        viewModel.setUnitPrice(double.tryParse(value.trim())),
                  ),
                ),
              ],
            ),
            _TotalRow(total: draft.total),

            const SectionHeader(
              title: 'Site details',
              icon: Icons.water_drop_outlined,
            ),
            _EnumPicker(
              label: 'House stage',
              icon: Icons.house_outlined,
              options: SaleOptions.houseStages,
              value: draft.houseStage,
              onChanged: (value) => setState(() => draft.houseStage = value),
            ),
            _EnumPicker(
              label: 'Current tank',
              icon: Icons.storage_rounded,
              options: SaleOptions.currentTanks,
              value: draft.currentTank,
              onChanged: (value) => setState(() => draft.currentTank = value),
            ),
            _EnumPicker(
              label: 'Water source',
              icon: Icons.water_rounded,
              options: SaleOptions.waterSources,
              value: draft.waterSource,
              onChanged: (value) => setState(() => draft.waterSource = value),
            ),
            _EnumPicker(
              label: 'Source of sale',
              icon: Icons.input_rounded,
              options: SaleOptions.sourcesOfSale,
              value: draft.sourceOfSale,
              onChanged: (value) => setState(() => draft.sourceOfSale = value),
            ),

            const SectionHeader(
              title: 'Referral',
              icon: Icons.handyman_outlined,
            ),
            OgeraTextField(
              label: 'Engineer name',
              controller: _engineerNameController,
              icon: Icons.architecture_rounded,
              maxLength: 200,
            ),
            OgeraTextField(
              label: 'Engineer phone',
              controller: _engineerPhoneController,
              icon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
              maxLength: 20,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
              ],
            ),
            OgeraTextField(
              label: 'Plumber name',
              controller: _plumberNameController,
              icon: Icons.plumbing_rounded,
              maxLength: 200,
            ),
            OgeraTextField(
              label: 'Plumber phone',
              controller: _plumberPhoneController,
              icon: Icons.call_outlined,
              keyboardType: TextInputType.phone,
              maxLength: 20,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
              ],
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
              : Text(viewModel.isEditing ? 'Save changes' : 'Record sale'),
        ),
      ),
    );
  }
}

/// The catalogue is read-only here — product management stays in Venting Next.
class _ProductPicker extends StatelessWidget {
  const _ProductPicker({required this.productCount, required this.onPick});

  final int productCount;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: OutlinedButton.icon(
        onPressed: onPick,
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
        icon: const Icon(Icons.inventory_2_outlined, size: 18),
        label: Text(
          productCount == 0
              ? 'Product catalogue unavailable'
              : 'Pick from catalogue ($productCount)',
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: OgeraColors.successSoft,
          borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
          border: Border.all(
            color: OgeraColors.success.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.functions_rounded,
              size: 18,
              color: OgeraColors.success,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Total',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: OgeraColors.success,
                ),
              ),
            ),
            Text(
              formatCurrency(total),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: OgeraColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One picker for all four ENUM-backed columns, so the stored value is always
/// the column's own key while the user reads a label.
class _EnumPicker extends StatelessWidget {
  const _EnumPicker({
    required this.label,
    required this.icon,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return OgeraPickerField(
      label: label,
      icon: icon,
      placeholder: 'Not recorded',
      value: value == null ? null : options[value] ?? value,
      onClear: () => onChanged(null),
      onTap: () async {
        final picked = await showOptionPicker<String>(
          context,
          title: label,
          options: options.keys.toList(growable: false),
          labelOf: (key) => options[key] ?? key,
          selected: value,
          searchable: false,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
