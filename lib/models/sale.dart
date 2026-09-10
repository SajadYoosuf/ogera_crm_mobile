import '../core/utils/formatters.dart';

/// These three lists mirror the ENUM columns on the `sales` table, so a value
/// the app offers is always a value the column accepts.
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

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: asInt(json['id']) ?? 0,
      saleDate: asText(json['saleDate']) ?? '',
      buyerName: asText(json['buyerName']) ?? '',
      buyerPhone: asText(json['buyerPhone']) ?? '',
      address: asText(json['address']),
      panchayath: asText(json['panchayath']),
      ward: asText(json['ward']),
      tankSize: asText(json['tankSize']),
      quantity: asInt(json['quantity']),
      unitPrice: asDouble(json['unitPrice']),
      totalPrice: asDouble(json['totalPrice']),
      houseStage: asText(json['houseStage']),
      currentTank: asText(json['currentTank']),
      waterSource: asText(json['waterSource']),
      sourceOfSale: asText(json['sourceOfSale']),
      engineerName: asText(json['engineerName']),
      engineerPhone: asText(json['engineerPhone']),
      plumberName: asText(json['plumberName']),
      plumberPhone: asText(json['plumberPhone']),
      contactId: asInt(json['contactId']),
      enteredBy: asText(json['enteredBy']),
      remarks: asText(json['remarks']),
      createdAt: parseDate(json['createdAt']),
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

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'saleDate': saleDate,
      'buyerName': buyerName.trim(),
      'buyerPhone': buyerPhone.trim(),
    };
    void put(String key, Object? value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      json[key] = value is String ? value.trim() : value;
    }

    put('address', address);
    put('panchayath', panchayath);
    put('ward', ward);
    put('tankSize', tankSize);
    put('quantity', quantity);
    put('unitPrice', unitPrice);
    put('houseStage', houseStage);
    put('currentTank', currentTank);
    put('waterSource', waterSource);
    put('sourceOfSale', sourceOfSale);
    put('engineerName', engineerName);
    put('engineerPhone', engineerPhone);
    put('plumberName', plumberName);
    put('plumberPhone', plumberPhone);
    put('contactId', contactId);
    put('remarks', remarks);
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

  factory SalePage.fromJson(Map<String, dynamic> json) {
    final rows = (json['sales'] as List?) ?? const [];
    return SalePage(
      sales: rows
          .whereType<Map<String, dynamic>>()
          .map(Sale.fromJson)
          .toList(growable: false),
      total: asInt(json['total']) ?? 0,
      page: asInt(json['page']) ?? 1,
      totalPages: asInt(json['totalPages']) ?? 1,
      totalRevenue: asDouble(json['totalRevenue']) ?? 0,
      totalTanks: asInt(json['totalTanks']) ?? 0,
      activePanchayaths: asInt(json['activePanchayaths']) ?? 0,
    );
  }
}

/// Read-only catalogue entry from the existing Venting Next products table.
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

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    return ProductOption(
      id: asInt(json['id']) ?? 0,
      name: asText(json['name']) ?? asText(json['title']) ?? 'Product',
      price:
          asDouble(json['priceSale']) ??
          asDouble(json['price']) ??
          asDouble(json['unitPrice']),
      size:
          asText(json['size']) ??
          asText(json['tankSize']) ??
          asText(json['capacity']),
    );
  }
}
