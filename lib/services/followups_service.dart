// followups_service.dart
//
// Handles all API calls for the follow-up board (leads pipeline).
//
// A "lead" is a consumer contact that has a pipeline stage (new_lead → won/lost).
// A "follow-up" is a scheduled task that gives the lead its due date on the board.
//
// What this service does:
//   - Fetches all leads and their earliest open follow-up date in one go
//   - Updates a lead's stage, owner, or next follow-up date
//   - Adds remarks (internal notes) and new follow-ups to a lead's timeline
//   - Fetches the pipeline stage list

import '../core/network/api_client.dart';
import '../core/utils/formatters.dart'; // asText, asInt, asList, asMap, isoDate
import '../models/followup.dart';
import '../models/lead_work.dart';

// ── Pagination helper ──────────────────────────────────────────────────────

/// Fetches every page from an endpoint that returns { items, total }.
/// Used when we need the full list, not just one page (e.g. all leads on the board).
///
/// [pageSize] controls how many rows each request fetches.
/// [maxPages] is a safety cap so a runaway endpoint can't loop forever.
Future<List<Map<String, dynamic>>> _fetchAll(
  ApiClient api,
  String path,
  Map<String, dynamic> query, {
  int pageSize = 100,
  int maxPages = 20,
}) async {
  final rows = <Map<String, dynamic>>[];
  for (var page = 0; page < maxPages; page++) {
    final data = asMap(
      await api.get(
        path,
        query: {...query, 'skip': page * pageSize, 'limit': pageSize},
      ),
    );
    final items = asList(data['items']);
    rows.addAll(items);
    final total = asInt(data['total']) ?? rows.length;
    // A short page (fewer items than the page size) means we have reached the end.
    if (items.length < pageSize || rows.length >= total) break;
  }
  return rows;
}

// ── FollowupsService ───────────────────────────────────────────────────────

/// API calls for the follow-up board screen.
class FollowupsService {
  const FollowupsService(this._api);

  final ApiClient _api;

  // Pipeline stages are managed by admin from the web app — the mobile app
  // shows them but cannot create or reorder them.
  static const _fixedStages = ApiException(
    'The pipeline stages are fixed and cannot be edited from the app.',
  );

  /// All consumer contacts plus the earliest open follow-up date for each.
  /// Fetches contacts and open tasks in parallel, then joins them in memory.
  Future<List<Lead>> leads() async {
    final results = await Future.wait([
      _fetchAll(_api, '/contacts', {'contact_type': 'consumer'}),
      _openTaskDates(),
    ]);
    final dueByContact = results[1] as Map<int, String>;
    return (results[0] as List<Map<String, dynamic>>)
        .map(Lead.fromJson)
        .map((lead) => lead.withDueDate(dueByContact[lead.id]))
        .toList(growable: false);
  }

  /// Returns the earliest open follow-up date per contact id.
  /// Overdue tasks are included (include_overdue: true).
  /// The API automatically narrows staff sessions to their own tasks.
  Future<Map<int, String>> _openTaskDates() async {
    final today = DateTime.now();
    final data = await _api.get(
      '/tasks',
      query: {
        'status': 'open',
        'date_from': isoDate(today),
        'date_to': isoDate(today.add(const Duration(days: 60))),
        'include_overdue': true,
        'limit': 1000,
      },
    );
    final earliest = <int, String>{};
    for (final task in asList(asMap(data)['items'])) {
      final contactId = asInt(task['contact_id']);
      final date = asText(task['scheduled_date']);
      if (contactId == null || date == null) continue;
      final current = earliest[contactId];
      // Keep the earliest date when a contact has more than one open follow-up.
      if (current == null || date.compareTo(current) < 0) {
        earliest[contactId] = date;
      }
    }
    return earliest;
  }

  /// Pipeline stages from the server, sorted by their display order.
  Future<List<Stage>> stages() async {
    final data = await _api.get('/pipeline/stages');
    return asList(data).map(Stage.fromJson).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  /// Updates one or more fields on a lead. Only sends what changed, so other
  /// fields are never accidentally cleared.
  ///
  /// The backend cannot unassign a lead or remove a follow-up, so those
  /// operations throw a user-facing error with a clear message.
  Future<void> updateLead(
    int id, {
    String? stage,
    String? assignedTo,
    bool clearAssignee = false,
    String? dueDate,
    bool clearDueDate = false,
  }) async {
    if (clearAssignee) {
      throw const ApiException(
        'Every lead needs an owner. Pick a staff member to reassign it.',
      );
    }
    if (clearDueDate) {
      throw const ApiException(
        'A follow-up date cannot be removed. Reschedule it or mark it done.',
      );
    }

    if (stage != null) {
      await _api.post(
        '/contacts/$id/stages',
        body: {
          'stage': stage,
          'changed_by': _api.currentUserId,
          // The backend requires a loss_reason for every "lost" stage move.
          if (stage == 'lost') 'loss_reason': 'other',
        },
      );
    }

    final newOwner = int.tryParse(assignedTo ?? '');
    if (newOwner != null) {
      await _api.put('/contacts/$id', body: {'assigned_to': newOwner});
    }

    if (dueDate != null) {
      await _scheduleFollowup(id, dueDate, owner: newOwner);
    }
  }

  /// Reschedules the lead's existing open follow-up, or books a new call if
  /// it has none. Due time is set to 23:59 (end of day), same as the web app.
  Future<void> _scheduleFollowup(int id, String date, {int? owner}) async {
    final rows = asList(await _api.get('/contacts/$id/followups'));
    final open =
        rows
            .map(asMap)
            .where((f) => asText(f['status']) != 'completed')
            .toList()
          ..sort(
            (a, b) => (asText(a['due_at']) ?? '').compareTo(
              asText(b['due_at']) ?? '',
            ),
          );
    final dueAt = '${date}T23:59:00';
    if (open.isNotEmpty) {
      // Move the earliest open follow-up.
      await _api.patch(
        '/contacts/$id/followups/${open.first['id']}',
        body: {'due_at': dueAt},
      );
      return;
    }
    // No open follow-up — book a phone call.
    final assignee =
        owner ??
        asInt(asMap(await _api.get('/contacts/$id'))['assigned_to']) ??
        _api.currentUserId;
    await _api.post(
      '/contacts/$id/followups',
      body: {'channel': 'phone_call', 'due_at': dueAt, 'assigned_to': assignee},
    );
  }

  /// The lead's full activity history, newest first.
  /// Includes notes, follow-ups, stage changes, and owner changes.
  Future<List<Remark>> remarks(int leadId) async {
    final rows = asList(await _api.get('/contacts/$leadId/history'));
    return [
      for (var i = 0; i < rows.length; i++)
        Remark.fromHistory(LeadHistoryEntry.fromJson(asMap(rows[i])), i + 1),
    ];
  }

  /// Adds an internal note to the lead's timeline.
  Future<void> addRemark(int leadId, String remark) {
    return _api.post(
      '/contacts/$leadId/activities',
      body: {'activity_type': 'internal_note', 'notes': remark},
    );
  }

  /// Books a new follow-up without touching the existing open one.
  /// Use [updateLead] with a dueDate to reschedule an existing follow-up instead.
  Future<void> addFollowup(
    int contactId, {
    required String date,
    int? assignedTo,
    String type = 'phone_call',
    String? notes,
  }) async {
    await _api.post(
      '/contacts/$contactId/followups',
      body: {
        'channel': type,
        'due_at': '${date}T23:59:00',
        'assigned_to': assignedTo ?? _api.currentUserId,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<void> deleteLead(int id) => _api.delete('/contacts/$id');

  // Stage creation and reordering are not supported from the mobile app.
  Future<Stage> createStage(String label) => Future.error(_fixedStages);
  Future<void> updateStage(String id, {String? label, int? orderIndex}) =>
      Future.error(_fixedStages);
}
