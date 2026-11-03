// location_queue.dart
//
// PURPOSE:
//   Staff members share their GPS location with the server so managers can see
//   where everyone is on a live map. The app captures a GPS ping periodically
//   and sends it via POST /staff/location. When there is no internet, the ping
//   would normally be lost.
//
// HOW THE OFFLINE QUEUE WORKS:
//   Instead of sending the ping directly, the app always saves it to a tiny
//   SQLite database on the device first (the "queue"). A background process
//   then reads from the queue and tries to send it to the server.
//
//   Step-by-step:
//     1. GPS ping captured → saved to `pending_location` table (overwriting any
//        older unsent ping for this user — we only care about the latest).
//     2. Background sender runs → calls peek() to read the queued ping.
//     3. If the POST succeeds → remove() deletes the row so it is not sent twice.
//     4. If the POST fails (no internet) → the row stays; the next background
//        run will try again automatically.
//
// WHY ONLY ONE ROW PER USER (ConflictAlgorithm.replace):
//   The table has `owner_id` as its PRIMARY KEY. Inserting a new row for the
//   same user overwrites the old one instead of adding a second row.
//   This is intentional: if the device was offline for 30 minutes, sending
//   thirty stale pings would flood the server with old data. Managers only need
//   the *current* position, so keeping just the newest point is correct.
//
// WHY A SEPARATE DATABASE FILE (ogera_location_queue.db):
//   The main cache lives in ogera_cache.db and is erased on sign-out so that
//   user A's data is not visible to user B. Location pings are tied to the
//   logged-in user via owner_id and must survive a brief sign-out/sign-in
//   cycle (e.g. token refresh), so they live in their own file that is NOT
//   cleared on sign-out.

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
