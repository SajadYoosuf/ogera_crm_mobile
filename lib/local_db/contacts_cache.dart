// contacts_cache.dart
//
// Reads and writes Contact objects to the local SQLite cache.
//
// WHY THIS EXISTS:
//   When the device has no internet, the contacts list would show an error.
//   This cache saves the last successful API response so the user can still
//   browse their contacts while offline.
//
// HOW THE CACHE KEY WORKS:
//   The contacts list changes based on the active tab (contact type) and the
//   current page number. The cache key captures both so we store multiple
//   pages without them overwriting each other.
//   Format: "<kind>|page<number>"  e.g. "consumer|page1", "all|page1"
//
// HOW TO USE (in ContactsViewModel):
//   final cache = ContactsCache();
//
//   // After a successful API call — save to cache:
//   await cache.save(key, contacts);
//
//   // When offline — load from cache:
//   final cached = await cache.load(key);
//
// NOTE: This cache is not encrypted. Contact data is business data the user
// already sees on their screen.

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../local_db/local_database.dart';
import '../models/contact.dart';

class ContactsCache {
  static const _table = 'contacts_cache';

  // Cache entries older than this are treated as stale and ignored.
  // One hour is long enough for a field visit but short enough that the
  // user does not see week-old data on a spotty connection.
  static const _maxAge = Duration(hours: 1);

  /// Saves [contacts] under [key]. Overwrites any previous entry with the same key.
  ///
  /// [key] is usually built with [cacheKey] to ensure consistency.
  Future<void> save(String key, List<Contact> contacts) async {
    final db = await LocalDatabase.get();
    final rows = contacts.map(_contactToJson).toList();
    await db.insert(
      _table,
      {
        'cache_key': key,
        'data': jsonEncode(rows),
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the cached contacts for [key], or an empty list when the cache is
  /// empty, missing, or older than [_maxAge].
  Future<List<Contact>> load(String key) async {
    final db = await LocalDatabase.get();
    final rows = await db.query(
      _table,
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return [];

    final row = rows.first;
    final savedAt = DateTime.tryParse(row['saved_at'] as String? ?? '');
    if (savedAt == null) return [];

    // Reject entries that are too old.
    if (DateTime.now().toUtc().difference(savedAt) > _maxAge) return [];

    try {
      final list = jsonDecode(row['data'] as String) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Contact.fromJson)
          .toList(growable: false);
    } on FormatException {
      return []; // Corrupted entry — treat as empty.
    }
  }

  /// Removes every row from the contacts cache.
  /// Call this on sign-out so one user's data is not left on the device for the next.
  Future<void> clear() async {
    final db = await LocalDatabase.get();
    await db.delete(_table);
  }

  /// Builds the cache key for a given contact type and page number.
  ///
  /// Examples:
  ///   cacheKey(kind: ContactKind.consumer, page: 1) → "consumer|page1"
  ///   cacheKey(kind: null, page: 1)                 → "all|page1"
  static String cacheKey({ContactKind? kind, int page = 1}) {
    final kindLabel = kind?.id ?? 'all';
    return '$kindLabel|page$page';
  }

  // Converts a Contact to a plain map Contact.fromJson() can reconstruct.
  // Only the fields a list-row contact carries are written (full detail fields
  // like consumer_profile are skipped — they are never in the list response).
  static Map<String, dynamic> _contactToJson(Contact c) {
    return {
      'id': c.id,
      'contact_type': c.contactType.id,
      'name': c.name,
      'phone': c.phone,
      'phone_alt': c.phoneAlt,
      'district': c.district,
      'address': c.address,
      'notes': c.notes,
      'latitude': c.latitude,
      'longitude': c.longitude,
      'referred_by_id': c.referredById,
      'lead_source_id': c.leadSourceId,
      if (c.leadSource != null)
        'lead_source': {
          'id': c.leadSource!.id,
          'name': c.leadSource!.name,
          'slug': c.leadSource!.slug,
        },
      // assigned_to: the list sends a {id, name} object — replicate that shape.
      if (c.assignedEmployee != null)
        'assigned_to': {
          'id': c.assignedEmployee!.id,
          'name': c.assignedEmployee!.name,
        }
      else
        'assigned_to': c.assignedTo,
      // created_by: same — list sends {id, name}.
      if (c.createdByEmployee != null)
        'created_by': {
          'id': c.createdByEmployee!.id,
          'name': c.createdByEmployee!.name,
        }
      else
        'created_by': c.createdBy,
      'created_at': c.createdAt.toIso8601String(),
      'updated_at': c.updatedAt?.toIso8601String(),
      'referrals_count': c.referralsCount,
      'is_verified': c.isVerified,
      'missing_fields': c.missingFields,
      if (c.currentStage != null)
        'lead_stage': {
          'stage_id': c.currentStage!.stageId,
          'stage_slug': c.currentStage!.stageSlug,
          'stage_name': c.currentStage!.stageName,
        },
      'house_stage': c.houseStage,
      'profession_type': c.professionType,
      'work_area': c.workArea,
      'owner_name': c.ownerName,
    };
  }
}
