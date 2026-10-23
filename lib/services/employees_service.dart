/// Employees service.
///
/// Wraps:
///   GET /employees/directory — active staff list (open to every signed-in employee)
///   GET /employees/{id}      — one employee's full profile (no password field)
library;

import '../core/network/api_client.dart';
import '../models/employee.dart';

class EmployeesService {
  EmployeesService(this._api);

  final ApiClient _api;

  /// Returns every active, non-deleted employee visible to the current user.
  ///
  /// Admin accounts are hidden by the backend. Managers also hide other managers.
  /// Each row has id, name, role, and phone — no password, no token.
  Future<List<EmployeeDirectoryEntry>> directory() async {
    final rows = await _api.get('/employees/directory');
    return asList(rows).map(EmployeeDirectoryEntry.fromJson).toList();
  }

  /// Loads one employee's full profile by [id].
  ///
  /// Used for the detail sheet. The backend never returns a password field.
  Future<EmployeeDetail> get(int id) async {
    final data = asMap(await _api.get('/employees/$id'));
    return EmployeeDetail.fromJson(data);
  }
}
