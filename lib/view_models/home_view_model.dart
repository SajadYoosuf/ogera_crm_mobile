/// HomeViewModel manages the data the Home tab needs.
///
/// It holds KPIs for three time ranges (today, 7d, month) and the
/// attendance check-in state. The screen calls [load] once on mount;
/// after that it switches range client-side with [setRange] — no extra
/// network calls needed.
///
/// Two kinds of error are kept apart so each shows in the right place:
///   [error]       — loading the KPIs or today's attendance failed
///   [actionError] — a check-in or check-out request failed
///
/// State flow:
///   isLoading=true  →  load() fires  →  isLoading=false, kpis filled
///   checkin() / checkout()  →  _attendance updated  →  notifyListeners()
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/formatters.dart';
import '../models/attendance.dart';
import '../models/followup.dart';
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

class HomeViewModel extends ChangeNotifier {
  HomeViewModel(this._service)
      : _location = LocationStreamingService(_service);

  final HomeService _service;
  final LocationStreamingService _location;

  bool _isLoading = false;
  bool _isCheckinLoading = false;
  String? _error;
  String? _actionError;

  AttendanceRecord? _attendance;
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

  // ── Home Tasks ────────────────────────────────────────────────────────────
  List<Task> _homeTasks = [];
  KpiRange _homeTasksRange = KpiRange.today;
  bool _isHomeTasksLoading = false;
  String? _homeTasksError;

  List<Task> get homeTasks => _homeTasks;
  KpiRange get homeTasksRange => _homeTasksRange;
  bool get isHomeTasksLoading => _isHomeTasksLoading;
  String? get homeTasksError => _homeTasksError;

  bool get isLoading => _isLoading;
  bool get isCheckinLoading => _isCheckinLoading;
  String? get error => _error;
  String? get actionError => _actionError;
  KpiRange get range => _range;
  bool get isCheckedIn => _attendance?.isOpen == true;
  AttendanceRecord? get attendance => _attendance;

  /// The KPIs for the currently selected range (empty if not yet loaded).
  DashboardKpis get kpis => _kpis[_range] ?? DashboardKpis.empty();

  /// Loads all three KPI ranges, today's attendance, recent leads, and
  /// today's tasks in parallel.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.summary(KpiRange.today.apiValue),
        _service.summary(KpiRange.week.apiValue),
        _service.summary(KpiRange.month.apiValue),
        _service.getToday(),
      ]);
      _kpis[KpiRange.today] = results[0] as DashboardKpis;
      _kpis[KpiRange.week] = results[1] as DashboardKpis;
      _kpis[KpiRange.month] = results[2] as DashboardKpis;
      _attendance = results[3] as AttendanceRecord?;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Load recent leads and tasks independently so a KPI failure does not
    // prevent the sections from rendering.
    await Future.wait([
      _loadRecentLeads(_recentLeadsRange),
      _loadHomeTasks(_homeTasksRange),
    ]);
  }

  /// Switches the visible KPI range; no network call.
  void setRange(KpiRange range) {
    if (_range == range) return;
    _range = range;
    notifyListeners();
  }

  // ── Recent Leads ──────────────────────────────────────────────────────────

  /// Switches the recent-leads time window and reloads from the server.
  Future<void> setRecentLeadsRange(KpiRange range) async {
    if (_recentLeadsRange == range) return;
    _recentLeadsRange = range;
    await _loadRecentLeads(range);
  }

  Future<void> _loadRecentLeads(KpiRange range) async {
    _isRecentLeadsLoading = true;
    _recentLeadsError = null;
    notifyListeners();
    try {
      _recentLeads = await _service.fetchRecentLeads(
        startDate: _rangeStartDate(range),
      );
    } catch (e) {
      _recentLeadsError = e.toString();
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

  Future<void> _loadHomeTasks(KpiRange range) async {
    _isHomeTasksLoading = true;
    _homeTasksError = null;
    notifyListeners();
    try {
      final from = _rangeStartDate(range);
      final to = isoDate(DateTime.now());
      _homeTasks = await _service.fetchHomeTasks(dateFrom: from, dateTo: to);
    } catch (e) {
      _homeTasksError = e.toString();
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

  /// Checks the employee in. [lat] and [lng] are optional GPS coords.
  Future<void> checkin({double? lat, double? lng}) async {
    _isCheckinLoading = true;
    _actionError = null;
    notifyListeners();
    try {
      _attendance = await _service.checkin(lat: lat, lng: lng);
      // Start background location pings once checked in.
      unawaited(_location.start());
    } catch (e) {
      _actionError = e.toString();
    } finally {
      _isCheckinLoading = false;
      notifyListeners();
    }
  }

  /// Checks the employee out of the current session.
  Future<void> checkout() async {
    _isCheckinLoading = true;
    _actionError = null;
    notifyListeners();
    try {
      _attendance = await _service.checkout();
      // Stop background location pings on checkout.
      unawaited(_location.stop());
    } catch (e) {
      _actionError = e.toString();
    } finally {
      _isCheckinLoading = false;
      notifyListeners();
    }
  }
}
