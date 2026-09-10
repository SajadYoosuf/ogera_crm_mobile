import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';
import '../models/contact.dart';
import '../models/professional.dart';
import '../models/staff_location.dart';
import '../services/crm_services.dart';
import '../services/location_api_service.dart';

/// The three map layers. Staff sessions are only ever offered the first two —
/// the layer is absent from their switcher and the endpoint refuses them.
enum MapLayer {
  contacts('Contacts'),
  professionals('Professionals'),
  staff('Staff');

  const MapLayer(this.label);

  final String label;
}

class MapViewModel extends ChangeNotifier {
  MapViewModel({
    required ContactsService contacts,
    required ProfessionalsService professionals,
    required LocationApiService locations,
    required this.canViewStaff,
  }) : _contacts = contacts,
       _professionals = professionals,
       _locations = locations;

  final ContactsService _contacts;
  final ProfessionalsService _professionals;
  final LocationApiService _locations;

  /// Head only. Drives both the switcher and the polling loop.
  final bool canViewStaff;

  /// Kerala, where the field team works — used until real pins arrive.
  static const fallbackCentre = LatLng(11.2588, 75.7804);

  MapLayer _layer = MapLayer.contacts;
  Timer? _livePoll;

  List<ContactPin> _contactPins = const [];
  List<Professional> _professionalPins = const [];
  List<StaffLocation> _staffLocations = const [];

  bool _isLoading = true;
  String? _error;
  ContactType? _contactTypeFilter;
  ProfessionalType? _professionalTypeFilter;
  bool _liveOnly = false;
  String _staffQuery = '';
  int? _selectedStaffId;

  MapLayer get layer => _layer;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ContactType? get contactTypeFilter => _contactTypeFilter;
  ProfessionalType? get professionalTypeFilter => _professionalTypeFilter;
  bool get liveOnly => _liveOnly;
  int? get selectedStaffId => _selectedStaffId;

  List<MapLayer> get availableLayers => canViewStaff
      ? MapLayer.values
      : const [MapLayer.contacts, MapLayer.professionals];

  List<ContactPin> get contactPins => _contactPins;

  List<Professional> get professionalPins => _professionalTypeFilter == null
      ? _professionalPins
      : _professionalPins
            .where((item) => item.type == _professionalTypeFilter)
            .toList(growable: false);

  /// Staff rows for the sheet: filtered, then ordered so the people who are
  /// actually moving sit at the top.
  List<StaffLocation> get staffLocations {
    var rows = _staffLocations;
    if (_liveOnly) {
      rows = rows
          .where((row) => row.state == StaffState.moving)
          .toList(growable: false);
    }
    if (_staffQuery.isNotEmpty) {
      final needle = _staffQuery.toLowerCase();
      rows = rows
          .where((row) => row.name.toLowerCase().contains(needle))
          .toList(growable: false);
    }
    final ordered = [...rows]
      ..sort((a, b) {
        final byState = a.state.index.compareTo(b.state.index);
        if (byState != 0) return byState;
        final left = a.recordedAt;
        final right = b.recordedAt;
        if (left == null && right == null) return a.name.compareTo(b.name);
        if (left == null) return 1;
        if (right == null) return -1;
        return right.compareTo(left);
      });
    return ordered;
  }

  int get liveCount =>
      _staffLocations.where((row) => row.state == StaffState.moving).length;

  StaffLocation? get selectedStaff {
    if (_selectedStaffId == null) return null;
    for (final row in _staffLocations) {
      if (row.userId == _selectedStaffId) return row;
    }
    return null;
  }

  /// Everything currently plotted, so the map can fit its own bounds.
  List<LatLng> get plottedPositions => switch (_layer) {
    MapLayer.contacts =>
      contactPins
          .map((pin) => LatLng(pin.latitude, pin.longitude))
          .toList(growable: false),
    MapLayer.professionals =>
      professionalPins
          .where((item) => item.hasLocation)
          .map((item) => LatLng(item.lat!, item.lng!))
          .toList(growable: false),
    MapLayer.staff =>
      staffLocations.map((row) => row.position).toList(growable: false),
  };

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    await _fetchLayer();
  }

  Future<void> refresh() => _fetchLayer();

  Future<void> selectLayer(MapLayer layer) async {
    if (_layer == layer) return;
    if (layer == MapLayer.staff && !canViewStaff) return;
    _layer = layer;
    _selectedStaffId = null;
    _isLoading = true;
    notifyListeners();
    await _fetchLayer();
    _syncPolling();
  }

  Future<void> _fetchLayer() async {
    try {
      switch (_layer) {
        case MapLayer.contacts:
          _contactPins = await _contacts.mapPins(type: _contactTypeFilter);
        case MapLayer.professionals:
          _professionalPins = await _professionals.list();
        case MapLayer.staff:
          _staffLocations = await _locations.live();
      }
      _error = null;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setContactTypeFilter(ContactType? type) {
    _contactTypeFilter = type;
    notifyListeners();
    if (_layer == MapLayer.contacts) unawaited(_fetchLayer());
  }

  void setProfessionalTypeFilter(ProfessionalType? type) {
    _professionalTypeFilter = type;
    notifyListeners();
  }

  void setLiveOnly(bool value) {
    _liveOnly = value;
    notifyListeners();
  }

  void searchStaff(String value) {
    _staffQuery = value.trim();
    notifyListeners();
  }

  void selectStaff(int? userId) {
    _selectedStaffId = userId;
    notifyListeners();
  }

  // ------------------------------------------------------------------ polling

  /// The live layer refreshes every 20 seconds while it is on screen, and stops
  /// the moment the map is backgrounded or another layer is chosen.
  void resumePolling() {
    _syncPolling();
  }

  void pausePolling() {
    _livePoll?.cancel();
    _livePoll = null;
  }

  void _syncPolling() {
    pausePolling();
    if (_layer != MapLayer.staff || !canViewStaff) return;
    _livePoll = Timer.periodic(AppConfig.liveRefreshInterval, (_) async {
      try {
        _staffLocations = await _locations.live();
        notifyListeners();
      } on ApiException {
        // A dropped poll is not worth an error banner; the next tick retries.
      }
    });
  }

  @override
  void dispose() {
    pausePolling();
    super.dispose();
  }
}

/// Backs the staff route sheet: one staff member, one day, with the current
/// position refreshed while the sheet stays open.
class StaffRouteViewModel extends ChangeNotifier {
  StaffRouteViewModel({
    required LocationApiService locations,
    required this.staff,
  }) : _locations = locations,
       _date = todayIso(),
       _current = staff;

  final LocationApiService _locations;
  final StaffLocation staff;

  static const _currentRefresh = Duration(seconds: 30);

  StaffRoute? _route;
  StaffLocation _current;
  String _date;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  StaffRoute? get route => _route;
  StaffLocation get current => _current;
  String get date => _date;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isToday => _date == todayIso();

  String get currentAddress =>
      _current.address ?? 'Address unavailable';

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _route = await _locations.history(userId: staff.userId, date: _date);
      _error = null;
    } on ApiException catch (error) {
      _error = error.message;
      _route = StaffRoute.empty(staff.userId, _date);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    await _refreshCurrent();
    _startRefresh();
  }

  Future<void> selectDate(String date) async {
    if (_date == date) return;
    _date = date;
    await load();
  }

  void _startRefresh() {
    _refreshTimer?.cancel();
    if (!isToday) return;
    _refreshTimer = Timer.periodic(_currentRefresh, (_) => _refreshCurrent());
  }

  /// Keeps the "current location" block honest while the sheet is open: a new
  /// position, its age, and its address.
  Future<void> _refreshCurrent() async {
    try {
      final rows = await _locations.live();
      for (final row in rows) {
        if (row.userId != staff.userId) continue;
        _current = row;
        notifyListeners();
        return;
      }
    } on ApiException {
      // Leave the last known position on screen rather than blanking it.
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
