/// LeadWorkService — the HTTP calls behind the pipeline lead screen.
///
/// WHAT IT CALLS
///   GET   /contacts/{id}/activities          → activity log tab
///   GET   /contacts/{id}/followups           → follow-ups tab
///   GET   /contacts/{id}/history             → history tab
///   POST  /contacts/{id}/followups           → schedule a follow-up
///   PATCH /contacts/{id}/followups/{fid}     → mark a follow-up done
///   GET   /settings/enums/activity_type      → activity type labels (via the cached catalog)
///
/// Logging an activity is still done by [ActivityService.log], so the same
/// request code serves the Home quick-action sheet and this screen.
///
/// WHY THE SERVER DECIDES
/// The app hides the add buttons for leads that belong to someone else, but it
/// does not rely on that alone. The backend has the final say and returns a
/// 4xx with a message, which surfaces in the sheet.
library;

import '../core/network/api_client.dart';
import '../core/reference/crm_options.dart';
import '../models/lead_work.dart';
import 'crm_services.dart';

class LeadWorkService {
  LeadWorkService(this._api);

  final ApiClient _api;

  /// Logged activities, newest first (the server sorts them).
  Future<List<ActivityEntry>> activities(int contactId) async {
    final rows = asList(await _api.get('/contacts/$contactId/activities'));
    return rows
        .map((row) => ActivityEntry.fromJson(asMap(row)))
        .toList(growable: false);
  }

  /// Scheduled follow-ups for the contact, newest due date first.
  Future<List<FollowupEntry>> followups(int contactId) async {
    final rows = asList(await _api.get('/contacts/$contactId/followups'));
    return rows
        .map((row) => FollowupEntry.fromJson(asMap(row)))
        .toList(growable: false);
  }

  /// The combined timeline (stages, activities, follow-ups, owner changes), newest first.
  Future<List<LeadHistoryEntry>> history(int contactId) async {
    final rows = asList(await _api.get('/contacts/$contactId/history'));
    return rows
        .map((row) => LeadHistoryEntry.fromJson(asMap(row)))
        .toList(growable: false);
  }

  /// Books a new follow-up. Always adds one; it never overwrites an earlier plan.
  Future<void> scheduleFollowup(int contactId, FollowupDraft draft) async {
    await _api.post('/contacts/$contactId/followups', body: draft.toJson());
  }

  /// Marks one follow-up completed. The server also writes an activity row
  /// with [outcome] and [notes], so the Activity log tab shows it.
  Future<void> completeFollowup(
    int contactId,
    int followupId, {
    required String outcome,
    required String notes,
  }) async {
    await _api.patch(
      '/contacts/$contactId/followups/$followupId',
      body: {'status': 'completed', 'outcome': outcome, 'notes': notes.trim()},
    );
  }

  /// Moves an open follow-up to [dueAt]. Sent as a naive local time, like scheduling.
  Future<void> rescheduleFollowup(
    int contactId,
    int followupId,
    DateTime dueAt,
  ) async {
    await _api.patch(
      '/contacts/$contactId/followups/$followupId',
      body: {'due_at': naiveLocalIso(dueAt)},
    );
  }

  /// Activity type labels from Settings, falling back to the built-in list.
  /// Cached by [SettingsOptionsCatalog], so calling this again is cheap.
  Future<Map<String, String>> activityTypes() {
    return SettingsOptionsCatalog.of(
      _api,
    ).options('activity_type', fallback: CrmOptions.defaultActivityTypes);
  }
}
