// sale.dart
//
// Dart model for a sale record from GET /sales.
//
// WHAT IS A SALE?
//   A sale is a record of a product sold to a customer. It stores who bought it,
//   what they bought, the purchase date, and which employee recorded it.
//
//   The backend endpoint is GET /sales (list) and GET /sales/{id} (detail).
//   Admins and managers can create, edit, and delete sales. All signed-in users
//   can view them.
//
// BACKEND FIELDS (SaleResponse in schemas/sale.py):
//   id, purchase_date, name, phone, alt_phone, address,
//   purchased_product, created_by_employee_id,
//   contact_id (optional — links to a contact record if the buyer is also a contact),
//   created_by: {id, name, branch}
//   created_at

import '../core/utils/formatters.dart';

/// A past sale, as returned by GET /sales or GET /sales/{id}.
class Sale {
  const Sale({
    required this.id,
    required this.name,
    required this.createdAt,
    this.purchaseDate,
    this.phone,
    this.altPhone,
    this.address,
    this.purchasedProduct,
    this.contactId,
    this.createdByEmployeeId,
    this.createdByName,
    this.createdByBranch,
  });

  final int id;

  /// The buyer's name. Always present (required by the API).
  final String name;

  /// When the product was bought. Null if not recorded.
  final DateTime? purchaseDate;

  final String? phone;
  final String? altPhone;
  final String? address;

  /// The product that was sold. Free text (or chosen from suggestions).
  final String? purchasedProduct;

  /// Links to a contacts record if the buyer is also tracked as a contact.
  final int? contactId;

  final int? createdByEmployeeId;

  /// The name of the employee who recorded this sale.
  final String? createdByName;
  final String? createdByBranch;

  final DateTime createdAt;

  String get displayName => name.trim().isEmpty ? '(No name)' : name.trim();

  factory Sale.fromJson(Map<String, dynamic> json) {
    final createdBy = json['created_by'];
    final createdByMap = createdBy is Map<String, dynamic> ? createdBy : null;
    return Sale(
      id: asInt(json['id']) ?? 0,
      name: asText(json['name']) ?? '',
      purchaseDate: _parseDate(asText(json['purchase_date'])),
      phone: asText(json['phone']),
      altPhone: asText(json['alt_phone']),
      address: asText(json['address']),
      purchasedProduct: asText(json['purchased_product']),
      contactId: asInt(json['contact_id']),
      createdByEmployeeId:
          asInt(json['created_by_employee_id']) ??
          (createdByMap != null ? asInt(createdByMap['id']) : null),
      createdByName: createdByMap != null ? asText(createdByMap['name']) : null,
      createdByBranch:
          createdByMap != null ? asText(createdByMap['branch']) : null,
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

/// Payload for POST /sales (create) and PUT /sales/{id} (update).
///
/// All fields are optional for editing: only the fields the user changed are sent.
/// [name] is required for create.
class SaleDraft {
  SaleDraft({
    this.name = '',
    this.phone,
    this.altPhone,
    this.address,
    this.purchasedProduct,
    this.purchaseDate,
    this.createdByEmployeeId,
  });

  String name;
  String? phone;
  String? altPhone;
  String? address;
  String? purchasedProduct;

  /// ISO-8601 date string (YYYY-MM-DD). The backend stores only the date, not time.
  String? purchaseDate;

  int? createdByEmployeeId;

  factory SaleDraft.fromSale(Sale sale) {
    return SaleDraft(
      name: sale.name,
      phone: sale.phone,
      altPhone: sale.altPhone,
      address: sale.address,
      purchasedProduct: sale.purchasedProduct,
      purchaseDate: sale.purchaseDate != null
          ? '${sale.purchaseDate!.year.toString().padLeft(4, '0')}-'
              '${sale.purchaseDate!.month.toString().padLeft(2, '0')}-'
              '${sale.purchaseDate!.day.toString().padLeft(2, '0')}'
          : null,
      createdByEmployeeId: sale.createdByEmployeeId,
    );
  }

  /// The request body sent to POST /sales or PUT /sales/{id}.
  /// For update (PUT), pass [forUpdate: true] so only filled fields are included.
  Map<String, dynamic> toApiJson({bool forUpdate = false}) {
    final body = <String, dynamic>{};
    void put(String key, Object? value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      body[key] = value is String ? value.trim() : value;
    }

    // For create, name is required. For update, only send what changed.
    if (!forUpdate || name.trim().isNotEmpty) {
      put('name', name);
    }
    put('phone', phone);
    put('alt_phone', altPhone);
    put('address', address);
    put('purchased_product', purchasedProduct);
    put('purchase_date', purchaseDate);
    put('created_by_employee_id', createdByEmployeeId);

    return body;
  }
}

/// One page of sales from GET /sales.
class SalePage {
  const SalePage({
    required this.sales,
    required this.total,
    required this.skip,
    required this.limit,
  });

  final List<Sale> sales;
  final int total;
  final int skip;
  final int limit;

  int get page => (skip ~/ limit) + 1;
  int get totalPages =>
      total == 0 ? 1 : (total + limit - 1) ~/ limit;

  factory SalePage.fromJson(Map<String, dynamic> json) {
    final rows = (json['items'] as List?) ?? const [];
    return SalePage(
      sales: rows
          .whereType<Map<String, dynamic>>()
          .map(Sale.fromJson)
          .toList(growable: false),
      total: asInt(json['total']) ?? 0,
      skip: asInt(json['skip']) ?? 0,
      limit: (asInt(json['limit']) ?? 20).clamp(1, 100),
    );
  }
}
