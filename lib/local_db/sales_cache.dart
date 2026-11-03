// sales_cache.dart
//
// Reads and writes Sale objects to the local SQLite cache, and holds a queue
// of create/edit/delete actions that were made while the device was offline.
//
// WHY TWO TABLES:
//   sales_cache      — the most-recently-fetched sales list (for display)
//   pending_sales    — offline write actions that have not yet reached the server
//
// WHY A PENDING QUEUE:
//   Sales are money — users should not lose a sale they entered in the field.
//   When the device is offline, any create/edit/delete is stored here.
//   The next time SalesViewModel successfully calls the API, it first replays
//   the pending actions before fetching the fresh list.
//
// HOW TO USE (in SalesViewModel):
//   final cache = SalesCache();
//
//   // Read (offline):
//   final cached = await cache.load();
//
//   // Write (online success):
//   await cache.save(sales);
//
//   // Queue (offline write):
//   await cache.queueAction(SalesPendingAction.create(draft: {...}));
//
//   // On reconnect — replay and then clear:
//   final pending = await cache.pendingActions();
//   for (final action in pending) { /* replay */ }
//   await cache.clearPending();

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../local_db/local_database.dart';

// ── Pending action model ───────────────────────────────────────────────────

/// The type of write that happened while offline.
enum SalesPendingActionType {
  create,
  update,
  delete,
}

/// One queued offline write for the sales module.
class SalesPendingAction {
  const SalesPendingAction({
    this.id,
    required this.type,
    this.saleId,
    required this.payload,
    required this.queuedAt,
  });

  /// Row id in `pending_sales` (set by the database on insert).
  final int? id;

  /// What kind of write this is: create, update, or delete.
  final SalesPendingActionType type;

  /// The server-side sale id. Null for creates (the server assigns it).
  final int? saleId;

  /// The request body as a plain map (the same map you would send to the API).
  final Map<String, dynamic> payload;

  /// When the action was queued.
  final DateTime queuedAt;

  factory SalesPendingAction.fromRow(Map<String, dynamic> row) {
    return SalesPendingAction(
      id: row['id'] as int?,
      type: SalesPendingActionType.values.firstWhere(
        (t) => t.name == row['action_type'],
        orElse: () => SalesPendingActionType.create,
      ),
      saleId: row['sale_id'] as int?,
      payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      queuedAt:
          DateTime.tryParse(row['queued_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// ── SalesCache ─────────────────────────────────────────────────────────────

class SalesCache {
  static const _salesTable = 'sales_cache';
  static const _pendingTable = 'pending_sales';

  // Sales cache is valid for 1 hour. This matches the contacts cache.
  static const _maxAge = Duration(hours: 1);

  // ── sales list cache ────────────────────────────────────────────────────

  /// Saves [sales] (a list of raw JSON maps from the API). Using raw maps means
  /// we do not need a Sale model to exist before the cache works — the view
  /// model decodes the maps itself.
  Future<void> save(List<Map<String, dynamic>> sales) async {
    final db = await LocalDatabase.get();
    await db.insert(
      _salesTable,
      {
        'cache_key': 'list',
        'data': jsonEncode(sales),
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the cached sales list, or an empty list if missing or stale.
  Future<List<Map<String, dynamic>>> load() async {
    final db = await LocalDatabase.get();
    final rows = await db.query(
      _salesTable,
      where: 'cache_key = ?',
      whereArgs: ['list'],
      limit: 1,
    );
    if (rows.isEmpty) return [];

    final row = rows.first;
    final savedAt = DateTime.tryParse(row['saved_at'] as String? ?? '');
    if (savedAt == null) return [];

    if (DateTime.now().toUtc().difference(savedAt) > _maxAge) return [];

    try {
      final list = jsonDecode(row['data'] as String) as List;
      return list.whereType<Map<String, dynamic>>().toList(growable: false);
    } on FormatException {
      return [];
    }
  }

  // ── pending action queue ────────────────────────────────────────────────

  /// Adds one offline write to the queue.
  Future<void> queueAction({
    required SalesPendingActionType type,
    int? saleId,
    required Map<String, dynamic> payload,
  }) async {
    final db = await LocalDatabase.get();
    await db.insert(
      _pendingTable,
      {
        'action_type': type.name, // 'create', 'update', or 'delete'
        'sale_id': saleId,
        'payload': jsonEncode(payload),
        'queued_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  /// Returns all queued actions, oldest first (so they replay in order).
  Future<List<SalesPendingAction>> pendingActions() async {
    final db = await LocalDatabase.get();
    final rows = await db.query(
      _pendingTable,
      orderBy: 'queued_at ASC',
    );
    return rows.map(SalesPendingAction.fromRow).toList(growable: false);
  }

  /// Removes one pending action by its row id after it has been replayed.
  Future<void> removePending(int rowId) async {
    final db = await LocalDatabase.get();
    await db.delete(
      _pendingTable,
      where: 'id = ?',
      whereArgs: [rowId],
    );
  }

  /// Removes all pending actions (call after a successful full sync).
  Future<void> clearPending() async {
    final db = await LocalDatabase.get();
    await db.delete(_pendingTable);
  }

  /// Removes both the sales list cache and all pending actions.
  /// Call this on sign-out.
  Future<void> clear() async {
    final db = await LocalDatabase.get();
    await db.delete(_salesTable);
    await db.delete(_pendingTable);
  }
}
