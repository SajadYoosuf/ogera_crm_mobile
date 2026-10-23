/// Tasks service.
///
/// Wraps:
///   GET /tasks  — paginated task list with optional filters
///   PATCH /tasks/{id}  — update a task's status or scheduled time
///
/// A Task has a type (call, visit, follow_up, demo, other), a priority
/// (low, medium, high), and a status (todo, in_progress, completed).
library;

import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

enum TaskStatus {
  todo('todo', 'To Do'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Completed');

  const TaskStatus(this.value, this.label);
  final String value;
  final String label;

  static TaskStatus fromValue(String value) => TaskStatus.values.firstWhere(
    (s) => s.value == value,
    orElse: () => TaskStatus.todo,
  );
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

/// A single CRM task.
///
/// [contactId] and [contactName] may be null if the task is not linked to
/// a lead/contact.
class Task {
  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.taskType,
    required this.priority,
    required this.status,
    this.scheduledAt,
    this.contactId,
    this.contactName,
    this.notes,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String? description;
  final String taskType;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? scheduledAt;
  final int? contactId;
  final String? contactName;
  final String? notes;
  final DateTime createdAt;

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as int,
    title: json['title'] as String,
    description: json['description'] as String?,
    taskType: asText(json['task_type']) ?? 'other',
    priority: TaskPriority.fromValue(json['priority'] as String? ?? 'medium'),
    status: TaskStatus.fromValue(json['status'] as String? ?? 'todo'),
    scheduledAt: json['scheduled_at'] != null
        ? DateTime.tryParse(json['scheduled_at'] as String)
        : null,
    contactId: json['contact_id'] as int?,
    contactName: json['contact_name'] as String?,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class TasksService {
  TasksService(this._api);

  final ApiClient _api;

  /// Returns a paged list of tasks.
  ///
  /// All filters are optional. [date] is an ISO date (YYYY-MM-DD) to filter
  /// tasks scheduled on that day. Pass null to get all tasks.
  Future<({List<Task> items, int total})> list({
    TaskStatus? status,
    TaskPriority? priority,
    String? date,
    int skip = 0,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{
      'skip': skip,
      'limit': limit,
      if (status != null) 'status': status.value,
      if (priority != null) 'priority': priority.value,
      if (date != null) 'date': date,
    };
    final data = asMap(await _api.get('/tasks', query: query));
    final items = asList(data['items']).map(Task.fromJson).toList();
    final total = asInt(data['total']) ?? items.length;
    return (items: items, total: total);
  }

  /// Updates a task's status and/or scheduled time.
  ///
  /// [id] is the task's database id.
  /// Only the fields you pass are sent; null values are omitted.
  Future<Task> update(
    int id, {
    TaskStatus? status,
    String? scheduledAt,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      if (status != null) 'status': status.value,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
      if (notes != null) 'notes': notes,
    };
    final data = asMap(await _api.patch('/tasks/$id', body: body));
    return Task.fromJson(data);
  }
}
