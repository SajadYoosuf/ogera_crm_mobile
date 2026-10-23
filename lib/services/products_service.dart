/// Products service.
///
/// Wraps:
///   GET /products — paged product catalogue (read-only for staff)
library;

import '../core/network/api_client.dart';
import '../models/product.dart';

class ProductsService {
  ProductsService(this._api);

  final ApiClient _api;

  /// Returns the first [limit] products, optionally filtered by [query].
  ///
  /// The backend returns `{ items, total, skip, limit }`. We only need the
  /// items for the mobile read-only view.
  Future<List<Product>> list({String? query, int limit = 100}) async {
    final data = asMap(
      await _api.get('/products', query: {
        if (query != null && query.isNotEmpty) 'q': query,
        'limit': limit,
        'is_active': 'true',
      }),
    );
    return asList(data['items']).map(Product.fromJson).toList();
  }
}
