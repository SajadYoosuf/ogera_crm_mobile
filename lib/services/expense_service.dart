/// Expense service.
///
/// Wraps:
///   GET    /expenses          — list (own or all depending on role)
///   POST   /expenses          — create a new expense claim
///   DELETE /expenses/{id}     — delete a pending expense (own only)
///   POST   /expenses/{id}/approve — manager/admin approves
///   POST   /expenses/{id}/reject  — manager/admin rejects with reason
///   POST   /expenses/{id}/bill-photo — upload a receipt photo
library;

import '../core/network/api_client.dart';
import '../models/expense.dart';

class ExpenseService {
  ExpenseService(this._api);

  final ApiClient _api;

  /// Returns a list of expense claims.
  ///
  /// Staff see only their own; managers/admins see all (the backend enforces
  /// this via the JWT role — no extra parameter needed).
  Future<List<Expense>> list({ExpenseStatus? status}) async {
    final query = <String, dynamic>{
      if (status != null) 'status': status.value,
    };
    final data = asMap(await _api.get('/expenses', query: query));
    return asList(data['items']).map(Expense.fromJson).toList();
  }

  /// Creates a new expense claim.
  Future<Expense> create(ExpenseDraft draft) async {
    final data = asMap(await _api.post('/expenses', body: draft.toJson()));
    return Expense.fromJson(data);
  }

  /// Deletes a pending expense (staff can only delete their own pending claims).
  Future<void> delete(int id) async {
    await _api.delete('/expenses/$id');
  }

  /// Manager/admin approves an expense claim.
  Future<Expense> approve(int id) async {
    final data = asMap(await _api.post('/expenses/$id/approve'));
    return Expense.fromJson(data);
  }

  /// Manager/admin rejects an expense claim.
  ///
  /// [reason] is shown to the staff member who submitted the claim.
  Future<Expense> reject(int id, {required String reason}) async {
    final data = asMap(
      await _api.post('/expenses/$id/reject', body: {'reason': reason}),
    );
    return Expense.fromJson(data);
  }

  /// Uploads a receipt photo for an expense.
  ///
  /// [localPath] is the device file path from the image picker.
  /// [mimeType] is usually 'image/jpeg' or 'image/png'.
  /// Returns the updated expense (which now has [billPhotoUrl] set).
  Future<Expense> uploadBill(
    int id, {
    required String localPath,
    String mimeType = 'image/jpeg',
  }) async {
    final data = asMap(
      await _api.postFile(
        '/expenses/$id/bill-photo',
        fieldName: 'file',
        filePath: localPath,
        mimeType: mimeType,
      ),
    );
    return Expense.fromJson(data);
  }
}
