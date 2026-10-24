import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/reference/crm_options.dart';
import '../models/contact.dart';
import '../services/crm_services.dart';

/// Paged, searchable, filterable contacts list.
///
/// Search is debounced so typing a phone number does not fire ten requests, and
/// every fetch carries a sequence number: a slow response for an abandoned
/// query is discarded rather than overwriting fresher results.
class ContactsViewModel extends ChangeNotifier {
  ContactsViewModel(this._service);

  final ContactsService _service;

  static const _pageSize = 20;
  static const _debounce = Duration(milliseconds: 350);

  final List<Contact> _contacts = [];
  Timer? _debounceTimer;
  int _sequence = 0;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  String _query = '';
  // null means the "All Contacts" tab; otherwise one of consumer/partner/dealer.
  ContactKind? _kind;
  String? _source;
  String? _startDate;
  String? _endDate;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  ContactTypeCounts _counts = const ContactTypeCounts();

  List<Contact> get contacts => List.unmodifiable(_contacts);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _page < _totalPages;
  String? get error => _error;
  String get query => _query;
  ContactKind? get kind => _kind;
  String? get source => _source;
  String? get startDate => _startDate;
  String? get endDate => _endDate;
  int get total => _total;

  /// Badge numbers for the type tabs.
  ContactTypeCounts get counts => _counts;

  bool get hasFilters =>
      _source != null ||
      _startDate != null ||
      _endDate != null ||
      _query.isNotEmpty;

  int countFor(ContactKind? kind) => _counts.of(kind);

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    _page = 1;
    await _fetch(page: 1, replace: true);
  }

  Future<void> refresh() => _fetch(page: 1, replace: true);

  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    await _fetch(page: _page + 1, replace: false);
  }

  void search(String value) {
    _query = value.trim();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => load(silent: false));
  }

  /// Switches the type tab. Re-selecting the same tab does nothing.
  void selectKind(ContactKind? kind) {
    if (_kind == kind) return;
    _kind = kind;
    load();
  }

  void applyFilters({
    String? source,
    String? startDate,
    String? endDate,
    bool clearSource = false,
    bool clearDates = false,
  }) {
    _source = clearSource ? null : (source ?? _source);
    if (clearDates) {
      _startDate = null;
      _endDate = null;
    } else {
      _startDate = startDate ?? _startDate;
      _endDate = endDate ?? _endDate;
    }
    load();
  }

  void clearFilters() {
    _source = null;
    _startDate = null;
    _endDate = null;
    load();
  }

  Future<void> _fetch({required int page, required bool replace}) async {
    final sequence = ++_sequence;
    try {
      final result = await _service.list(
        query: _query.isEmpty ? null : _query,
        // Explicit null on purpose: the "All Contacts" tab must not be limited to consumers.
        kind: _kind,
        source: _source,
        startDate: _startDate,
        endDate: _endDate,
        page: page,
        limit: _pageSize,
      );
      if (sequence != _sequence) return;

      if (replace) {
        _contacts
          ..clear()
          ..addAll(result.contacts);
      } else {
        _contacts.addAll(result.contacts);
      }
      _page = result.page;
      _totalPages = result.totalPages;
      _total = result.total;
      _error = null;
      if (replace) await _loadCounts();
    } on ApiException catch (error) {
      if (sequence != _sequence) return;
      _error = error.message;
      if (replace) _contacts.clear();
    } finally {
      if (sequence == _sequence) {
        _isLoading = false;
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Refreshes the tab badges. A failed count keeps the last numbers and must
  /// not hide the list, the same rule the web page follows.
  Future<void> _loadCounts() async {
    try {
      _counts = await _service.typeCounts();
    } on ApiException {
      // Keep the previous counts.
    }
  }

  /// Applied after a create, edit, or delete so the list reflects the change
  /// without a full refetch.
  void upsert(Contact contact) {
    final index = _contacts.indexWhere((item) => item.id == contact.id);
    final shown = _kind == null || contact.contactType == _kind;
    if (index == -1) {
      if (shown) {
        _contacts.insert(0, contact);
        _total++;
      }
    } else if (shown) {
      _contacts[index] = contact;
    } else {
      _contacts.removeAt(index);
      _total--;
    }
    notifyListeners();
  }

  void removeById(int id) {
    final removed = _contacts.length;
    _contacts.removeWhere((contact) => contact.id == id);
    if (_contacts.length != removed) {
      _total = (_total - 1).clamp(0, 1 << 30);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Backs the create / edit form. Keeps validation and the save call in one
/// place so both entry points behave identically.
class ContactFormViewModel extends ChangeNotifier {
  ContactFormViewModel(this._service, {Contact? existing})
    : _existing = existing,
      draft = existing == null
          ? ContactDraft(phone: '', source: 'offline')
          : ContactDraft.fromContact(existing);

  final ContactsService _service;
  final Contact? _existing;
  final ContactDraft draft;

  bool _isSaving = false;
  String? _error;

  bool get isEditing => _existing != null;
  bool get isSaving => _isSaving;
  String? get error => _error;

  /// House stage options from Settings, as {stored value: label}. The draft
  /// keeps the stored value; the form shows the label.
  Map<String, String> houseStages = CrmOptions.defaultHouseStages;

  /// Loads the Settings list once the form opens, then redraws the form.
  Future<void> loadHouseStages() async {
    houseStages = await _service.houseStages();
    notifyListeners();
  }

  String? validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Enter a phone number.';
    if (digits.length < 10) return 'Enter at least 10 digits.';
    return null;
  }

  /// A campaign target must name the staff member it belongs to — the same rule
  /// the API enforces, checked here so the user sees it before a round-trip.
  // TODO(campaign): isCampaignTarget / campaignStaffId not yet on ContactDraft.
  String? validateCampaign() {
    return null;
  }

  void setType(ContactKind type) {
    draft.contactType = type;
    notifyListeners();
  }

  void setLocation({String? latitude, String? longitude, String? address}) {
    draft.latitude = latitude;
    draft.longitude = longitude;
    if (address != null && address.isNotEmpty) draft.address = address;
    notifyListeners();
  }

  /// Referral paths are mutually exclusive: choosing one clears the other.
  void setContactReferral(int? contactId) {
    draft.referredByContactId = contactId;
    _clearProfessionalReferral();
    notifyListeners();
  }

  /// The professional reference is stored alongside a name/type/phone snapshot,
  /// so the record still reads correctly if the professional is later edited.
  // TODO(referral): professionalType/Name/Phone/Address/Latitude/Longitude not
  // yet on ContactDraft — add them when the professional-referral UI is built.
  void setProfessionalReferral({
    required String type,
    required String name,
    required String phone,
    String? address,
    String? latitude,
    String? longitude,
  }) {
    draft.referredByContactId = null;
    notifyListeners();
  }

  void clearReferral() {
    draft.referredByContactId = null;
    _clearProfessionalReferral();
    notifyListeners();
  }

  void _clearProfessionalReferral() {
    draft.referredByContactId = null;
  }

  // TODO(campaign): isCampaignTarget / campaignStaffId not yet on ContactDraft.
  void setCampaign({required bool isTarget, String? staffId}) {
    notifyListeners();
  }

  /// The rules the API enforces on a contact, checked first so the user sees
  /// them before a round-trip: district and address are required, and an
  /// Offline lead must come with the place it was captured.
  String? validateBeforeSave() {
    if ((draft.district ?? '').trim().isEmpty) return 'Select the district.';
    if ((draft.address ?? '').trim().isEmpty) return 'Enter the address.';
    final offline =
        LeadSourceCatalog.normalise(draft.source ?? '') == 'offline';
    final hasLocation =
        double.tryParse((draft.latitude ?? '').trim()) != null &&
        double.tryParse((draft.longitude ?? '').trim()) != null;
    if (offline && !hasLocation && _existing == null) {
      return 'Capture the location for an Offline contact.';
    }
    return null;
  }

  Future<Contact?> save() async {
    final problem = validateCampaign() ?? validateBeforeSave();
    if (problem != null) {
      _error = problem;
      notifyListeners();
      return null;
    }

    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final saved = _existing == null
          ? await _service.create(draft)
          : await _service.update(_existing.id, draft);
      return saved;
    } on ApiException catch (error) {
      _error = error.message;
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
