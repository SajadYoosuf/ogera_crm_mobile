import 'package:sqflite/sqflite.dart';

/// Durable buffer for the newest location that has not reached the server.
///
/// The product deliberately keeps only the latest unsent point. This avoids
/// replaying stale GPS data after a long outage while still ensuring that the
/// server eventually receives the most recent position.
class LocationQueue {
  LocationQueue({Future<Database> Function()? databaseFactory})
    : _databaseFactory = databaseFactory ?? _openDatabase;

  final Future<Database> Function() _databaseFactory;
  Database? _database;

  Future<Database> get _db async => _database ??= await _databaseFactory();

  Future<void> save({
    required int ownerId,
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
  }) async {
    final db = await _db;
    await db.insert('pending_location', {
      'owner_id': ownerId,
      'latitude': latitude,
      'longitude': longitude,
      'captured_at': capturedAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> peek({required int ownerId}) async {
    final rows = await (await _db).query(
      'pending_location',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> count({required int ownerId}) async {
    final rows = await (await _db).rawQuery(
      'SELECT COUNT(*) AS count FROM pending_location WHERE owner_id = ?',
      [ownerId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> remove({required int ownerId}) async {
    await (await _db).delete(
      'pending_location',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
    );
  }

  static Future<Database> _openDatabase() async {
    final path = '${await getDatabasesPath()}/ogera_location_queue.db';
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_location (
            owner_id INTEGER PRIMARY KEY,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            captured_at TEXT NOT NULL
          )
        ''');
      },
    );
  }
}
