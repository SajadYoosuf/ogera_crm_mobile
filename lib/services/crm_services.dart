import '../core/network/api_client.dart';
import '../models/contact.dart';
import '../models/followup.dart';
import '../models/performance.dart';
import '../models/professional.dart';
import '../models/sale.dart';

/// One file for the four record modules: they share the same envelope, the same
/// bearer token, and the same shape of list/detail/create/update/delete calls.

class ContactsService {
  const ContactsService(this._api);

  final ApiClient _api;

  Future<ContactPage> list({
    String? query,
    ContactType? type,
    String? source,
    String? startDate,
    String? endDate,
    String? addedBy,
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/api/contacts',
      query: {
        'query': query,
        'type': type?.id,
        'source': source,
        'startDate': startDate,
        'endDate': endDate,
        'addedBy': addedBy,
        'page': page,
        'limit': limit,
      },
    );
    return ContactPage.fromJson(asMap(data));
  }

  Future<List<ContactPin>> mapPins({ContactType? type}) async {
    final data = await _api.get(
      '/api/contacts',
      query: {'fields': 'map', 'type': type?.id},
    );
    return asList(
      asMap(data)['contacts'],
    ).map(ContactPin.fromJson).whereType<ContactPin>().toList(growable: false);
  }

  Future<Contact> detail(int id) async {
    final data = await _api.get('/api/contacts/$id');
    return Contact.fromJson(asMap(data));
  }

  Future<Contact> create(ContactDraft draft) async {
    final data = await _api.post('/api/contacts', body: draft.toJson());
    return Contact.fromJson(asMap(data));
  }

  Future<Contact> update(int id, ContactDraft draft) async {
    final data = await _api.put('/api/contacts/$id', body: draft.toJson());
    return Contact.fromJson(asMap(data));
  }

  Future<void> delete(int id) => _api.delete('/api/contacts/$id');

  /// Referral picker: contacts already surfaced by the paged list endpoint.
  Future<List<Contact>> search(String query) async {
    final page = await list(query: query, limit: 10);
    return page.contacts;
  }
}

class ProfessionalsService {
  const ProfessionalsService(this._api);

  final ApiClient _api;

  /// Omitting `type` asks the endpoint for every profession in one request.
  /// This used to fan out one request per profession and merge the results,
  /// which double-counted any type the server did not recognise.
  Future<List<Professional>> list({
    ProfessionalType? type,
    String? query,
  }) async {
    final data = await _api.get(
      '/api/professionals',
      query: {'type': type?.id, 'query': query},
    );
    return asList(
      asMap(data)['professionals'],
    ).map(Professional.fromJson).toList(growable: false);
  }

  Future<Professional> detail(int id) async {
    final data = await _api.get('/api/professionals/$id');
    return Professional.fromJson(asMap(data));
  }

  Future<Professional> create(ProfessionalDraft draft) async {
    final data = await _api.post('/api/professionals', body: draft.toJson());
    return Professional.fromJson(asMap(data));
  }

  Future<Professional> update(int id, ProfessionalDraft draft) async {
    final data = await _api.put('/api/professionals/$id', body: draft.toJson());
    return Professional.fromJson(asMap(data));
  }

  Future<void> delete(int id) => _api.delete('/api/professionals/$id');
}

class FollowupsService {
  const FollowupsService(this._api);

  final ApiClient _api;

  Future<List<Lead>> leads() async {
    final data = await _api.get('/api/followups');
    return asList(
      asMap(data)['leads'],
    ).map(Lead.fromJson).toList(growable: false);
  }

  Future<List<Stage>> stages() async {
    final data = await _api.get('/api/followups/stages');
    final stages =
        (data is List ? asList(data) : asList(asMap(data)['stages']))
            .map(Stage.fromJson)
            .toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return stages;
  }

  /// Sends only the fields that changed, so an unrelated column is never
  /// blanked by a partial edit.
  Future<void> updateLead(
    int id, {
    String? stage,
    String? assignedTo,
    bool clearAssignee = false,
    String? dueDate,
    bool clearDueDate = false,
  }) {
    final body = <String, dynamic>{'id': id, 'stage': ?stage};
    // Clearing is an explicit null / empty string; leaving a field out entirely
    // is what tells the API not to touch that column.
    if (clearAssignee) {
      body['followupAssignedTo'] = null;
    } else if (assignedTo != null) {
      body['followupAssignedTo'] = assignedTo;
    }
    if (clearDueDate) {
      body['followupDueDate'] = '';
    } else if (dueDate != null) {
      body['followupDueDate'] = dueDate;
    }
    return _api.put('/api/followups', body: body);
  }

  Future<List<Remark>> remarks(int leadId) async {
    final data = await _api.get('/api/followups/$leadId/remarks');
    return asList(
      asMap(data)['remarks'],
    ).map(Remark.fromJson).toList(growable: false);
  }

  Future<void> addRemark(int leadId, String remark) {
    return _api.post(
      '/api/followups/$leadId/remarks',
      body: {'remark': remark},
    );
  }

  Future<void> deleteLead(int id) => _api.delete('/api/followups', body: {'id': id});

  Future<Stage> createStage(String label) async {
    final data = await _api.post(
      '/api/followups/stages',
      body: {'label': label},
    );
    return Stage.fromJson(asMap(data));
  }

  Future<void> updateStage(String id, {String? label, int? orderIndex}) {
    return _api.put(
      '/api/followups/stages',
      body: {'id': id, 'label': ?label, 'orderIndex': ?orderIndex},
    );
  }
}

class SalesService {
  const SalesService(this._api);

  final ApiClient _api;

  Future<SalePage> list({
    String? query,
    String? panchayath,
    String? ward,
    String? waterSource,
    String? sourceOfSale,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      '/api/sales',
      query: {
        'query': query,
        'panchayath': panchayath,
        'ward': ward,
        'waterSource': waterSource,
        'sourceOfSale': sourceOfSale,
        'startDate': startDate,
        'endDate': endDate,
        'page': page,
        'limit': limit,
      },
    );
    return SalePage.fromJson(asMap(data));
  }

  /// There is no `GET /api/sales/[id]` — the sale row itself always comes from
  /// the list. `/details` returns only what hangs off the sale, and each of its
  /// three lists degrades to empty rather than failing the request.
  Future<List<Contact>> referrals(int saleId) async {
    final data = await _api.get('/api/sales/$saleId/details');
    return asList(
      asMap(data)['referrals'],
    ).map(Contact.fromJson).toList(growable: false);
  }

  Future<Sale> create(SaleDraft draft) async {
    final data = await _api.post('/api/sales', body: draft.toJson());
    return Sale.fromJson(asMap(data));
  }

  Future<Sale> update(int id, SaleDraft draft) async {
    final data = await _api.put('/api/sales/$id', body: draft.toJson());
    return Sale.fromJson(asMap(data));
  }

  Future<void> delete(int id) => _api.delete('/api/sales/$id');

  Future<List<ProductOption>> products() async {
    final data = await _api.get('/api/sales/products');
    return asList(data).map(ProductOption.fromJson).toList(growable: false);
  }

  /// Referral picker for the contact form.
  Future<List<Sale>> search(String query) async {
    final data = await _api.get('/api/sales/search', query: {'query': query});
    return asList(data).map(Sale.fromJson).toList(growable: false);
  }
}

class PerformanceService {
  const PerformanceService(this._api);

  final ApiClient _api;

  /// Heads get the whole team; the server narrows a staff session to itself.
  Future<PerformanceReport> fetch({
    required String startDate,
    required String endDate,
  }) async {
    final data = await _api.get(
      '/api/performance',
      query: {'startDate': startDate, 'endDate': endDate},
    );
    return PerformanceReport.fromJson(data);
  }
}

class StaffDirectoryService {
  const StaffDirectoryService(this._api);

  final ApiClient _api;

  Future<List<StaffMember>> list() async {
    final data = await _api.get('/api/staff');
    return asList(data).map(StaffMember.fromJson).toList(growable: false);
  }
}
