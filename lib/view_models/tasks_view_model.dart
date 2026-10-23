/// TasksViewModel manages the Tasks tab's state.
///
/// WHAT IT DOES:
///   - Holds the list of tasks loaded from GET /tasks.
///   - Lets the user select a day on the calendar row → filters to that date.
///   - Lets the user pick status/priority chips → stacks filters.
///   - Exposes methods to complete, change status, or reschedule a task.
///
/// WHY THIS PATTERN:
///   The view model is the single source of truth for the Tasks tab.
///   The screen reads state and calls methods; it never calls the API directly.
library;

import 'package:flutter/foundation.dart';

import '../core/utils/formatters.dart';
import '../services/tasks_service.dart';

class TasksViewModel extends ChangeNotifier {
  TasksViewModel(this._service);

  final TasksService _service;

  bool _isLoading = false;
  String? _error;

  final List<Task> _tasks = [];
  TaskSummary? _summary;

  DateTime _selectedDate = DateTime.now();

  /// null = "open" (both todo + in_progress) — shows the whole active list.
  String? _statusFilter;

  TaskPriority? _priorityFilter;

  List<Task> get tasks => List.unmodifiable(_tasks);
  TaskSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;
  String? get statusFilter => _statusFilter;
  TaskPriority? get priorityFilter => _priorityFilter;

  // ── Loading ──────────────────────────────────────────────────────────────

  /// Load tasks from the server using the current filters.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final dateStr = isoDate(_selectedDate);
      final result = await _service.list(
        statusFilter: _statusFilter ?? 'open',
        priority: _priorityFilter,
        dateFrom: dateStr,
        dateTo: dateStr,
        includeOverdue: _statusFilter == null || _statusFilter == 'open',
      );
      _tasks
        ..clear()
        ..addAll(result.items);
      _summary = result.summary;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  /// Move the calendar selection to [date] and reload.
  Future<void> selectDate(DateTime date) async {
    _selectedDate = date;
    await load();
  }

  /// Toggle or clear the status chip filter, then reload.
  ///
  /// Passing the same value as the current filter clears it (back to "open").
  Future<void> setStatusFilter(String? status) async {
    _statusFilter = (_statusFilter == status) ? null : status;
    await load();
  }

  /// Toggle or clear the priority chip filter, then reload.
  Future<void> setPriorityFilter(TaskPriority? priority) async {
    _priorityFilter = (_priorityFilter == priority) ? null : priority;
    await load();
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Marks a task as complete with an outcome (required by the backend).
  ///
  /// Removes the task from the list on success (completed tasks go to
  /// the "Completed" view, which loads separately).
  Future<bool> complete(int id, {required String outcome, String? notes}) async {
    try {
      await _service.complete(id, outcome: outcome, notes: notes);
      _tasks.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggles a task between todo ↔ in_progress.
  Future<bool> toggleStatus(int id, TaskStatus status) async {
    try {
      await _service.updateStatus(id, status);
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Reschedules a task.
  ///
  /// [dueAt] is an ISO-8601 datetime string.
  Future<bool> reschedule(int id, String dueAt) async {
    try {
      await _service.reschedule(id, dueAt);
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
