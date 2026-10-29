/// Tasks service.
///
/// WHAT IT DOES:
///   Talks to the follow-up endpoints for the Tasks tab:
///   - GET /tasks                                   → the signed-in user's tasks
///   - PATCH /contacts/{id}/followups/{task}        → complete / status / reschedule
///     (contact-linked tasks; the backend also writes the contact's activity log
///      and auto-books a retry on "no answer" / "not now")
///   - PATCH /tasks/{task}                          → same body, for standalone tasks
///   - POST  /contacts/{id}/followups               → book the next follow-up
///
/// BACKEND CONTRACT (FastAPI, routes/tasks.py + routes/followups.py):
///   GET /tasks response item fields:
///     id, title, type, notes, status ("pending"|"done"), priority,
///     scheduled_date (YYYY-MM-DD), scheduled_time (HH:MM:SS),
///     task_state ("pending"|"due_today"|"overdue"|"done"),
///     overdue_days, contact_id, contact_name, contact_phone, contact_type,
///     assigned_to, created_at
///
///   PATCH body (exactly one of status / due_at):
///     status:         "todo" | "inprogress" | "completed"
///     outcome:        "done" | "not_now" | "no_answer"   (required with completed)
///     notes:          free text, what was done
///     actual_channel: the activity type actually used (optional)
///     due_at:         naive local datetime, for reschedule
library;

import 'package:intl/intl.dart';

import '../core/network/api_client.dart';
import '../core/reference/crm_options.dart';
import '../core/utils/formatters.dart';
import 'crm_services.dart';

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// Status values the UI and the PATCH endpoint understand.
///
/// The list response only says "pending" or "done", so [fromResponseStatus]
/// maps it to a UI status.
enum TaskStatus {
  todo('todo', 'To Do'),
  inProgress('inprogress', 'In Progress'),
  completed('completed', 'Completed');

  const TaskStatus(this.value, this.label);

  /// The value sent to the backend on PATCH.
  final String value;
  final String label;

  /// Map the backend response status ("pending" or "done") to a UI status.
  static TaskStatus fromResponseStatus(String status) {
    switch (status) {
      case 'done':
        return TaskStatus.completed;
      case 'pending':
      default:
        return TaskStatus.todo;
    }
  }
}

/// What happened on a task. The backend accepts only these three values.
enum TaskOutcome {
  done('done', 'Done'),
  notNow('not_now', 'Not now'),
  noAnswer('no_answer', 'No answer');

  const TaskOutcome(this.value, this.label);
  final String value;
  final String label;
}

enum TaskPriority {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High');

  const TaskPriority(this.value, this.label);
  final String value;
  final String label;

  static TaskPriority fromValue(String value) => TaskPriority.values.firstWhere(
    (p) => p.value == value,
    orElse: () => TaskPriority.medium,
  );
}

/// Task state from the backend — used for visual cues (overdue badge etc.).
enum TaskState {
  pending,
  dueToday,
  overdue,
  done;

  static TaskState fromValue(String value) {
    switch (value) {
      case 'due_today':
        return TaskState.dueToday;
      case 'overdue':
        return TaskState.overdue;
      case 'done':
        return TaskState.done;
      case 'pending':
      default:
        return TaskState.pending;
    }
  }
}

/// A single CRM task.
///
/// Maps directly to one item in GET /tasks → items[].
class Task {
  const Task({
    required this.id,
    this.title,
    required this.taskType,
    this.notes,
    required this.status,
    required this.priority,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.taskState,
    required this.overdueDays,
    this.contactId,
    this.contactName,
    this.contactPhone,
    this.contactType,
    required this.assignedTo,
    required this.createdAt,
  });

  final int id;
  final String? title;
  final String taskType;
  final String? notes;
  final TaskStatus status;
  final TaskPriority priority;

  /// Date string YYYY-MM-DD from the backend.
  final String scheduledDate;

  /// Time string HH:MM:SS from the backend.
  final String scheduledTime;
  final TaskState taskState;
  final int overdueDays;
  final int? contactId;
  final String? contactName;
  final String? contactPhone;
  final String? contactType;
  final int assignedTo;
  final DateTime createdAt;

  /// True once the task is completed (the backend reports it as "done").
  bool get isDone => taskState == TaskState.done;

  /// The combined scheduled date+time as a [DateTime].
  DateTime get scheduledAt {
    try {
      return DateTime.parse('${scheduledDate}T$scheduledTime');
    } catch (_) {
      return DateTime.now();
    }
  }

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: asInt(json['id']) ?? 0,
    title: asText(json['title']),
    taskType: asText(json['type']) ?? 'other',
    notes: asText(json['notes']),
    status: TaskStatus.fromResponseStatus(asText(json['status']) ?? 'pending'),
    priority: TaskPriority.fromValue(asText(json['priority']) ?? 'medium'),
    scheduledDate: asText(json['scheduled_date']) ?? '',
    scheduledTime: asText(json['scheduled_time']) ?? '00:00:00',
    taskState: TaskState.fromValue(asText(json['task_state']) ?? 'pending'),
    overdueDays: asInt(json['overdue_days']) ?? 0,
    contactId: asInt(json['contact_id']),
    contactName: asText(json['contact_name']),
    contactPhone: asText(json['contact_phone']),
    contactType: asText(json['contact_type']),
    assignedTo: asInt(json['assigned_to']) ?? 0,
    createdAt:
        DateTime.tryParse(asText(json['created_at']) ?? '') ?? DateTime.now(),
  );
}

/// Summary counts returned by GET /tasks.
class TaskSummary {
  const TaskSummary({
    required this.overdue,
    required this.today,
    required this.upcoming,
    required this.done,
  });

  final int overdue;
  final int today;
  final int upcoming;
  final int done;

  factory TaskSummary.fromJson(Map<String, dynamic> json) => TaskSummary(
    overdue: asInt(json['overdue']) ?? 0,
    today: asInt(json['today']) ?? 0,
    upcoming: asInt(json['upcoming']) ?? 0,
    done: asInt(json['done']) ?? 0,
  );
}

/// Activity-type values that cannot be a task type. Internal notes are logs, not tasks.
const _notTaskTypes = {'internal_note'};

/// The app stores some activity types under short names (see the backend's
/// STORED_CHANNELS). A PATCH with the stored name avoids a false "channel changed" edit log.
const _storedChannelNames = {'phone_call': 'call', 'field_visit': 'visit'};

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class TasksService {
  TasksService(this._api);

  final ApiClient _api;

  /// Returns a page of the signed-in user's tasks with a summary.
  ///
  /// The `assigned_to` filter is always sent, so the screen shows only tasks
  /// assigned to the person logged in on this phone.
  ///
  /// [dateFrom]/[dateTo] are ISO date strings (YYYY-MM-DD).
  /// [statusFilter] accepts "open", "todo", "inprogress", "completed", "all".
  Future<({List<Task> items, int total, TaskSummary summary})> list({
    String statusFilter = 'open',
    TaskPriority? priority,
    String? dateFrom,
    String? dateTo,
    bool includeOverdue = false,
    int skip = 0,
    int limit = 50,
  }) async {
    final owner = _api.currentUserId;
    if (owner == null) {
      throw const ApiException('Sign in again to see your tasks.');
    }
    final query = <String, dynamic>{
      'skip': skip,
      'limit': limit,
      'status': statusFilter,
      'assigned_to': owner,
      'priority': ?priority?.value,
      'date_from': ?dateFrom,
      'date_to': ?dateTo,
      if (includeOverdue) 'include_overdue': true,
    };
    final data = asMap(await _api.get('/tasks', query: query));
    final items = asList(data['items']).map(Task.fromJson).toList();
    final total = asInt(data['total']) ?? items.length;
    final summary = TaskSummary.fromJson(asMap(data['summary']));
    return (items: items, total: total, summary: summary);
  }

  /// Activity types the employee can pick for a task, as {value: label}.
  ///
  /// Uses the Settings list, with the built-in list as a fallback so the
  /// picker is never empty.
  Future<Map<String, String>> taskTypes() async {
    final all = await SettingsOptionsCatalog.of(
      _api,
    ).options('activity_type', fallback: CrmOptions.defaultActivityTypes);
    return {
      for (final entry in all.entries)
        if (!_notTaskTypes.contains(entry.key)) entry.key: entry.value,
    };
  }

  /// Marks a task completed.
  ///
  /// [outcome] is one of [TaskOutcome]; [notes] says what was done;
  /// [activityType] is the task type actually used.
  Future<void> complete(
    Task task, {
    required TaskOutcome outcome,
    required String notes,
    required String activityType,
  }) async {
    await _api.patch(
      _taskPath(task),
      body: {
        'status': 'completed',
        'outcome': outcome.value,
        'notes': notes.trim(),
        'actual_channel': _storedChannelNames[activityType] ?? activityType,
      },
    );
  }

  /// Changes a task's status (todo ↔ inprogress).
  Future<void> updateStatus(Task task, TaskStatus status) async {
    await _api.patch(_taskPath(task), body: {'status': status.value});
  }

  /// Reschedules a task to [dueAt] (local time, sent without a timezone like the web app).
  Future<void> reschedule(Task task, DateTime dueAt) async {
    await _api.patch(_taskPath(task), body: {'due_at': _localIso(dueAt)});
  }

  /// Books the next follow-up with a contact, assigned to [assignedTo].
  ///
  /// The backend needs a due time, so the caller passes one (the sheet uses
  /// tomorrow 23:59, the same default the web app uses for "no time").
  Future<void> scheduleNextFollowup({
    required int contactId,
    required String activityType,
    required DateTime dueAt,
    int? assignedTo,
  }) async {
    // Defaults to the person on this phone: the employee who completes a task books its follow-up.
    final owner = assignedTo ?? _api.currentUserId;
    if (owner == null) {
      throw const ApiException('Sign in again to schedule a follow-up.');
    }
    await _api.post(
      '/contacts/$contactId/followups',
      body: {
        'channel': activityType,
        'due_at': _localIso(dueAt),
        'assigned_to': owner,
      },
    );
  }

  /// Contact-linked tasks use the contact route, which also writes the
  /// activity log and books retries. Standalone tasks use the /tasks route.
  String _taskPath(Task task) => task.contactId == null
      ? '/tasks/${task.id}'
      : '/contacts/${task.contactId}/followups/${task.id}';

  /// "2026-10-25T23:59:00" — the naive local format the backend expects.
  String _localIso(DateTime value) =>
      DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(value);
}
