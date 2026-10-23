/// Products screen — read-only product catalogue.
///
/// WHAT IT SHOWS:
///   - A searchable list of active products from GET /products.
///   - Name, model number, SKU, MRP / sale price.
///   - Read-only — no add/edit buttons (admin/manager do that on the web).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../theme/ogera_colors.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final ApiClient _api;
  bool _loading = false;
  String? _error;
  List<_Product> _products = [];
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = asMap(
        await _api.get('/products', query: {'is_active': true, 'limit': 500}),
      );
      _products = asList(data['items']).map(_Product.fromJson).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  List<_Product> get _filtered {
    if (_query.isEmpty) return _products;
    return _products
        .where(
          (p) =>
              (p.name.toLowerCase().contains(_query)) ||
              (p.sku?.toLowerCase().contains(_query) == true) ||
              (p.modelNumber?.toLowerCase().contains(_query) == true),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(title: const Text('Products')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: OgeraSearchField(
              controller: _searchController,
              hint: 'Search products…',
              onChanged: (_) {},
            ),
          ),
          Expanded(
            child: Builder(
              builder: (_) {
                if (_loading) return const LoadingListView(itemHeight: 72);
                if (_error != null) {
                  return ErrorStateView(message: _error!, onRetry: _load);
                }
                if (_filtered.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products',
                    message: 'No active products in the catalogue.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  itemCount: _filtered.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _ProductCard(product: _filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final _Product product;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (product.shortDescription != null) ...[
            const SizedBox(height: 3),
            Text(
              product.shortDescription!,
              style: const TextStyle(fontSize: 13, color: OgeraColors.muted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (product.sku != null)
                _Tag(label: 'SKU: ${product.sku}'),
              if (product.modelNumber != null)
                _Tag(label: product.modelNumber!),
              if (product.mrp != null)
                _Tag(
                  label: product.salePrice != null
                      ? '₹${product.salePrice} (MRP ₹${product.mrp})'
                      : 'MRP ₹${product.mrp}',
                  highlight: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.highlight = false});
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? OgeraColors.blueSoft : OgeraColors.canvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: OgeraColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: highlight ? OgeraColors.blue : OgeraColors.muted,
          fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _Product {
  const _Product({
    required this.id,
    required this.name,
    this.shortDescription,
    this.modelNumber,
    this.sku,
    this.mrp,
    this.salePrice,
  });

  final int id;
  final String name;
  final String? shortDescription;
  final String? modelNumber;
  final String? sku;
  final String? mrp;
  final String? salePrice;

  factory _Product.fromJson(Map<String, dynamic> json) => _Product(
    id: asInt(json['id']) ?? 0,
    name: asText(json['name']) ?? '',
    shortDescription: asText(json['short_description']),
    modelNumber: asText(json['model_number']),
    sku: asText(json['sku']),
    mrp: json['mrp']?.toString(),
    salePrice: json['sale_price']?.toString(),
  );
}
