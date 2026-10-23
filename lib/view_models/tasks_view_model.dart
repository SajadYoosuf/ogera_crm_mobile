/// TasksViewModel manages the Tasks tab's state.
///
/// The user can:
///   • tap a day in the calendar row  → filters tasks to that date
///   • pick a status chip (Todo / In Progress / Completed) → filter
///   • pick a priority chip (Low / Medium / High) → filter
///   • change a task's status via the bottom sheet → calls update()
///   • reschedule a task → calls reschedule()
///
/// All three filters stack: only tasks matching all active filters show.
/// The list reloads from the server whenever any filter changes.
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
  DateTime _selectedDate = DateTime.now();
  TaskStatus? _statusFilter;
  TaskPriority? _priorityFilter;

  List<Task> get tasks => List.unmodifiable(_tasks);
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;
  TaskStatus? get statusFilter => _statusFilter;
  TaskPriority? get priorityFilter => _priorityFilter;

  /// Load tasks from the server using the current filters.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.list(
        status: _statusFilter,
        priority: _priorityFilter,
        date: isoDate(_selectedDate),
      );
      _tasks
        ..clear()
        ..addAll(result.items);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Move the calendar selection to [date] and reload.
  Future<void> selectDate(DateTime date) async {
    _selectedDate = date;
    await load();
  }

  /// Toggle or clear the status chip filter, then reload.
  Future<void> setStatusFilter(TaskStatus? status) async {
    _statusFilter = (_statusFilter == status) ? null : status;
    await load();
  }

  /// Toggle or clear the priority chip filter, then reload.
  Future<void> setPriorityFilter(TaskPriority? priority) async {
    _priorityFilter = (_priorityFilter == priority) ? null : priority;
    await load();
  }

  /// Changes a task's status (called from the status bottom sheet).
  Future<void> updateStatus(int id, TaskStatus status, {String? notes}) async {
    try {
      final updated = await _service.update(id, status: status, notes: notes);
      final idx = _tasks.indexWhere((t) => t.id == id);
      if (idx != -1) {
        _tasks[idx] = updated;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Reschedules a task (called from the reschedule bottom sheet).
  ///
  /// [scheduledAt] is an ISO-8601 datetime string.
  Future<void> reschedule(int id, String scheduledAt) async {
    try {
      final updated = await _service.update(id, scheduledAt: scheduledAt);
      final idx = _tasks.indexWhere((t) => t.id == id);
      if (idx != -1) {
        _tasks[idx] = updated;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
