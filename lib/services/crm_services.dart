import '../core/network/api_client.dart';
import '../core/reference/crm_options.dart';
import '../core/utils/formatters.dart';
import '../models/contact.dart';
import '../models/followup.dart';
import '../models/lead_work.dart';
import '../models/professional.dart';

/// One file for the record modules. They all talk to the same FastAPI server
/// with the same bearer token; the services translate between its snake_case
/// JSON and the shapes the screens already use.

/// The API refers to a lead source by id, the app by slug. This looks the id
/// up once per [ApiClient] and keeps it, since sources rarely change.
class LeadSourceCatalog {
  LeadSourceCatalog._(this._api);

  static final _catalogs = Expando<LeadSourceCatalog>('LeadSourceCatalog');

  /// One catalog per API client, shared by every service built on it.
  factory LeadSourceCatalog.of(ApiClient api) =>
      _catalogs[api] ??= LeadSourceCatalog._(api);

  final ApiClient _api;
  Map<String, int>? _idsBySlug;

  /// Older builds stored these labels; map them onto today's slugs.
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

  /// The id for a slug, or null when the server has no such source.
  Future<int?> idFor(String? slug) async {
    if ((slug ?? '').trim().isEmpty) return null;
    return (await _load())[normalise(slug!)];
  }
}

/// Pages through a list endpoint that answers `{ items, total }`, so a screen
/// that wants "everything" does not need to know the page size.
Future<List<Map<String, dynamic>>> _fetchAll(
  ApiClient api,
  String path,
  Map<String, dynamic> query, {
  int pageSize = 100,
  int maxPages = 20,
}) async {
  final rows = <Map<String, dynamic>>[];
  for (var page = 0; page < maxPages; page++) {
    final data = asMap(
      await api.get(
        path,
        query: {...query, 'skip': page * pageSize, 'limit': pageSize},
      ),
    );
    final items = asList(data['items']);
    rows.addAll(items);
    final total = asInt(data['total']) ?? rows.length;
    // A short page is the last one, whatever the total claims.
    if (items.length < pageSize || rows.length >= total) break;
  }
  return rows;
}

/// Dropdown options an admin manages in Settings > Lists & Options, read from
/// `GET /settings/enums/{category}`. Each category is fetched once per
/// [ApiClient] and kept, like [LeadSourceCatalog].
class SettingsOptionsCatalog {
  SettingsOptionsCatalog._(this._api);

  static final _catalogs = Expando<SettingsOptionsCatalog>(
    'SettingsOptionsCatalog',
  );

  factory SettingsOptionsCatalog.of(ApiClient api) =>
      _catalogs[api] ??= SettingsOptionsCatalog._(api);

  final ApiClient _api;
  final _byCategory = <String, Map<String, String>>{};

  /// Active options of [category] in Settings order, as {value: label}.
  /// Falls back to [fallback] when the request fails or returns nothing, so a
  /// picker is never empty. A failed load is not cached; the next call retries.
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

class ContactsService {
  ContactsService(this._api)
    : _sources = LeadSourceCatalog.of(_api),
      _options = SettingsOptionsCatalog.of(_api);

  final ApiClient _api;
  final LeadSourceCatalog _sources;
  final SettingsOptionsCatalog _options;

  /// House stages for the contact form, as {stored value: label}.
  Future<Map<String, String>> houseStages() =>
      _options.options('house_stage', fallback: CrmOptions.defaultHouseStages);

  /// Active lead sources from the server, as {slug: name}. Only the sources the
  /// admin has switched on appear here, so a filter never offers a dead option.
  /// Falls back to the built-in list when the request fails, so the picker is
  /// never empty.
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

  /// One page of contacts for the Contacts tab and other list screens.
  ///
  /// [kind] picks one type. It is a default parameter, so leaving it out gives
  /// consumers only (the pipeline relies on this). Passing `kind: null`
  /// explicitly asks for every type, which is what the "All Contacts" tab does.
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
    // An unknown source can match nothing; -1 keeps the filter honest.
    if (source != null && source.isNotEmpty && sourceId == null) sourceId = -1;

    final data = await _api.get(
      '/contacts',
      query: {
        if (kind != null) 'contact_type': kind.id,
        'search': query,
        'lead_source_id': sourceId,
        'created_from': startDate,
        'created_to': endDate,
        // The performance drill-down asks for the contacts nobody is recorded
        // as having added.
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

  /// Totals per contact type for the tab badges. Ignores search and filters.
  Future<ContactTypeCounts> typeCounts() async {
    final data = await _api.get('/contacts/type-counts');
    return ContactTypeCounts.fromJson(asMap(data));
  }

  // TODO(map): ContactPin model not yet defined; mapPins returns raw JSON for now.
  // Replace List<Map<String,dynamic>> with a proper ContactPin model when the
  // map feature is built.
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

  Future<Map<String, dynamic>> _body(ContactDraft draft) async {
    final slug = draft.source == null
        ? null
        : LeadSourceCatalog.normalise(draft.source!);
    return draft.toApiJson(
      leadSourceId: await _sources.idFor(slug),
      // Both names are GPS sources: the backend's rule keys on `field_visit`,
      // while older mobile code and data use `offline`.
      offline: slug == 'offline' || slug == 'field_visit',
    );
  }

  Future<void> delete(int id) => _api.delete('/contacts/$id');

  /// Referral picker and activity picker: contacts from the paged list endpoint.
  /// Pass [assignedTo] or [createdBy] to limit results to one employee's contacts.
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
}

/// Professionals are the API's partner contacts.
class ProfessionalsService {
  ProfessionalsService(this._api) : _sources = LeadSourceCatalog.of(_api);

  final ApiClient _api;
  final LeadSourceCatalog _sources;

  /// Omitting `type` asks for every profession in one go.
  Future<List<Professional>> list({
    ProfessionalType? type,
    String? query,
  }) async {
    final rows = await _fetchAll(_api, '/contacts', {
      'contact_type': 'partner',
      'profession_type': type?.apiValue,
      'search': query,
    });
    return rows.map(Professional.fromJson).toList(growable: false);
  }

  Future<Professional> detail(int id) async {
    final data = await _api.get('/contacts/$id');
    return Professional.fromJson(asMap(data));
  }

  Future<Professional> create(ProfessionalDraft draft) async {
    final data = await _api.post('/contacts', body: await _body(draft));
    return Professional.fromJson(asMap(data));
  }

  Future<Professional> update(int id, ProfessionalDraft draft) async {
    final data = await _api.put('/contacts/$id', body: await _body(draft));
    return Professional.fromJson(asMap(data));
  }

  Future<Map<String, dynamic>> _body(ProfessionalDraft draft) async =>
      draft.toApiJson(offlineSourceId: await _sources.idFor('offline'));

  Future<void> delete(int id) => _api.delete('/contacts/$id');
}

/// The follow-up board: consumer contacts by pipeline stage, plus the open
/// follow-up tasks that give each lead its due date.
class FollowupsService {
  const FollowupsService(this._api);

  final ApiClient _api;

  static const _fixedStages = ApiException(
    'The pipeline stages are fixed and cannot be edited from the app.',
  );

  Future<List<Lead>> leads() async {
    final results = await Future.wait([
      _fetchAll(_api, '/contacts', {'contact_type': 'consumer'}),
      _openTaskDates(),
    ]);
    final dueByContact = results[1] as Map<int, String>;
    return (results[0] as List<Map<String, dynamic>>)
        .map(Lead.fromJson)
        .map((lead) => lead.withDueDate(dueByContact[lead.id]))
        .toList(growable: false);
  }

  /// Earliest open follow-up date per contact. Overdue tasks are included; the
  /// API narrows a staff session to their own tasks.
  Future<Map<int, String>> _openTaskDates() async {
    final today = DateTime.now();
    final data = await _api.get(
      '/tasks',
      query: {
        'status': 'open',
        'date_from': isoDate(today),
        'date_to': isoDate(today.add(const Duration(days: 60))),
        'include_overdue': true,
        'limit': 1000,
      },
    );
    final earliest = <int, String>{};
    for (final task in asList(asMap(data)['items'])) {
      final contactId = asInt(task['contact_id']);
      final date = asText(task['scheduled_date']);
      if (contactId == null || date == null) continue;
      final current = earliest[contactId];
      if (current == null || date.compareTo(current) < 0) {
        earliest[contactId] = date;
      }
    }
    return earliest;
  }

  Future<List<Stage>> stages() async {
    final data = await _api.get('/pipeline/stages');
    return asList(data).map(Stage.fromJson).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  /// Applies only the changes asked for, so an unrelated column is never
  /// touched by a partial edit.
  ///
  /// The API cannot unassign a lead or remove a follow-up date, so
  /// [clearAssignee] and [clearDueDate] are refused with a clear message.
  Future<void> updateLead(
    int id, {
    String? stage,
    String? assignedTo,
    bool clearAssignee = false,
    String? dueDate,
    bool clearDueDate = false,
  }) async {
    if (clearAssignee) {
      throw const ApiException(
        'Every lead needs an owner. Pick a staff member to reassign it.',
      );
    }
    if (clearDueDate) {
      throw const ApiException(
        'A follow-up date cannot be removed. Reschedule it or mark it done.',
      );
    }

    if (stage != null) {
      await _api.post(
        '/contacts/$id/stages',
        body: {
          'stage': stage,
          'changed_by': _api.currentUserId,
          // The API wants a reason for every lost lead.
          if (stage == 'lost') 'loss_reason': 'other',
        },
      );
    }

    final newOwner = int.tryParse(assignedTo ?? '');
    if (newOwner != null) {
      await _api.put('/contacts/$id', body: {'assigned_to': newOwner});
    }

    if (dueDate != null) {
      await _scheduleFollowup(id, dueDate, owner: newOwner);
    }
  }

  /// Moves the lead's open follow-up to [date], or books a call when it has
  /// none. The task belongs to the lead's owner.
  /// Uses the follow-up endpoints: the server rejects the old activity shape.
  /// Due time is the whole day (23:59), the same as the web app.
  Future<void> _scheduleFollowup(int id, String date, {int? owner}) async {
    final rows = asList(await _api.get('/contacts/$id/followups'));
    final open =
        rows
            .map(asMap)
            .where((f) => asText(f['status']) != 'completed')
            .toList()
          ..sort(
            (a, b) => (asText(a['due_at']) ?? '').compareTo(
              asText(b['due_at']) ?? '',
            ),
          );
    final dueAt = '${date}T23:59:00';
    if (open.isNotEmpty) {
      await _api.patch(
        '/contacts/$id/followups/${open.first['id']}',
        body: {'due_at': dueAt},
      );
      return;
    }
    final assignee =
        owner ??
        asInt(asMap(await _api.get('/contacts/$id'))['assigned_to']) ??
        _api.currentUserId;
    await _api.post(
      '/contacts/$id/followups',
      body: {'channel': 'phone_call', 'due_at': dueAt, 'assigned_to': assignee},
    );
  }

  /// The lead's timeline, newest first, from `GET /contacts/{id}/history`.
  ///
  /// One request gives every event (notes, follow-ups, stage moves, owner
  /// changes) with the fields the server actually sends. The server already
  /// orders them newest first, so no client-side sort is needed.
  Future<List<Remark>> remarks(int leadId) async {
    final rows = asList(await _api.get('/contacts/$leadId/history'));
    return [
      for (var i = 0; i < rows.length; i++)
        Remark.fromHistory(LeadHistoryEntry.fromJson(asMap(rows[i])), i + 1),
    ];
  }

  Future<void> addRemark(int leadId, String remark) {
    return _api.post(
      '/contacts/$leadId/activities',
      body: {'activity_type': 'internal_note', 'notes': remark},
    );
  }

  /// Books a new follow-up on a contact. Unlike [updateLead], which moves the
  /// open follow-up, this always adds one, so no earlier plan is overwritten.
  Future<void> addFollowup(
    int contactId, {
    required String date,
    int? assignedTo,
    String type = 'phone_call',
    String? notes,
  }) async {
    await _api.post(
      '/contacts/$contactId/followups',
      body: {
        'channel': type,
        'due_at': '${date}T23:59:00',
        'assigned_to': assignedTo ?? _api.currentUserId,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<void> deleteLead(int id) => _api.delete('/contacts/$id');

  Future<Stage> createStage(String label) => Future.error(_fixedStages);

  Future<void> updateStage(String id, {String? label, int? orderIndex}) =>
      Future.error(_fixedStages);
}

class StaffDirectoryService {
  const StaffDirectoryService(this._api);

  final ApiClient _api;

  Future<List<StaffMember>> list() async {
    final data = await _api.get('/employees/directory');
    return asList(data).map(StaffMember.fromJson).toList(growable: false);
  }
}
