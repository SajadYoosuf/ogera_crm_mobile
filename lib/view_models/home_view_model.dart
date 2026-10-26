/// HomeViewModel manages the data the Home tab needs.
///
/// It holds KPIs for three time ranges (today, 7d, month), today's field
/// check-in state, and the employee's current location label. The screen calls
/// [load] once on mount; after that it switches range client-side with
/// [setRange] — no extra network calls needed.
///
/// Two kinds of error are kept apart so each shows in the right place:
///   [error]       — loading the KPIs failed
///   [actionError] — a check-in or check-out request failed
///
/// Check-in rules (they mirror the backend):
///   - one field session per employee per day
///   - once checked out, the day is finished: no second check-in
///
/// State flow:
///   load()          →  KPIs, attendance, leads and tasks load independently
///   checkin()       →  GPS read, POST /attendance/checkin, tracking starts,
///                      location label loads
///   checkout()      →  POST /attendance/checkout, tracking stops
///   refreshLocation()  →  reads GET /staff/location/me and shortens the address
///
/// A 409 from check-in or check-out means the server already has today's
/// record, so the view model re-reads it instead of leaving a stale button.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';
import '../models/attendance.dart';
import '../models/followup.dart';
import '../services/geocoding_service.dart';
import '../services/home_service.dart';
import '../services/location_streaming_service.dart';
import '../services/tasks_service.dart';

/// Which time window the KPI row shows.
enum KpiRange { today, week, month }

extension KpiRangeX on KpiRange {
  String get apiValue => switch (this) {
    KpiRange.today => 'today',
    KpiRange.week => '7d',
    KpiRange.month => 'month',
  };

  String get label => switch (this) {
    KpiRange.today => 'Today',
    KpiRange.week => 'This Week',
    KpiRange.month => 'This Month',
  };
}

/// Where the employee is in today's field day. The check-in card shows one
/// layout per status.
enum FieldDayStatus {
  /// Today's attendance has not come back from the server yet.
  loading,

  /// Today's attendance could not be loaded.
  error,

  /// No check-in today yet.
  notStarted,

  /// Checked in and the session is still open.
  onField,

  /// Checked out: today's field visit is done.
  completed,
}

class HomeViewModel extends ChangeNotifier {
  /// [location] and [geocoder] default to the real services. Tests pass fakes
  /// so they never start GPS timers or call the map service.
  HomeViewModel(
    this._service, {
    LocationStreamingService? location,
    GeocodingService? geocoder,
  }) : _location = location ?? LocationStreamingService(_service),
       _geocoder = geocoder ?? GeocodingService() {
    _location.onStatusChanged = notifyListeners;
  }

  final HomeService _service;
  final LocationStreamingService _location;
  final GeocodingService _geocoder;

  bool _isLoading = false;
  bool _isCheckinLoading = false;
  String? _error;
  FailureKind? _errorKind;
  String? _actionError;
  FailureKind? _recentLeadsErrorKind;
  FailureKind? _homeTasksErrorKind;

  AttendanceRecord? _attendance;
  bool _attendanceLoaded = false;
  String? _attendanceError;

  String? _locationLabel;
  bool _isLocationLoading = false;
  bool _locationFailed = false;

  final Map<KpiRange, DashboardKpis> _kpis = {};
  KpiRange _range = KpiRange.today;

  // ── Recent Leads ──────────────────────────────────────────────────────────
  List<Lead> _recentLeads = [];
  KpiRange _recentLeadsRange = KpiRange.today;
  bool _isRecentLeadsLoading = false;
  String? _recentLeadsError;

  List<Lead> get recentLeads => _recentLeads;
  KpiRange get recentLeadsRange => _recentLeadsRange;
  bool get isRecentLeadsLoading => _isRecentLeadsLoading;
  String? get recentLeadsError => _recentLeadsError;
  FailureKind? get recentLeadsErrorKind => _recentLeadsErrorKind;

  // ── Home Tasks ────────────────────────────────────────────────────────────
  List<Task> _homeTasks = [];
  KpiRange _homeTasksRange = KpiRange.today;
  bool _isHomeTasksLoading = false;
  String? _homeTasksError;

  List<Task> get homeTasks => _homeTasks;
  KpiRange get homeTasksRange => _homeTasksRange;
  bool get isHomeTasksLoading => _isHomeTasksLoading;
  String? get homeTasksError => _homeTasksError;
  FailureKind? get homeTasksErrorKind => _homeTasksErrorKind;

  bool get isLoading => _isLoading;
  bool get isCheckinLoading => _isCheckinLoading;
  String? get error => _error;
  FailureKind? get errorKind => _errorKind;
  String? get actionError => _actionError;
  KpiRange get range => _range;
  AttendanceRecord? get attendance => _attendance;
  String? get attendanceError => _attendanceError;
  bool get isCheckedIn => _attendance?.isOpen == true;

  /// The check-in card's layout is picked from this one value.
  FieldDayStatus get fieldDayStatus {
    if (_attendanceError != null) return FieldDayStatus.error;
    if (!_attendanceLoaded) return FieldDayStatus.loading;
    final record = _attendance;
    if (record == null) return FieldDayStatus.notStarted;
    return record.isOpen ? FieldDayStatus.onField : FieldDayStatus.completed;
  }

  /// Short address of the employee's last reported position, e.g. "MG Road".
  /// Null until a location has been read.
  String? get locationLabel => _locationLabel;
  bool get isLocationLoading => _isLocationLoading;
  bool get locationFailed => _locationFailed;
  int get pendingLocationCount => _location.pendingCount;
  bool get isLocationSyncing => _location.isSyncing;

  /// The KPIs for the currently selected range (empty if not yet loaded).
  DashboardKpis get kpis => _kpis[_range] ?? DashboardKpis.empty();

  /// Loads all three KPI ranges, today's attendance, recent leads, and
  /// today's tasks.
  Future<void> load() async {
    // Set ALL loading flags before the first notifyListeners so the whole
    // Home tab gets one rebuild into "loading" state instead of 4 rapid ones.
    _isLoading = true;
    _error = null;
    _errorKind = null;
    _isRecentLeadsLoading = true;
    _recentLeadsError = null;
    _recentLeadsErrorKind = null;
    _isHomeTasksLoading = true;
    _homeTasksError = null;
    _homeTasksErrorKind = null;
    notifyListeners(); // single "everything is loading" rebuild

    try {
      final results = await Future.wait([
        _service.summary(KpiRange.today.apiValue),
        _service.summary(KpiRange.week.apiValue),
        _service.summary(KpiRange.month.apiValue),
      ]);
      _kpis[KpiRange.today] = results[0];
      _kpis[KpiRange.week] = results[1];
      _kpis[KpiRange.month] = results[2];
    } catch (e) {
      final failure = describeFailure(e);
      _error = failure.message;
      _errorKind = failure.kind;
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Each block loads on its own, so a failing KPI call cannot hide the rest.
    // Attendance must not ride on the KPI calls: if it stays unknown, the card
    // offers "Check in" to someone who already checked in today.
    // Pass silent:true so the sub-loaders skip their own "loading=true +
    // notifyListeners" — we already set those flags above.
    await Future.wait([
      refreshAttendance(),
      _loadRecentLeads(_recentLeadsRange, silent: true),
      _loadHomeTasks(_homeTasksRange, silent: true),
    ]);
  }

  /// Switches the visible KPI range; no network call.
  void setRange(KpiRange range) {
    if (_range == range) return;
    _range = range;
    notifyListeners();
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  /// Reloads today's check-in record. Also used by the card's retry and after
  /// a 409, so the card always shows what the server has.
  Future<void> refreshAttendance() async {
    try {
      _attendance = await _service.getToday();
      _attendanceError = null;
    } catch (e) {
      _attendanceError = describeFailure(e).message;
    } finally {
      _attendanceLoaded = true;
      notifyListeners();
    }
    // An open session found on load (e.g. the app was restarted in the field)
    // gets its tracking and location label back.
    if (isCheckedIn) await _startFieldSession();
  }

  /// Starts today's field session. The phone's GPS fix is sent with it when
  /// one is available; check-in still goes through without it.
  Future<void> checkin() async {
    _isCheckinLoading = true;
    _actionError = null;
    notifyListeners();
    try {
      final position = await _location.currentPosition();
      _attendance = await _service.checkin(
        lat: position?.latitude,
        lng: position?.longitude,
      );
      _attendanceLoaded = true;
      _attendanceError = null;
      await _startFieldSession();
    } catch (e) {
      await _handleActionError(e);
    } finally {
      _isCheckinLoading = false;
      notifyListeners();
    }
  }

  /// Ends the current field session.
  Future<void> checkout() async {
    _isCheckinLoading = true;
    _actionError = null;
    notifyListeners();
    try {
      _attendance = await _service.checkout();
      _attendanceLoaded = true;
      _attendanceError = null;
      await _stopFieldSession();
    } catch (e) {
      await _handleActionError(e);
    } finally {
      _isCheckinLoading = false;
      notifyListeners();
    }
  }

  /// Shows the server's own words for a failed check-in or check-out. A 404
  /// or 409 means the server state differs from what the app shows, so the
  /// app re-reads today's record.
  Future<void> _handleActionError(Object error) async {
    _actionError = describeFailure(error).message;
    final status = error is ApiException ? error.statusCode : null;
    if (status == 404 || status == 409) {
      await refreshAttendance();
    }
  }

  /// Starts background pings and reads the server's last point for the card.
  Future<void> _startFieldSession() async {
    try {
      await _location.start();
    } catch (_) {
      // Tracking is best effort; the card still works without it.
    }
    await refreshLocation();
  }

  Future<void> _stopFieldSession() async {
    try {
      await _location.stop();
    } catch (_) {
      // Nothing to undo if tracking never started.
    }
  }

  // ── Location ──────────────────────────────────────────────────────────────

  /// Reads the employee's last stored GPS point from the server and turns it
  /// into a short address. Used after check-in and by the card's refresh
  /// button. Nothing is sent from the phone here: the server's stored point is
  /// the source of truth.
  Future<void> refreshLocation() async {
    if (_isLocationLoading) return;
    _isLocationLoading = true;
    _locationFailed = false;
    notifyListeners();
    try {
      final last = await _service.getLastLocation();
      if (last == null) {
        _locationLabel = null;
      } else {
        final point = LatLng(last.latitude, last.longitude);
        // Falls back to coordinates when the map service cannot answer.
        final address =
            await _geocoder.resolve(point) ??
            GeocodingService.coordinateLabel(point);
        final label = firstWords(address);
        _locationLabel = label.isEmpty ? null : label;
      }
    } catch (_) {
      _locationFailed = true;
    } finally {
      _isLocationLoading = false;
      notifyListeners();
    }
  }

  // ── Recent Leads ──────────────────────────────────────────────────────────

  /// Switches the recent-leads time window and reloads from the server.
  Future<void> setRecentLeadsRange(KpiRange range) async {
    if (_recentLeadsRange == range) return;
    _recentLeadsRange = range;
    await _loadRecentLeads(range);
  }

  // [silent] skips the "loading=true + notifyListeners" at the top because
  // load() already set those flags and fired one batched notifyListeners.
  Future<void> _loadRecentLeads(KpiRange range, {bool silent = false}) async {
    if (!silent) {
      _isRecentLeadsLoading = true;
      _recentLeadsError = null;
      _recentLeadsErrorKind = null;
      notifyListeners();
    }
    try {
      _recentLeads = await _service.fetchRecentLeads(
        startDate: _rangeStartDate(range),
      );
    } catch (e) {
      final failure = describeFailure(e);
      _recentLeadsError = failure.message;
      _recentLeadsErrorKind = failure.kind;
    } finally {
      _isRecentLeadsLoading = false;
      notifyListeners();
    }
  }

  // ── Home Tasks ────────────────────────────────────────────────────────────

  /// Switches the home-tasks time window and reloads from the server.
  Future<void> setHomeTasksRange(KpiRange range) async {
    if (_homeTasksRange == range) return;
    _homeTasksRange = range;
    await _loadHomeTasks(range);
  }

  /// Reloads the home task list for the current range. Used after a task is
  /// completed or changed from the home list.
  Future<void> refreshHomeTasks() => _loadHomeTasks(_homeTasksRange);

  // [silent] skips the "loading=true + notifyListeners" at the top because
  // load() already set those flags and fired one batched notifyListeners.
  Future<void> _loadHomeTasks(KpiRange range, {bool silent = false}) async {
    if (!silent) {
      _isHomeTasksLoading = true;
      _homeTasksError = null;
      _homeTasksErrorKind = null;
      notifyListeners();
    }
    try {
      final from = _rangeStartDate(range);
      final to = isoDate(DateTime.now());
      _homeTasks = await _service.fetchHomeTasks(dateFrom: from, dateTo: to);
    } catch (e) {
      final failure = describeFailure(e);
      _homeTasksError = failure.message;
      _homeTasksErrorKind = failure.kind;
    } finally {
      _isHomeTasksLoading = false;
      notifyListeners();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns an ISO date string for the start of the period denoted by
  /// [range] (today's date for Today, 7 days ago for Week, 30 days ago for
  /// Month). The API filters with `created_from >= startDate`.
  String _rangeStartDate(KpiRange range) {
    final now = DateTime.now();
    final start = switch (range) {
      KpiRange.today => DateTime(now.year, now.month, now.day),
      KpiRange.week => now.subtract(const Duration(days: 6)),
      KpiRange.month => now.subtract(const Duration(days: 29)),
    };
    return isoDate(start);
  }
}
