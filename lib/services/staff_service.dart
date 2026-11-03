// staff_service.dart
//
// Fetches the list of staff members (employees) for use in assignee pickers
// and the follow-ups board "filter by staff" feature.
//
// What it does:
//   - GET /employees/directory → list of StaffMember (id, name, role)
//
// Why separate: staff data is used by FollowupsViewModel and PipelineViewModel
// to show who a lead is assigned to, and by the assign-staff picker.

import '../core/network/api_client.dart';
import '../models/followup.dart';

/// Fetches the directory of staff members the current user can assign leads to.
class StaffDirectoryService {
  const StaffDirectoryService(this._api);

  final ApiClient _api;

  /// Returns all active staff members, used to populate assignee pickers.
  Future<List<StaffMember>> list() async {
    final data = await _api.get('/employees/directory');
    return asList(data).map(StaffMember.fromJson).toList(growable: false);
  }
}
