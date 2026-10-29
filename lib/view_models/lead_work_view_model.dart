/// LeadWorkViewModel — state for the pipeline lead screen.
///
/// WHAT IT HOLDS
///   - Three lists for one contact: activities, follow-ups and history.
///     Each list starts as `null` (still loading), then becomes a real list
///     or keeps its last good value with an error message next to it.
///   - The activity type labels from Settings.
///   - [canWrite]: true for admin and manager on any lead, and for the assigned
///     employee on their own lead.
///   - [canChangeFollowup]: true for admin and manager, and for the assignee of
///     that follow-up. Used for Mark done and Reschedule.
///
/// THE ACCESS RULE (mirrors services/lead_access.py on the server)
/// Anyone who can open a lead can read its activity, follow-ups and history.
/// Admin and manager may log, schedule and change anything. Other employees may
/// log and schedule only on a lead assigned to them, and may change only the
/// follow-ups assigned to them. The screen hides buttons it must not show, and
/// every write method here refuses before it reaches the network. The server
/// makes the final decision either way.
///
/// HOW IT STAYS FAST
///   - [load] fetches the three lists in parallel, once, when the screen opens.
///   - After a write, only the lists that changed are fetched again. A booked
///     follow-up reloads follow-ups and history, not the activity log.
///   - Each list has its own error, so one failed request does not blank the
///     whole screen.
library;

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/reference/crm_options.dart';
import '../models/lead_work.dart';
import '../services/lead_work_service.dart';

class LeadWorkViewModel extends ChangeNotifier {
  LeadWorkViewModel({
    required LeadWorkService service,
    required this.contactId,
    required this.ownerId,
    required this.currentUserId,
    this.isHead = false,
  }) : _service = service;

  final LeadWorkService _service;

  /// The lead (a `contacts` row) this screen is about.
  final int contactId;

  /// The employee the lead is assigned to, or null when nobody owns it yet.
  final int? ownerId;

  /// The signed-in employee, or null if the session has no id.
  final int? currentUserId;

  /// True for admin and manager, who may work on any lead.
  final bool isHead;

  List<ActivityEntry>? _activities;
  String? _activitiesError;

  List<FollowupEntry>? _followups;
  String? _followupsError;

  List<LeadHistoryEntry>? _history;
  String? _historyError;

  Map<String, String> _activityTypeLabels = CrmOptions.defaultActivityTypes;

  List<ActivityEntry>? get activities => _activities;
  String? get activitiesError => _activitiesError;

  List<FollowupEntry>? get followups => _followups;
  String? get followupsError => _followupsError;

  List<LeadHistoryEntry>? get history => _history;
  String? get historyError => _historyError;

  /// Activity type labels, e.g. `{'phone_call': 'Phone call'}`.
  Map<String, String> get activityTypeLabels => _activityTypeLabels;

  /// True when the signed-in employee is the one this lead is assigned to.
  bool get isOwner => ownerId != null && ownerId == currentUserId;

  /// True when the signed-in employee may log activities and schedule follow-ups here.
  bool get canWrite => isHead || isOwner;

  /// True when the signed-in employee may mark [item] done or reschedule it.
  bool canChangeFollowup(FollowupEntry item) =>
      isHead || item.assignedTo == currentUserId;

  /// Opens the screen: fetches the lists in parallel.
  Future<void> load() async {
    await Future.wait([
      reloadActivities(),
      reloadFollowups(),
      reloadHistory(),
      _loadActivityTypes(),
    ]);
  }

  Future<void> reloadActivities() async {
    try {
      _activities = await _service.activities(contactId);
      _activitiesError = null;
    } on ApiException catch (error) {
      _activitiesError = error.message;
    } catch (_) {
      _activitiesError = 'Could not load the activity log.';
    }
    notifyListeners();
  }

  Future<void> reloadFollowups() async {
    try {
      _followups = await _service.followups(contactId);
      _followupsError = null;
    } on ApiException catch (error) {
      _followupsError = error.message;
    } catch (_) {
      _followupsError = 'Could not load the follow-ups.';
    }
    notifyListeners();
  }

  Future<void> reloadHistory() async {
    try {
      _history = await _service.history(contactId);
      _historyError = null;
    } on ApiException catch (error) {
      _historyError = error.message;
    } catch (_) {
      _historyError = 'Could not load the history.';
    }
    notifyListeners();
  }

  /// Called after the activity sheet saved a row. That sheet posts the row
  /// itself, so this only refreshes the lists it changed.
  Future<void> refreshAfterActivity() {
    return Future.wait([reloadActivities(), reloadHistory()]);
  }

  /// Books a follow-up for this lead. Returns null on success, or the message to show.
  Future<String?> scheduleFollowup(FollowupDraft draft) async {
    final denied = _denied();
    if (denied != null) return denied;
    try {
      await _service.scheduleFollowup(contactId, draft);
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not schedule the follow-up. Check your connection and try again.';
    }
    await Future.wait([reloadFollowups(), reloadHistory()]);
    return null;
  }

  /// Marks [item] done with an [outcome] (`done`, `not_now` or `no_answer`)
  /// and the notes of what happened. Returns null on success, or the message to show.
  Future<String?> completeFollowup(
    FollowupEntry item, {
    required String outcome,
    required String notes,
  }) async {
    final denied = _followupDenied(item);
    if (denied != null) return denied;
    try {
      await _service.completeFollowup(
        contactId,
        item.id,
        outcome: outcome,
        notes: notes,
      );
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not mark the follow-up done. Check your connection and try again.';
    }
    // Completing a follow-up writes an activity row too, so all three lists change.
    await Future.wait([reloadFollowups(), reloadActivities(), reloadHistory()]);
    return null;
  }

  /// Moves [item] to [dueAt]. Returns null on success, or the message to show.
  Future<String?> rescheduleFollowup(FollowupEntry item, DateTime dueAt) async {
    final denied = _followupDenied(item);
    if (denied != null) return denied;
    try {
      await _service.rescheduleFollowup(contactId, item.id, dueAt);
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not reschedule the follow-up. Check your connection and try again.';
    }
    await Future.wait([reloadFollowups(), reloadHistory()]);
    return null;
  }

  String? _denied() {
    if (canWrite) return null;
    return 'Only an admin, a manager or the assigned employee can add to this lead.';
  }

  String? _followupDenied(FollowupEntry item) {
    if (canChangeFollowup(item)) return null;
    return 'Only the assignee, an admin or a manager can change this follow-up.';
  }

  Future<void> _loadActivityTypes() async {
    try {
      _activityTypeLabels = await _service.activityTypes();
    } catch (_) {
      // The built-in list stays in place, so pickers are never empty.
    }
    notifyListeners();
  }
}
