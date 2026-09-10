import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/staff_location.dart';

/// Local buffer for positions captured while the device had no usable
/// connection. Points are uploaded in batches and deleted only once the server
/// has accepted them, so a failed flush never loses a visit.
///
/// The table is capped at [maxPoints]; when it overflows the oldest rows drop
/// first, because a stale point matters less than the current one.
class LocationQueue {
  LocationQueue({String? databaseName})
    : _name = databaseName ?? 'ogera_location.db';

  static const table = 'pending_points';
  static const maxPoints = 2000;

  final String _name;
  Database? _database;

  Future<Database> get _db async => _database ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _name);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            recorded_at TEXT NOT NULL,
            accuracy REAL,
            speed REAL,
            heading REAL,
            battery_level INTEGER,
            is_moving INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_recorded_at ON $table (recorded_at)',
        );
      },
    );
  }

  Future<void> add(PendingPoint point) async {
    final db = await _db;
    await db.insert(table, point.toRow());
    await _trim(db);
  }

  Future<List<PendingPoint>> take(int limit) async {
    final db = await _db;
    final rows = await db.query(
      table,
      orderBy: 'recorded_at ASC',
      limit: limit,
    );
    return rows.map(PendingPoint.fromRow).toList(growable: false);
  }

  Future<void> remove(List<PendingPoint> points) async {
    final ids = points.map((point) => point.localId).whereType<int>().toList();
    if (ids.isEmpty) return;
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(table, where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<int> count() async {
    final db = await _db;
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM $table');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> clear() async {
    final db = await _db;
    await db.delete(table);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> _trim(Database db) async {
    final total =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) AS total FROM $table'),
        ) ??
        0;
    if (total <= maxPoints) return;
    await db.rawDelete(
      'DELETE FROM $table WHERE id IN ('
      'SELECT id FROM $table ORDER BY recorded_at ASC LIMIT ?)',
      [total - maxPoints],
    );
  }
}
