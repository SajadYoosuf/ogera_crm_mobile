// sales_service.dart
//
// All API calls for the Sales module.
//
// BACKEND ENDPOINTS (routes/sales.py):
//   GET    /sales                  — paged list, filterable by search/product/date
//   GET    /sales/{id}             — single sale detail
//   POST   /sales                  — create (admin/manager only)
//   PUT    /sales/{id}             — update (admin/manager only)
//   DELETE /sales/{id}             — delete (admin/manager only)
//
// WHY SEPARATE FROM ContactsService:
//   Sales have their own domain (purchase records, not pipeline leads).
//   Keeping them in a dedicated file makes both files shorter and easier to read.

import '../core/network/api_client.dart';
import '../models/sale.dart';

class SalesService {
  const SalesService(this._api);

  final ApiClient _api;

  /// Paged list of past sales, newest first.
  ///
  /// [search] matches name, phone, address or product.
  /// [product] is an exact product name filter.
  /// [from] / [to] are ISO-8601 date strings (YYYY-MM-DD).
  Future<SalePage> list({
    String? search,
    String? product,
    String? from,
    String? to,
    int skip = 0,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/sales',
      query: {
        'skip': skip,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (product != null && product.trim().isNotEmpty) 'product': product.trim(),
        if (from != null && from.isNotEmpty) 'purchased_from': from,
        if (to != null && to.isNotEmpty) 'purchased_to': to,
      },
    );
    return SalePage.fromJson(asMap(data));
  }

  /// Active products from the catalogue, used by the sale form.
  Future<List<String>> products() async {
    final data = asMap(
      await _api.get(
        '/products',
        query: {'limit': 200, 'is_active': 'true'},
      ),
    );
    return asList(data['items'])
        .map((product) => (product['name'] as String?)?.trim() ?? '')
        .where((product) => product.isNotEmpty)
        .toList(growable: false);
  }

  Future<Sale> detail(int id) async {
    final data = await _api.get('/sales/$id');
    return Sale.fromJson(asMap(data));
  }

  /// Creates a new sale record. Admin and manager only.
  Future<Sale> create(SaleDraft draft) async {
    final data = await _api.post('/sales', body: draft.toApiJson());
    return Sale.fromJson(asMap(data));
  }

  /// Partially updates a sale (only the changed fields are sent).
  Future<Sale> update(int id, SaleDraft draft) async {
    final data = await _api.put(
      '/sales/$id',
      body: draft.toApiJson(forUpdate: true),
    );
    return Sale.fromJson(asMap(data));
  }

  /// Deletes a sale. Admin and manager only.
  Future<void> delete(int id) => _api.delete('/sales/$id');
}
