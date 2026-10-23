/// Tasks service.
///
/// WHAT IT DOES:
///   Wraps GET /tasks and PATCH /tasks/{id}.
///
/// BACKEND CONTRACT (as of the current FastAPI backend):
///   GET /tasks response item fields:
///     id, title, type, notes, status ("pending"|"done"), priority,
///     scheduled_date (YYYY-MM-DD), scheduled_time (HH:MM:SS),
///     task_state ("pending"|"due_today"|"overdue"|"done"),
///     overdue_days, contact_id, contact_name, contact_phone, contact_type,
///     assigned_to, created_at
///
///   PATCH /tasks/{id} body: { status?, outcome?, notes?, due_at? }
///     - status is one of: todo, inprogress, completed, pending
///     - outcome is REQUIRED when status=completed
///     - due_at is for reschedule (mutually exclusive with status)
library;

import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

/// Display status values understood by the UI.
///
/// The backend returns "pending" or "done" in the response, but accepts
/// "todo", "inprogress", "completed" on PATCH. We keep all values here
/// and translate as needed.
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
    createdAt: DateTime.tryParse(asText(json['created_at']) ?? '') ?? DateTime.now(),
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

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class TasksService {
  TasksService(this._api);

  final ApiClient _api;

  /// Returns a paged list of tasks with a summary.
  ///
  /// [dateFrom]/[dateTo] are ISO date strings (YYYY-MM-DD).
  /// [status] accepts "open", "todo", "inprogress", "completed", "all",
  /// "due_today", "overdue".
  Future<({List<Task> items, int total, TaskSummary summary})> list({
    String statusFilter = 'open',
    TaskPriority? priority,
    String? dateFrom,
    String? dateTo,
    bool includeOverdue = false,
    int skip = 0,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{
      'skip': skip,
      'limit': limit,
      'status': statusFilter,
      if (priority != null) 'priority': priority.value,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
      if (includeOverdue) 'include_overdue': true,
    };
    final data = asMap(await _api.get('/tasks', query: query));
    final items = asList(data['items']).map(Task.fromJson).toList();
    final total = asInt(data['total']) ?? items.length;
    final summary = TaskSummary.fromJson(asMap(data['summary']));
    return (items: items, total: total, summary: summary);
  }

  /// Marks a task complete with an outcome.
  ///
  /// [outcome] is required by the backend when marking completed.
  Future<void> complete(int id, {required String outcome, String? notes}) async {
    await _api.patch('/tasks/$id', body: {
      'status': 'completed',
      'outcome': outcome,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  /// Changes a task's status (todo ↔ inprogress).
  Future<void> updateStatus(int id, TaskStatus status) async {
    await _api.patch('/tasks/$id', body: {'status': status.value});
  }

  /// Reschedules a task to a new date/time.
  ///
  /// [dueAt] is an ISO-8601 datetime string (e.g. "2026-10-25T14:00:00").
  Future<void> reschedule(int id, String dueAt) async {
    await _api.patch('/tasks/$id', body: {'due_at': dueAt});
  }
}
