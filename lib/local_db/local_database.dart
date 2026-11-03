// local_database.dart
//
// Opens (or creates) the single SQLite database the app uses for offline caching.
//
// WHY ONE DATABASE FILE:
//   SQLite works best with one file per app. All cache tables live here,
//   separated from `ogera_location_queue.db` which is the GPS queue.
//
// HOW TO USE:
//   Call `LocalDatabase.get()` anywhere to get the open database.
//   The first call creates the file and tables; later calls reuse the same object.
//
//   Example:
//     final db = await LocalDatabase.get();
//     final rows = await db.query('contacts_cache');
//
// TABLES:
//   contacts_cache     — most-recently-fetched contacts page
//   tasks_cache        — most-recently-fetched tasks for the current day
//   pipeline_cache     — all pipeline contacts (bucketed by stage on read)
//   sales_cache        — most-recently-fetched sales list
//   pending_sales      — offline write actions queued while offline (create/update/delete)

import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  // Singleton: only one Database instance is ever open at a time.
  static Database? _db;

  /// Returns the open database, creating the file on first call.
  static Future<Database> get() async {
    return _db ??= await _open();
  }

  /// Closes and forgets the database. Call this on sign-out so a new user
  /// gets a clean cache (the next call to `get()` reopens the file).
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Future<Database> _open() async {
    final path = '${await getDatabasesPath()}/ogera_cache.db';
    return openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  // Called once when the database file is first created.
  // Each cache table stores rows as JSON text so adding new model fields
  // never requires a schema migration.
  static Future<void> _createTables(Database db, int version) async {
    // contacts_cache: one row per cached page.
    //   key   — identifies which page/filter combo this row belongs to
    //           (e.g. "consumer|page1" or "all|page1")
    //   data  — JSON array of Contact objects from the last successful fetch
    //   saved_at — ISO-8601 timestamp, used to expire stale cache entries
    await db.execute('''
      CREATE TABLE contacts_cache (
        cache_key   TEXT PRIMARY KEY,
        data        TEXT NOT NULL,
        saved_at    TEXT NOT NULL
      )
    ''');

    // tasks_cache: one row per calendar date.
    //   date  — the task's scheduled_date (YYYY-MM-DD)
    //   data  — JSON array of Task objects for that date
    //   saved_at — ISO-8601 timestamp
    await db.execute('''
      CREATE TABLE tasks_cache (
        date        TEXT PRIMARY KEY,
        data        TEXT NOT NULL,
        saved_at    TEXT NOT NULL
      )
    ''');

    // pipeline_cache: one row per contact-type board (consumer/partner/dealer).
    //   contact_type — "consumer", "partner", or "dealer"
    //   data         — JSON array of all Lead objects for that board
    //   saved_at     — ISO-8601 timestamp
    await db.execute('''
      CREATE TABLE pipeline_cache (
        contact_type  TEXT PRIMARY KEY,
        data          TEXT NOT NULL,
        saved_at      TEXT NOT NULL
      )
    ''');

    // sales_cache: the most-recently-fetched sales list.
    //   cache_key — always "list" (only one sales list at a time)
    //   data      — JSON array of raw sale objects from the API
    //   saved_at  — ISO-8601 timestamp
    await db.execute('''
      CREATE TABLE sales_cache (
        cache_key   TEXT PRIMARY KEY,
        data        TEXT NOT NULL,
        saved_at    TEXT NOT NULL
      )
    ''');

    // pending_sales: create/update/delete actions queued while offline.
    //   id          — auto-increment row id (used to remove one action after replay)
    //   action_type — "create", "update", or "delete"
    //   sale_id     — the server-side id; NULL for creates
    //   payload     — JSON-encoded request body to send when back online
    //   queued_at   — ISO-8601 timestamp (actions are replayed oldest-first)
    await db.execute('''
      CREATE TABLE pending_sales (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        sale_id     INTEGER,
        payload     TEXT NOT NULL,
        queued_at   TEXT NOT NULL
      )
    ''');
  }
}
