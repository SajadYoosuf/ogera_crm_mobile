/// TasksViewModel manages the Tasks tab's state.
///
/// WHAT IT DOES:
///   - Holds the signed-in user's tasks loaded from GET /tasks.
///   - Filters: a calendar day, a status dropdown and a priority dropdown.
///   - Exposes actions (complete, change status, reschedule, book the next
///     follow-up). Each action returns null on success or an error message.
///
/// WHY THIS PATTERN:
///   The view model is the single source of truth for the Tasks tab.
///   Screens read state and call methods; they never call the API directly.
///
/// GLITCH GUARDS:
///   - A load error replaces the list, so only load errors use [error].
///     A failed action is returned to the caller and never hides the list.
///   - Each load gets a number. If an older response arrives after a newer
///     one (for example after quick filter taps), it is ignored.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';
import '../services/tasks_service.dart';

/// Status dropdown values. [apiValue] is what GET /tasks expects.
enum TaskStatusFilter {
  all('All active', 'open'),
  todo('To Do', 'todo'),
  inProgress('In Progress', 'inprogress'),
  completed('Completed', 'completed');

  const TaskStatusFilter(this.label, this.apiValue);

  final String label;
  final String apiValue;

  /// True for the filters that show open (not completed) tasks.
  bool get isOpen => this != TaskStatusFilter.completed;
}

class TasksViewModel extends ChangeNotifier {
  TasksViewModel(this._service);

  final TasksService _service;

  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  /// Counts load requests so a slow, older response cannot overwrite a newer one.
  int _latestLoad = 0;

  final List<Task> _tasks = [];
  TaskSummary? _summary;

  DateTime _selectedDate = DateTime.now();
  TaskStatusFilter _statusFilter = TaskStatusFilter.all;
  TaskPriority? _priorityFilter;

  List<Task> get tasks => List.unmodifiable(_tasks);
  TaskSummary? get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedDate => _selectedDate;
  TaskStatusFilter get statusFilter => _statusFilter;

  /// null = all priorities.
  TaskPriority? get priorityFilter => _priorityFilter;

  // ── Loading ──────────────────────────────────────────────────────────────

  /// Loads the tasks that match the current filters.
  ///
  /// [silent] reloads in the background without the loading state, so the
  /// list does not flash after an action.
  Future<void> load({bool silent = false}) async {
    final request = ++_latestLoad;
    if (!silent) {
      _isLoading = true;
      _error = null;
      _notify();
    }

    String? failure;
    ({List<Task> items, int total, TaskSummary summary})? result;
    try {
      final dateStr = isoDate(_selectedDate);
      result = await _service.list(
        statusFilter: _statusFilter.apiValue,
        priority: _priorityFilter,
        dateFrom: dateStr,
        dateTo: dateStr,
        includeOverdue: _statusFilter.isOpen,
      );
    } on ApiException catch (e) {
      failure = e.message;
    } catch (_) {
      failure = 'Could not load tasks. Check your connection and try again.';
    }

    // A newer load started while this one was waiting: drop this result.
    if (request != _latestLoad) return;

    if (result != null) {
      _tasks
        ..clear()
        ..addAll(result.items);
      _summary = result.summary;
      _error = null;
    } else {
      _error = failure;
    }
    _isLoading = false;
    _notify();
  }

  // ── Filters ───────────────────────────────────────────────────────────────

  /// Moves the calendar selection to [date] and reloads.
  Future<void> selectDate(DateTime date) {
    _selectedDate = date;
    return load();
  }

  /// Sets the status dropdown and reloads.
  Future<void> setStatusFilter(TaskStatusFilter filter) {
    if (filter == _statusFilter) return Future.value();
    _statusFilter = filter;
    return load();
  }

  /// Sets the priority dropdown (null = all) and reloads.
  Future<void> setPriorityFilter(TaskPriority? priority) {
    if (priority == _priorityFilter) return Future.value();
    _priorityFilter = priority;
    return load();
  }

  // ── Task types ────────────────────────────────────────────────────────────

  /// Task types from Settings, as {value: label}, for the pickers.
  Future<Map<String, String>> taskTypes() => _service.taskTypes();

  // ── Actions ───────────────────────────────────────────────────────────────
  //
  // Each action returns null on success, or a message to show the user.

  /// Marks [task] completed with an outcome, a note and the task type used.
  Future<String?> complete(
    Task task, {
    required TaskOutcome outcome,
    required String notes,
    required String activityType,
  }) {
    return _runAction(
      () => _service.complete(
        task,
        outcome: outcome,
        notes: notes,
        activityType: activityType,
      ),
      onSuccess: () {
        // Completed tasks leave the active list straight away.
        _tasks.removeWhere((t) => t.id == task.id);
        _notify();
      },
    );
  }

  /// Changes [task] to [status] (To Do or In Progress).
  Future<String?> updateStatus(Task task, TaskStatus status) {
    return _runAction(() => _service.updateStatus(task, status));
  }

  /// Moves [task] to [dueAt].
  Future<String?> reschedule(Task task, DateTime dueAt) {
    return _runAction(() => _service.reschedule(task, dueAt));
  }

  /// Books the next follow-up with the same contact. It is assigned to the signed-in user.
  Future<String?> scheduleNextFollowup({
    required int contactId,
    required String activityType,
    required DateTime dueAt,
  }) async {
    try {
      await _service.scheduleNextFollowup(
        contactId: contactId,
        activityType: activityType,
        dueAt: dueAt,
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not schedule the follow-up. Please try again.';
    }
  }

  /// Runs [action]. On success it reloads the summary quietly. On failure it
  /// returns a message and leaves the list alone.
  Future<String?> _runAction(
    Future<void> Function() action, {
    VoidCallback? onSuccess,
  }) async {
    try {
      await action();
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not update the task. Check your connection and try again.';
    }
    onSuccess?.call();
    unawaited(load(silent: true));
    return null;
  }

  // ── Plumbing ──────────────────────────────────────────────────────────────

  /// Notifies listeners unless the view model was already disposed.
  /// A late response can arrive after the screen closes; notifying then throws.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
