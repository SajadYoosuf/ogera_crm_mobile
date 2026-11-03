// contacts_service.dart
//
// Handles all API calls related to contacts (customers / leads).
// A contact is a person the business tracks — they can be a consumer,
// a partner, or a dealer depending on the contact_type field.
//
// This file also contains two shared helpers used internally:
//   - LeadSourceCatalog   : maps lead-source slugs to their server IDs
//   - SettingsOptionsCatalog : fetches admin-managed dropdown lists once per session

import '../core/network/api_client.dart';
import '../core/reference/crm_options.dart';
import '../core/utils/formatters.dart';
import '../models/contact.dart';

// ── Shared helpers ─────────────────────────────────────────────────────────

/// The API refers to a lead source by integer id, but the app uses readable
/// slugs like "meta" or "website". This catalog fetches the mapping once from
/// GET /lead-sources and keeps it in memory for the lifetime of the ApiClient.
class LeadSourceCatalog {
  LeadSourceCatalog._(this._api);

  // One catalog instance per ApiClient — shared by all services that need it.
  static final _catalogs = Expando<LeadSourceCatalog>('LeadSourceCatalog');

  factory LeadSourceCatalog.of(ApiClient api) =>
      _catalogs[api] ??= LeadSourceCatalog._(api);

  final ApiClient _api;
  Map<String, int>? _idsBySlug;

  // Old label → current slug mappings, so data from older builds still filters correctly.
  static const _aliases = {'online': 'website'};

  static String normalise(String slug) {
    final key = slug.trim().toLowerCase();
    return _aliases[key] ?? key;
  }

  Future<Map<String, int>> _load() async {
    final cached = _idsBySlug;
    if (cached != null) return cached;
    final data = await _api.get('/lead-sources');
    final loaded = <String, int>{
      for (final row in asList(data))
        if (asText(row['slug']) != null && asInt(row['id']) != null)
          asText(row['slug'])!: asInt(row['id'])!,
    };
    return _idsBySlug = loaded;
  }

  /// Returns the server id for a slug, or null if the server has no such source.
  Future<int?> idFor(String? slug) async {
    if ((slug ?? '').trim().isEmpty) return null;
    return (await _load())[normalise(slug!)];
  }
}

/// Admin-managed dropdown lists, read from GET /settings/enums/{category}.
/// Each category is fetched once per ApiClient and cached in memory.
/// Falls back to a hardcoded list when the request fails (offline or error),
/// so pickers are never empty.
class SettingsOptionsCatalog {
  SettingsOptionsCatalog._(this._api);

  static final _catalogs = Expando<SettingsOptionsCatalog>(
    'SettingsOptionsCatalog',
  );

  factory SettingsOptionsCatalog.of(ApiClient api) =>
      _catalogs[api] ??= SettingsOptionsCatalog._(api);

  final ApiClient _api;
  final _byCategory = <String, Map<String, String>>{};

  /// Returns active options as {value: label} in the admin's sort order.
  /// A failed fetch is not cached so the next call retries.
  Future<Map<String, String>> options(
    String category, {
    required Map<String, String> fallback,
  }) async {
    final cached = _byCategory[category];
    if (cached != null) return cached;
    try {
      final rows = asList(await _api.get('/settings/enums/$category'));
      final loaded = <String, String>{
        for (final row in rows)
          if (asText(row['value']) != null)
            asText(row['value'])!:
                asText(row['label']) ?? asText(row['value'])!,
      };
      if (loaded.isEmpty) return fallback;
      return _byCategory[category] = loaded;
    } on Exception {
      return fallback;
    }
  }
}

// ── ContactsService ────────────────────────────────────────────────────────

/// All API calls for contacts (create, read, update, delete, search, filters).
///
/// What it does:
///   - Fetches a paged list of contacts with filters (search, source, date, assignee)
///   - Creates and updates contacts, resolving lead-source slugs to server IDs
///   - Fetches dropdown options (house stages, lead sources) from the server
///   - Provides a quick search method used by the referral picker and activity picker
///
/// Why: keeps all the HTTP and JSON translation for contacts in one place,
/// so view models and screens only work with clean Dart objects.
class ContactsService {
  ContactsService(this._api)
    : _sources = LeadSourceCatalog.of(_api),
      _options = SettingsOptionsCatalog.of(_api);

  final ApiClient _api;
  final LeadSourceCatalog _sources;
  final SettingsOptionsCatalog _options;

  /// House stage options for the contact form, fetched from admin settings.
  Future<Map<String, String>> houseStages() =>
      _options.options('house_stage', fallback: CrmOptions.defaultHouseStages);

  /// Lead source options for the filter chip bar.
  /// Only sources the admin has enabled appear here.
  /// Falls back to the built-in list if the request fails.
  Future<Map<String, String>> leadSourceOptions() async {
    try {
      final rows = asList(await _api.get('/lead-sources'));
      final loaded = <String, String>{
        for (final row in rows)
          if (asText(row['slug']) != null)
            asText(row['slug'])!:
                asText(row['name']) ??
                CrmOptions.sourceLabel(asText(row['slug'])!),
      };
      if (loaded.isNotEmpty) return loaded;
    } on Exception {
      // Fall through to the built-in list below.
    }
    return {
      for (final slug in CrmOptions.contactSources)
        slug: CrmOptions.sourceLabel(slug),
    };
  }

  /// One page of contacts for the Contacts tab.
  ///
  /// [kind] picks one contact type (consumer by default).
  /// Pass kind: null explicitly to get all contact types (the "All" tab).
  Future<ContactPage> list({
    ContactKind? kind = ContactKind.consumer,
    String? query,
    String? source,
    String? startDate,
    String? endDate,
    String? addedBy,
    int? assignedTo,
    int? createdBy,
    int page = 1,
    int limit = 20,
  }) async {
    var sourceId = await _sources.idFor(source);
    // An unknown source slug returns -1 so the filter matches nothing rather
    // than being silently ignored.
    if (source != null && source.isNotEmpty && sourceId == null) sourceId = -1;

    final data = await _api.get(
      '/contacts',
      query: {
        if (kind != null) 'contact_type': kind.id,
        'search': query,
        'lead_source_id': sourceId,
        'created_from': startDate,
        'created_to': endDate,
        'created_by':
            createdBy ?? (addedBy == 'unattributed' ? null : addedBy),
        'unattributed': addedBy == 'unattributed' ? true : null,
        'assigned_to': assignedTo,
        'skip': (page - 1) * limit,
        'limit': limit,
      },
    );
    return ContactPage.fromJson(asMap(data));
  }

  /// Tab badge counts — totals per contact type, ignoring search and filters.
  Future<ContactTypeCounts> typeCounts() async {
    final data = await _api.get('/contacts/type-counts');
    return ContactTypeCounts.fromJson(asMap(data));
  }

  // TODO(map): ContactPin model not yet defined; mapPins returns raw JSON for now.
  Future<List<Map<String, dynamic>>> mapPins({ContactKind? type}) async {
    final data = await _api.get(
      '/contacts/map',
      query: {
        'contact_type': 'consumer',
        if (type != null) 'contact_kind': type.id,
      },
    );
    return asList(
      asMap(data)['items'],
    ).whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<Contact> detail(int id) async {
    final data = await _api.get('/contacts/$id');
    return Contact.fromJson(asMap(data));
  }

  Future<Contact> create(ContactDraft draft) async {
    final data = await _api.post('/contacts', body: await _body(draft));
    return Contact.fromJson(asMap(data));
  }

  Future<Contact> update(int id, ContactDraft draft) async {
    final data = await _api.put('/contacts/$id', body: await _body(draft));
    return Contact.fromJson(asMap(data));
  }

  Future<void> delete(int id) => _api.delete('/contacts/$id');

  /// Quick search used by the referral picker and activity log picker.
  /// Returns the first 10 matches by name or phone.
  Future<List<Contact>> search(
    String query, {
    int? assignedTo,
    int? createdBy,
  }) async {
    final page = await list(
      query: query,
      assignedTo: assignedTo,
      createdBy: createdBy,
      limit: 10,
    );
    return page.contacts;
  }

  /// Builds the request body for create and update.
  /// Resolves the lead-source slug to its server ID, and marks GPS coordinates
  /// as required when the source is a field visit.
  Future<Map<String, dynamic>> _body(ContactDraft draft) async {
    final slug = draft.source == null
        ? null
        : LeadSourceCatalog.normalise(draft.source!);
    return draft.toApiJson(
      leadSourceId: await _sources.idFor(slug),
      // Both "offline" and "field_visit" are GPS-based sources.
      offline: slug == 'offline' || slug == 'field_visit',
    );
  }
}
