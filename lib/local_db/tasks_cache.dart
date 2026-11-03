// tasks_cache.dart
//
// Reads and writes Task objects to the local SQLite cache.
//
// WHY THIS EXISTS:
//   The Tasks tab shows tasks for the selected day. If the user is in the field
//   without internet, they still need to see their scheduled tasks.
//
// HOW THE CACHE KEY WORKS:
//   Tasks are stored one date at a time (YYYY-MM-DD). Each date gets its own row
//   so we can cache several days without re-fetching them all at once.
//
// HOW TO USE (in TasksViewModel):
//   final cache = TasksCache();
//
//   // After a successful API call:
//   await cache.save(date: '2025-01-15', tasks: tasks);
//
//   // When offline:
//   final cached = await cache.load(date: '2025-01-15');

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../local_db/local_database.dart';
import '../services/tasks_service.dart';

class TasksCache {
  static const _table = 'tasks_cache';

  // Task cache is valid for 30 minutes. Tasks change during the day (marked done,
  // rescheduled) so we use a shorter window than contacts.
  static const _maxAge = Duration(minutes: 30);

  /// Saves [tasks] for the given [date] string (YYYY-MM-DD).
  Future<void> save({required String date, required List<Task> tasks}) async {
    final db = await LocalDatabase.get();
    final rows = tasks.map(_taskToJson).toList();
    await db.insert(
      _table,
      {
        'date': date,
        'data': jsonEncode(rows),
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns cached tasks for [date], or an empty list if missing or stale.
  Future<List<Task>> load({required String date}) async {
    final db = await LocalDatabase.get();
    final rows = await db.query(
      _table,
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (rows.isEmpty) return [];

    final row = rows.first;
    final savedAt = DateTime.tryParse(row['saved_at'] as String? ?? '');
    if (savedAt == null) return [];

    if (DateTime.now().toUtc().difference(savedAt) > _maxAge) return [];

    try {
      final list = jsonDecode(row['data'] as String) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Task.fromJson)
          .toList(growable: false);
    } on FormatException {
      return [];
    }
  }

  /// Removes every row from the tasks cache.
  Future<void> clear() async {
    final db = await LocalDatabase.get();
    await db.delete(_table);
  }

  // Converts a Task to a plain map that Task.fromJson() can reconstruct.
  // We use the same field names the backend sends so fromJson works unchanged.
  static Map<String, dynamic> _taskToJson(Task t) {
    return {
      'id': t.id,
      'title': t.title,
      'type': t.taskType,
      'notes': t.notes,
      // fromResponseStatus maps "done"|"pending" — we reverse our enum here.
      'status': t.taskState == TaskState.done ? 'done' : 'pending',
      'priority': t.priority.value,
      'scheduled_date': t.scheduledDate,
      'scheduled_time': t.scheduledTime,
      'task_state': _taskStateValue(t.taskState),
      'overdue_days': t.overdueDays,
      'contact_id': t.contactId,
      'contact_name': t.contactName,
      'contact_phone': t.contactPhone,
      'contact_type': t.contactType,
      'assigned_to': t.assignedTo,
      'created_at': t.createdAt.toIso8601String(),
    };
  }

  static String _taskStateValue(TaskState state) {
    switch (state) {
      case TaskState.dueToday:
        return 'due_today';
      case TaskState.overdue:
        return 'overdue';
      case TaskState.done:
        return 'done';
      case TaskState.pending:
        return 'pending';
    }
  }
}
