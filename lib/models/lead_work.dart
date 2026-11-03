/// Data for the pipeline lead screen (activity log, follow-ups and history).
///
/// WHAT THIS FILE HOLDS
/// Plain Dart classes that mirror three backend responses for one contact:
///   GET /contacts/{id}/activities → [ActivityEntry]   (backend ActivityLogResponse)
///   GET /contacts/{id}/followups  → [FollowupEntry]   (backend FollowupScheduleResponse)
///   GET /contacts/{id}/history    → [LeadHistoryEntry] (backend HistoryItem)
/// It also holds the two request bodies the screen sends: [FollowupDraft]
/// (schedule a follow-up) and the outcome choices used when a follow-up is done.
///
/// WHY SEPARATE CLASSES
/// The screen never touches raw JSON maps. The `fromJson` factories convert
/// snake_case keys once, so widgets read `entry.dueAt` instead of `json['due_at']`.
library;

import 'package:intl/intl.dart';

import '../core/utils/formatters.dart';

/// One row of the Activity log tab: a call, visit, WhatsApp, note or the
/// outcome of a completed follow-up (the server writes that row too).
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.activityType,
    required this.loggedAt,
    this.title,
    this.outcome,
    this.notes,
    this.followupId,
    this.doneByName,
  });

  final int id;

  /// Stored type name, e.g. `phone_call`, `field_visit`, `whatsapp`.
  final String activityType;
  final DateTime loggedAt;
  final String? title;

  /// `done`, `not_now` or `no_answer` when the attempt had an outcome.
  final String? outcome;
  final String? notes;

  /// Set when this row records a completed follow-up.
  final int? followupId;
  final String? doneByName;

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    return ActivityEntry(
      id: asInt(json['id']) ?? 0,
      activityType: asText(json['activity_type']) ?? 'other',
      loggedAt: parseDate(json['logged_at']) ?? DateTime.now(),
      title: asText(json['title']),
      outcome: asText(json['outcome']),
      notes: asText(json['notes']),
      followupId: asInt(json['followup_id']),
      doneByName: asText(json['done_by_name']),
    );
  }
}

/// One row of the Follow-ups tab: a scheduled task for a contact.
class FollowupEntry {
  const FollowupEntry({
    required this.id,
    required this.dueAt,
    required this.status,
    required this.taskState,
    required this.assignedTo,
    this.title,
    this.channel,
    this.notes,
    this.assignedToName,
    this.overdueDays = 0,
  });

  final int id;
  final DateTime dueAt;

  /// Backend status: `todo`, `inprogress` or `completed`.
  final String status;

  /// Backend display state: `overdue`, `due_today`, `todo`, `inprogress` or `completed`.
  final String taskState;
  final int assignedTo;
  final String? title;
  final String? channel;
  final String? notes;
  final String? assignedToName;
  final int overdueDays;

  bool get isOpen => status != 'completed';

  factory FollowupEntry.fromJson(Map<String, dynamic> json) {
    return FollowupEntry(
      id: asInt(json['id']) ?? 0,
      dueAt: parseDate(json['due_at']) ?? DateTime.now(),
      status: asText(json['status']) ?? 'todo',
      taskState: asText(json['task_state']) ?? 'todo',
      assignedTo: asInt(json['assigned_to']) ?? 0,
      title: asText(json['title']),
      channel: asText(json['channel']),
      notes: asText(json['notes']),
      assignedToName: asText(json['assigned_to_name']),
      overdueDays: asInt(json['overdue_days']) ?? 0,
    );
  }
}

/// One row of the History tab: a stage move, a logged activity, a scheduled
/// or rescheduled follow-up, an owner change, or a follow-up field edit.
class LeadHistoryEntry {
  const LeadHistoryEntry({
    required this.eventType,
    required this.timestamp,
    this.actorId,
    this.actorName,
    this.stageName,
    this.previousStageName,
    this.activityType,
    this.title,
    this.outcome,
    this.notes,
    this.dueAt,
    this.previousDueAt,
    this.assignedToName,
    this.assignedFromName,
    this.fieldName,
    this.oldValue,
    this.newValue,
  });

  /// `stage`, `activity`, `followup`, `followup_rescheduled`, `assignment` or `followup_edit`.
  final String eventType;
  final DateTime timestamp;
  final int? actorId;
  final String? actorName;
  final String? stageName;
  final String? previousStageName;
  final String? activityType;
  final String? title;
  final String? outcome;
  final String? notes;
  final DateTime? dueAt;
  final DateTime? previousDueAt;
  final String? assignedToName;
  final String? assignedFromName;
  final String? fieldName;
  final String? oldValue;
  final String? newValue;

  factory LeadHistoryEntry.fromJson(Map<String, dynamic> json) {
    return LeadHistoryEntry(
      eventType: asText(json['event_type']) ?? '',
      timestamp: parseDate(json['timestamp']) ?? DateTime.now(),
      actorId: asInt(json['actor_id']),
      actorName: asText(json['actor_name']),
      stageName: asText(json['stage_name']),
      previousStageName: asText(json['previous_stage_name']),
      activityType: asText(json['activity_type']),
      title: asText(json['title']),
      outcome: asText(json['outcome']),
      notes: asText(json['notes']) ?? asText(json['stage_note']),
      dueAt: parseDate(json['due_at']),
      previousDueAt: parseDate(json['previous_due_at']),
      assignedToName: asText(json['assigned_to_name']),
      assignedFromName: asText(json['assigned_from_name']),
      fieldName: asText(json['field_name']),
      oldValue: asText(json['old_value']),
      newValue: asText(json['new_value']),
    );
  }

  /// One readable line for the timeline, e.g. "Stage moved to Interested from New Lead".
  String get summary {
    final name = title == null ? '' : ': $title';
    return switch (eventType) {
      'stage' =>
        previousStageName == null
            ? 'Stage set to ${stageName ?? 'unknown'}'
            : 'Stage moved to ${stageName ?? 'unknown'} from $previousStageName',
      'activity' =>
        '${humanizeSlug(activityType ?? 'activity')} logged'
            '${outcome == null ? '' : ' · ${humanizeSlug(outcome!)}'}',
      'followup' => 'Follow-up scheduled$name',
      'followup_rescheduled' => 'Follow-up rescheduled$name',
      'assignment' =>
        assignedFromName == null
            ? 'Assigned to ${assignedToName ?? 'someone'}'
            : 'Reassigned from $assignedFromName to ${assignedToName ?? 'someone'}',
      'followup_edit' =>
        '${humanizeSlug(fieldName ?? 'follow-up')} changed'
            '${newValue == null ? '' : ' to ${humanizeSlug(newValue!)}'}',
      _ => 'Update',
    };
  }
}

/// A local date-time as the backend expects it: "2026-10-25T23:59:00", no timezone.
String naiveLocalIso(DateTime value) =>
    DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(value);

/// The body sent to `POST /contacts/{id}/followups`.
///
/// [dueAt] is sent as a naive local time (no timezone), the same format the
/// web app and the Tasks flow use. The backend rejects times in the past.
class FollowupDraft {
  const FollowupDraft({
    required this.channel,
    required this.dueAt,
    required this.assignedTo,
    this.title,
    this.notes,
  });

  /// An activity type from Settings, e.g. `phone_call`.
  final String channel;
  final DateTime dueAt;
  final int assignedTo;
  final String? title;
  final String? notes;

  Map<String, dynamic> toJson() {
    final cleanTitle = title?.trim();
    final cleanNotes = notes?.trim();
    return {
      'channel': channel,
      'due_at': naiveLocalIso(dueAt),
      'assigned_to': assignedTo,
      'priority': 'medium',
      if (cleanTitle != null && cleanTitle.isNotEmpty) 'title': cleanTitle,
      if (cleanNotes != null && cleanNotes.isNotEmpty) 'notes': cleanNotes,
    };
  }
}
