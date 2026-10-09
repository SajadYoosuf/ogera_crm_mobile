import '../core/utils/formatters.dart';

/// Option lists for the sale form. The API's `sales` register only keeps the
/// date, buyer, phones, address and purchased product, so the fields below
/// are kept for the screens that still show them but are never sent.
class SaleOptions {
  const SaleOptions._();

  static const sourcesOfSale = <String, String>{
    'direct_call': 'Direct Call',
    'walk_in': 'Walk-in',
    'referral': 'Referral',
    'facebook': 'Facebook Ads',
    'google': 'Google',
    'other': 'Other',
  };

  static const houseStages = <String, String>{
    'under_construction': 'Under construction',
    'built': 'Built',
    'renovation': 'Renovation',
  };

  static const currentTanks = <String, String>{
    'plastic': 'Plastic',
    'other_ss': 'Other stainless steel',
    'none': 'None',
  };

  static const waterSources = <String, String>{
    'borewell': 'Borewell',
    'corporation': 'Corporation',
    'well': 'Open Well',
    'other': 'Other',
  };

  static String label(Map<String, String> options, String? value) =>
      value == null ? '—' : options[value] ?? humanizeSlug(value);
}

class Sale {
  const Sale({
    required this.id,
    required this.saleDate,
    required this.buyerName,
    required this.buyerPhone,
    this.address,
    this.panchayath,
    this.ward,
    this.tankSize,
    this.quantity,
    this.unitPrice,
    this.totalPrice,
    this.houseStage,
    this.currentTank,
    this.waterSource,
    this.sourceOfSale,
    this.engineerName,
    this.engineerPhone,
    this.plumberName,
    this.plumberPhone,
    this.contactId,
    this.enteredBy,
    this.remarks,
    this.createdAt,
  });

  final int id;
  final String saleDate;
  final String buyerName;
  final String buyerPhone;
  final String? address;
  final String? panchayath;
  final String? ward;
  final String? tankSize;
  final int? quantity;
  final double? unitPrice;
  final double? totalPrice;
  final String? houseStage;
  final String? currentTank;
  final String? waterSource;
  final String? sourceOfSale;
  final String? engineerName;
  final String? engineerPhone;
  final String? plumberName;
  final String? plumberPhone;
  final int? contactId;
  final String? enteredBy;
  final String? remarks;
  final DateTime? createdAt;

  DateTime? get saleDateTime => DateTime.tryParse(saleDate);

  String? get referralSummary {
    final parts = <String>[];
    if ((engineerName ?? '').isNotEmpty) parts.add('Engineer: $engineerName');
    if ((plumberName ?? '').isNotEmpty) parts.add('Plumber: $plumberName');
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// A row of `GET /sales`. The register's purchased product is the closest
  /// match for the old tank size, so it fills that slot.
  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: asInt(json['id']) ?? 0,
      saleDate: asText(json['purchase_date']) ?? '',
      buyerName: asText(json['name']) ?? '',
      buyerPhone: asText(json['phone']) ?? '',
      address: asText(json['address']),
      tankSize: asText(json['purchased_product']),
      createdAt: parseDate(json['created_at']),
    );
  }
}

class SaleDraft {
  SaleDraft({
    String? saleDate,
    this.buyerName = '',
    this.buyerPhone = '',
    this.address,
    this.panchayath,
    this.ward,
    this.tankSize,
    this.quantity,
    this.unitPrice,
    this.houseStage,
    this.currentTank,
    this.waterSource,
    this.sourceOfSale,
    this.engineerName,
    this.engineerPhone,
    this.plumberName,
    this.plumberPhone,
    this.contactId,
    this.remarks,
  }) : saleDate = saleDate ?? todayIso();

  String saleDate;
  String buyerName;
  String buyerPhone;
  String? address;
  String? panchayath;
  String? ward;
  String? tankSize;
  int? quantity;
  double? unitPrice;
  String? houseStage;
  String? currentTank;
  String? waterSource;
  String? sourceOfSale;
  String? engineerName;
  String? engineerPhone;
  String? plumberName;
  String? plumberPhone;
  int? contactId;
  String? remarks;

  /// Total is derived, never typed — the ledger should never disagree with
  /// quantity times unit price.
  double get total => (quantity ?? 0) * (unitPrice ?? 0);

  factory SaleDraft.fromSale(Sale sale) {
    return SaleDraft(
      saleDate: sale.saleDate.isEmpty ? todayIso() : sale.saleDate,
      buyerName: sale.buyerName,
      buyerPhone: sale.buyerPhone,
      address: sale.address,
      panchayath: sale.panchayath,
      ward: sale.ward,
      tankSize: sale.tankSize,
      quantity: sale.quantity,
      unitPrice: sale.unitPrice,
      houseStage: sale.houseStage,
      currentTank: sale.currentTank,
      waterSource: sale.waterSource,
      sourceOfSale: sale.sourceOfSale,
      engineerName: sale.engineerName,
      engineerPhone: sale.engineerPhone,
      plumberName: sale.plumberName,
      plumberPhone: sale.plumberPhone,
      contactId: sale.contactId,
      remarks: sale.remarks,
    );
  }

  /// The `POST /sales` / `PUT /sales/{id}` body.
  Map<String, dynamic> toApiJson() {
    final json = <String, dynamic>{
      'purchase_date': saleDate,
      'name': buyerName.trim(),
    };
    void put(String key, String? value) {
      if (value == null || value.trim().isEmpty) return;
      json[key] = value.trim();
    }

    put('phone', buyerPhone);
    put('address', address);
    put('purchased_product', tankSize);
    return json;
  }
}

class SalePage {
  const SalePage({
    required this.sales,
    required this.total,
    required this.page,
    required this.totalPages,
    required this.totalRevenue,
    required this.totalTanks,
    required this.activePanchayaths,
  });

  final List<Sale> sales;
  final int total;
  final int page;
  final int totalPages;
  final double totalRevenue;
  final int totalTanks;
  final int activePanchayaths;

  /// `GET /sales` pages by `skip`/`limit`. The register has no price or
  /// quantity columns, so the revenue and tank totals stay at zero.
  factory SalePage.fromJson(Map<String, dynamic> json) {
    final rows = (json['items'] as List?) ?? const [];
    final total = asInt(json['total']) ?? 0;
    final limit = (asInt(json['limit']) ?? 20).clamp(1, 1 << 20);
    final skip = asInt(json['skip']) ?? 0;
    return SalePage(
      sales: rows
          .whereType<Map<String, dynamic>>()
          .map(Sale.fromJson)
          .toList(growable: false),
      total: total,
      page: skip ~/ limit + 1,
      totalPages: total == 0 ? 1 : (total + limit - 1) ~/ limit,
      totalRevenue: 0,
      totalTanks: 0,
      activePanchayaths: 0,
    );
  }
}

/// A product name seen in the sales register, offered as a suggestion.
class ProductOption {
  const ProductOption({
    required this.id,
    required this.name,
    this.price,
    this.size,
  });

  final int id;
  final String name;
  final double? price;
  final String? size;

  /// `GET /sales/products` answers with plain product names.
  factory ProductOption.fromName(String name, int index) =>
      ProductOption(id: index + 1, name: name);
}
