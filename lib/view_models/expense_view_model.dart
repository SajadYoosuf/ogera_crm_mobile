/// ExpenseViewModel manages the Expenses screen's state.
///
/// Staff can:
///   • view their own expense list
///   • create a new pending expense (optionally attach a bill photo)
///   • delete a pending expense
///
/// Managers/admins additionally can:
///   • see all staff expenses
///   • approve or reject an expense with a reason
///
/// The backend enforces the role rules — no extra check needed here.
library;

import 'package:flutter/foundation.dart';

import '../models/expense.dart';
import '../services/expense_service.dart';

class ExpenseViewModel extends ChangeNotifier {
  ExpenseViewModel(this._service);

  final ExpenseService _service;

  bool _isLoading = false;
  bool _isMutating = false;
  String? _error;

  final List<Expense> _expenses = [];
  ExpenseStatus? _statusFilter;

  List<Expense> get expenses => List.unmodifiable(_expenses);
  bool get isLoading => _isLoading;
  bool get isMutating => _isMutating;
  String? get error => _error;
  ExpenseStatus? get statusFilter => _statusFilter;

  /// Loads the expense list from the server.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _expenses
        ..clear()
        ..addAll(await _service.list(status: _statusFilter));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filters by status, then reloads.
  Future<void> setStatusFilter(ExpenseStatus? status) async {
    _statusFilter = (_statusFilter == status) ? null : status;
    await load();
  }

  /// Creates a new expense claim and prepends it to the list.
  Future<bool> create(ExpenseDraft draft) async {
    _isMutating = true;
    _error = null;
    notifyListeners();
    try {
      final expense = await _service.create(draft);
      _expenses.insert(0, expense);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  /// Deletes a pending expense.
  Future<bool> delete(int id) async {
    _isMutating = true;
    _error = null;
    notifyListeners();
    try {
      await _service.delete(id);
      _expenses.removeWhere((e) => e.id == id);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  /// Approves an expense; replaces the old row in the list.
  Future<bool> approve(int id) async {
    return _review(() => _service.approve(id));
  }

  /// Rejects an expense with a reason; replaces the old row in the list.
  Future<bool> reject(int id, {required String reason}) async {
    return _review(() => _service.reject(id, reason: reason));
  }

  /// Uploads a bill photo for an expense and updates the row in the list.
  Future<bool> uploadBill(
    int id, {
    required String localPath,
    String mimeType = 'image/jpeg',
  }) async {
    return _review(
      () => _service.uploadBill(id, localPath: localPath, mimeType: mimeType),
    );
  }

  Future<bool> _review(Future<Expense> Function() action) async {
    _isMutating = true;
    _error = null;
    notifyListeners();
    try {
      final updated = await action();
      final idx = _expenses.indexWhere((e) => e.id == updated.id);
      if (idx != -1) {
        _expenses[idx] = updated;
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }
}
