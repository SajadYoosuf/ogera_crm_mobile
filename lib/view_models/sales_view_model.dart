// sales_view_model.dart
//
// State manager for the Sales tab.
//
// WHAT IT DOES:
//   - Holds the paged list of past sales from GET /sales.
//   - Filters: free-text search, product name, date range.
//   - Exposes create, update, and delete actions.
//   - Falls back to the SQLite cache (SalesCache) when the device is offline.
//   - Queues offline write actions (create/edit/delete) in SalesCache.pending_sales
//     and replays them when the device is back online.
//
// OFFLINE WRITE QUEUE:
//   When a create/edit/delete fails because of no internet, the action is saved
//   to the local `pending_sales` table. On the next successful load(), all queued
//   actions are replayed first, then the fresh list is fetched.
//
// GLITCH GUARDS:
//   A sequence counter prevents a slow API response from overwriting a newer one.
//   Failed actions return an error message to the caller instead of showing an error
//   on the list (the same pattern as TasksViewModel).

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../local_db/sales_cache.dart';
import '../models/sale.dart';
import '../services/sales_service.dart';

class SalesViewModel extends ChangeNotifier {
  SalesViewModel(this._service, {SalesCache? cache})
    : _cache = cache ?? SalesCache();

  final SalesService _service;
  final SalesCache _cache;

  static const _pageSize = 20;

  final List<Sale> _sales = [];
  int _sequence = 0;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isOffline = false;
  String? _error;

  String _query = '';
  String? _productFilter;
  String? _fromDate;
  String? _toDate;

  int _skip = 0;
  int _total = 0;
  int _totalPages = 1;
  int _currentPage = 1;

  /// Suggestions for the product autocomplete, loaded once per session.
  List<String> _productSuggestions = [];

  // ── Getters ──────────────────────────────────────────────────────────────

  List<Sale> get sales => List.unmodifiable(_sales);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  /// True when the displayed list came from the local cache, not the server.
  bool get isOffline => _isOffline;
  String? get error => _error;
  String get query => _query;
  String? get productFilter => _productFilter;
  String? get fromDate => _fromDate;
  String? get toDate => _toDate;
  int get total => _total;
  bool get hasMore => _currentPage < _totalPages;
  List<String> get productSuggestions => List.unmodifiable(_productSuggestions);

  bool get hasFilters =>
      _productFilter != null || _fromDate != null || _toDate != null;

  // ── Loading ───────────────────────────────────────────────────────────────

  /// Initial load and pull-to-refresh. Replays offline queue first, then fetches.
  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    // Replay pending offline actions before fetching fresh data.
    await _replayPending();

    _skip = 0;
    await _fetch(skip: 0, replace: true);
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    await _fetch(skip: _skip + _pageSize, replace: false);
  }

  void setSearch(String value) {
    _query = value.trim();
    load(silent: false);
  }

  void applyFilters({
    String? product,
    String? fromDate,
    String? toDate,
    bool clearProduct = false,
    bool clearDates = false,
  }) {
    _productFilter = clearProduct ? null : (product ?? _productFilter);
    if (clearDates) {
      _fromDate = null;
      _toDate = null;
    } else {
      _fromDate = fromDate ?? _fromDate;
      _toDate = toDate ?? _toDate;
    }
    load();
  }

  void clearFilters() {
    _productFilter = null;
    _fromDate = null;
    _toDate = null;
    load();
  }

  /// Loads the product name suggestions for the search autocomplete.
  /// Called once when the tab opens; failures are silently ignored.
  Future<void> loadProductSuggestions() async {
    try {
      _productSuggestions = await _service.products();
      notifyListeners();
    } on Exception {
      // Non-critical — suggestions are a nice-to-have.
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Creates a new sale. Returns null on success or an error message.
  /// If the device is offline, queues the action for the next sync.
  Future<String?> create(SaleDraft draft) async {
    try {
      final saved = await _service.create(draft);
      _sales.insert(0, saved);
      _total++;
      // Update cache with the new list.
      await _saveSalesToCache();
      notifyListeners();
      return null;
    } on SocketException {
      // Offline — queue the create action and show it optimistically.
      await _cache.queueAction(
        type: SalesPendingActionType.create,
        payload: draft.toApiJson(),
      );
      return null; // Treat as success; a banner will say "saved offline".
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save the sale. Please try again.';
    }
  }

  /// Updates an existing sale. Returns null on success or an error message.
  Future<String?> update(int id, SaleDraft draft) async {
    try {
      final saved = await _service.update(id, draft);
      final index = _sales.indexWhere((s) => s.id == id);
      if (index != -1) _sales[index] = saved;
      await _saveSalesToCache();
      notifyListeners();
      return null;
    } on SocketException {
      await _cache.queueAction(
        type: SalesPendingActionType.update,
        saleId: id,
        payload: draft.toApiJson(forUpdate: true),
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not update the sale. Please try again.';
    }
  }

  /// Deletes a sale. Returns null on success or an error message.
  Future<String?> delete(int id) async {
    try {
      await _service.delete(id);
      _sales.removeWhere((s) => s.id == id);
      _total = (_total - 1).clamp(0, 1 << 30);
      await _saveSalesToCache();
      notifyListeners();
      return null;
    } on SocketException {
      await _cache.queueAction(
        type: SalesPendingActionType.delete,
        saleId: id,
        payload: {},
      );
      // Remove from the displayed list immediately (optimistic).
      _sales.removeWhere((s) => s.id == id);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not delete the sale. Please try again.';
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _fetch({required int skip, required bool replace}) async {
    final sequence = ++_sequence;
    try {
      final page = await _service.list(
        search: _query.isEmpty ? null : _query,
        product: _productFilter,
        from: _fromDate,
        to: _toDate,
        skip: skip,
        limit: _pageSize,
      );

      if (sequence != _sequence) return;

      if (replace) {
        _sales
          ..clear()
          ..addAll(page.sales);
      } else {
        _sales.addAll(page.sales);
      }
      _skip = skip + page.sales.length;
      _total = page.total;
      _totalPages = page.totalPages;
      _currentPage = page.page;
      _error = null;
      _isOffline = false;

      // Cache the first page when no filters are active.
      if (replace && !hasFilters && _query.isEmpty) {
        await _saveSalesToCache();
      }
    } on SocketException {
      if (sequence != _sequence) return;
      if (replace) {
        final cached = await _cache.load();
        _sales
          ..clear()
          ..addAll(cached.map(_saleFromRaw).whereType<Sale>());
        _isOffline = true;
        _error = _sales.isEmpty ? 'No internet connection.' : null;
      }
    } on ApiException catch (e) {
      if (sequence != _sequence) return;
      _error = e.message;
      _isOffline = false;
      if (replace) _sales.clear();
    } finally {
      if (sequence == _sequence) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  // Replays pending offline actions, oldest first.
  // Errors during replay are silently ignored — the server may have already
  // processed the action, or the data may have been deleted in the meantime.
  Future<void> _replayPending() async {
    final actions = await _cache.pendingActions();
    for (final action in actions) {
      try {
        switch (action.type) {
          case SalesPendingActionType.create:
            final draft = _draftFromPayload(action.payload);
            await _service.create(draft);
          case SalesPendingActionType.update:
            if (action.saleId != null) {
              final draft = _draftFromPayload(action.payload);
              await _service.update(action.saleId!, draft);
            }
          case SalesPendingActionType.delete:
            if (action.saleId != null) {
              await _service.delete(action.saleId!);
            }
        }
        // Successfully replayed — remove from the queue.
        if (action.id != null) {
          await _cache.removePending(action.id!);
        }
      } on SocketException {
        // Still offline — stop replaying and try again later.
        break;
      } on ApiException {
        // The action was rejected by the server (e.g. duplicate, deleted id).
        // Remove it so it does not block future syncs.
        if (action.id != null) {
          await _cache.removePending(action.id!);
        }
      }
    }
  }

  Future<void> _saveSalesToCache() async {
    final raws = _sales.map(_saleToRaw).toList();
    await _cache.save(raws);
  }

  // Converts a Sale to a raw JSON map the cache stores.
  static Map<String, dynamic> _saleToRaw(Sale s) => {
    'id': s.id,
    'name': s.name,
    'phone': s.phone,
    'alt_phone': s.altPhone,
    'address': s.address,
    'purchased_product': s.purchasedProduct,
    'purchase_date': s.purchaseDate?.toIso8601String().substring(0, 10),
    'created_by_employee_id': s.createdByEmployeeId,
    if (s.createdByName != null)
      'created_by': {'id': s.createdByEmployeeId, 'name': s.createdByName, 'branch': s.createdByBranch},
    'created_at': s.createdAt.toIso8601String(),
  };

  // Reconstructs a Sale from a raw cache map.
  static Sale? _saleFromRaw(Map<String, dynamic> raw) {
    try {
      return Sale.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  static SaleDraft _draftFromPayload(Map<String, dynamic> payload) {
    return SaleDraft(
      name: (payload['name'] as String?) ?? '',
      phone: payload['phone'] as String?,
      altPhone: payload['alt_phone'] as String?,
      address: payload['address'] as String?,
      purchasedProduct: payload['purchased_product'] as String?,
      purchaseDate: payload['purchase_date'] as String?,
      createdByEmployeeId: payload['created_by_employee_id'] as int?,
    );
  }

  /// Returns the pending action count (for showing a "X changes pending sync" badge).
  Future<int> pendingCount() async {
    return (await _cache.pendingActions()).length;
  }
}
