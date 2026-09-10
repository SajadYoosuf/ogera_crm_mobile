import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/sale.dart';
import '../services/crm_services.dart';

/// Head-only. The Sales Ledger tab is not built for a staff session at all, so
/// this view model is never constructed for one.
class SalesViewModel extends ChangeNotifier {
  SalesViewModel(this._service);

  final SalesService _service;

  static const _pageSize = 20;
  static const _debounce = Duration(milliseconds: 350);

  final List<Sale> _sales = [];
  Timer? _debounceTimer;
  int _sequence = 0;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  String _query = '';
  String? _panchayath;
  String? _ward;
  String? _waterSource;
  String? _sourceOfSale;
  String? _startDate;
  String? _endDate;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  double _totalRevenue = 0;
  int _totalTanks = 0;
  int _activePanchayaths = 0;

  List<Sale> get sales => List.unmodifiable(_sales);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _page < _totalPages;
  String? get error => _error;
  String get query => _query;
  String? get panchayath => _panchayath;
  String? get ward => _ward;
  String? get waterSource => _waterSource;
  String? get sourceOfSale => _sourceOfSale;
  String? get startDate => _startDate;
  String? get endDate => _endDate;
  int get total => _total;
  double get totalRevenue => _totalRevenue;
  int get totalTanks => _totalTanks;
  int get activePanchayaths => _activePanchayaths;

  bool get hasFilters =>
      _panchayath != null ||
      _ward != null ||
      _waterSource != null ||
      _sourceOfSale != null ||
      _startDate != null ||
      _endDate != null;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    await _fetch(page: 1, replace: true);
  }

  Future<void> refresh() => _fetch(page: 1, replace: true);

  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    await _fetch(page: _page + 1, replace: false);
  }

  void search(String value) {
    _query = value.trim();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, load);
  }

  void applyFilters({
    String? panchayath,
    String? ward,
    String? waterSource,
    String? sourceOfSale,
    String? startDate,
    String? endDate,
  }) {
    _panchayath = panchayath;
    _ward = ward;
    _waterSource = waterSource;
    _sourceOfSale = sourceOfSale;
    _startDate = startDate;
    _endDate = endDate;
    load();
  }

  void clearFilters() {
    _panchayath = null;
    _ward = null;
    _waterSource = null;
    _sourceOfSale = null;
    _startDate = null;
    _endDate = null;
    load();
  }

  Future<void> _fetch({required int page, required bool replace}) async {
    final sequence = ++_sequence;
    try {
      final result = await _service.list(
        query: _query.isEmpty ? null : _query,
        panchayath: _panchayath,
        ward: _ward,
        waterSource: _waterSource,
        sourceOfSale: _sourceOfSale,
        startDate: _startDate,
        endDate: _endDate,
        page: page,
        limit: _pageSize,
      );
      if (sequence != _sequence) return;
      if (replace) {
        _sales
          ..clear()
          ..addAll(result.sales);
      } else {
        _sales.addAll(result.sales);
      }
      _page = result.page;
      _totalPages = result.totalPages;
      _total = result.total;
      _totalRevenue = result.totalRevenue;
      _totalTanks = result.totalTanks;
      _activePanchayaths = result.activePanchayaths;
      _error = null;
    } on ApiException catch (error) {
      if (sequence != _sequence) return;
      _error = error.message;
      if (replace) _sales.clear();
    } finally {
      if (sequence == _sequence) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  void upsert(Sale sale) {
    final index = _sales.indexWhere((item) => item.id == sale.id);
    if (index == -1) {
      _sales.insert(0, sale);
      _total++;
    } else {
      _sales[index] = sale;
    }
    notifyListeners();
  }

  void removeById(int id) {
    _sales.removeWhere((sale) => sale.id == id);
    _total = (_total - 1).clamp(0, 1 << 30);
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

class SaleFormViewModel extends ChangeNotifier {
  SaleFormViewModel(this._service, {Sale? existing})
    : _existing = existing,
      draft = existing == null ? SaleDraft() : SaleDraft.fromSale(existing);

  final SalesService _service;
  final Sale? _existing;
  final SaleDraft draft;

  List<ProductOption> _products = const [];
  bool _isSaving = false;
  String? _error;

  bool get isEditing => _existing != null;
  bool get isSaving => _isSaving;
  String? get error => _error;

  /// The catalogue is read-only here; product management stays in Venting Next.
  List<ProductOption> get products => _products;

  Future<void> loadProducts() async {
    try {
      _products = await _service.products();
      notifyListeners();
    } on ApiException {
      // A missing catalogue must not block a manual sale entry.
      _products = const [];
    }
  }

  void applyProduct(ProductOption product) {
    draft.tankSize = product.size ?? product.name;
    if (product.price != null) draft.unitPrice = product.price;
    draft.quantity ??= 1;
    notifyListeners();
  }

  void setQuantity(int? quantity) {
    draft.quantity = quantity;
    notifyListeners();
  }

  void setUnitPrice(double? price) {
    draft.unitPrice = price;
    notifyListeners();
  }

  String? validateBuyerName(String? value) {
    if ((value ?? '').trim().length < 2) return 'Enter the buyer name.';
    return null;
  }

  String? validateBuyerPhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return 'Enter a valid phone number.';
    return null;
  }

  Future<Sale?> save() async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      return _existing == null
          ? await _service.create(draft)
          : await _service.update(_existing.id, draft);
    } on ApiException catch (error) {
      _error = error.message;
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
