// pipeline_cache.dart
//
// Reads and writes PipelineContact objects to the local SQLite cache.
//
// WHY THIS EXISTS:
//   The pipeline board fetches ALL contacts in one shot so it can show counts
//   per stage column. That is a large request. Caching means the board loads
//   instantly on revisit and still works when the device is offline.
//
// HOW THE CACHE KEY WORKS:
//   The board has three tabs: consumer, partner, dealer. Each tab has its own
//   cache row keyed by contact_type so switching tabs does not clear the others.
//
// HOW TO USE (in PipelineViewModel):
//   final cache = PipelineCache();
//
//   // After a successful API call:
//   await cache.save(contactType: 'consumer', contacts: contacts);
//
//   // When offline:
//   final cached = await cache.load(contactType: 'consumer');

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../local_db/local_database.dart';
import '../services/pipeline_service.dart';

class PipelineCache {
  static const _table = 'pipeline_cache';

  // Pipeline data can change from reassignments and stage moves during the day.
  // 2 hours gives the team a useful offline buffer without serving stale boards.
  static const _maxAge = Duration(hours: 2);

  /// Saves all [contacts] for the given [contactType] ("consumer", "partner", or "dealer").
  Future<void> save({
    required String contactType,
    required List<PipelineContact> contacts,
  }) async {
    final db = await LocalDatabase.get();
    final rows = contacts.map(_contactToJson).toList();
    await db.insert(
      _table,
      {
        'contact_type': contactType,
        'data': jsonEncode(rows),
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns cached contacts for [contactType], or an empty list if missing or stale.
  Future<List<PipelineContact>> load({required String contactType}) async {
    final db = await LocalDatabase.get();
    final rows = await db.query(
      _table,
      where: 'contact_type = ?',
      whereArgs: [contactType],
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
          .map(PipelineContact.fromJson)
          .toList(growable: false);
    } on FormatException {
      return [];
    }
  }

  /// Removes every row from the pipeline cache.
  Future<void> clear() async {
    final db = await LocalDatabase.get();
    await db.delete(_table);
  }

  // Converts a PipelineContact to a plain map that PipelineContact.fromJson() can
  // reconstruct. We use the same field names the backend sends.
  static Map<String, dynamic> _contactToJson(PipelineContact c) {
    return {
      'id': c.id,
      'phone': c.phone,
      'contact_type': c.contactType,
      'name': c.name,
      'district': c.district,
      'missing_fields': c.missingFields,
      // The stage slug lives inside a `lead_stage` object in the API response.
      if (c.stageSlug != null)
        'lead_stage': {
          'stage_slug': c.stageSlug,
          'stage_name': c.stageName,
        },
      // assigned_to is sent as {id, name} in the list response.
      if (c.assignedToId != null)
        'assigned_to': {
          'id': c.assignedToId,
          'name': c.assignedToName ?? '',
        },
    };
  }
}
