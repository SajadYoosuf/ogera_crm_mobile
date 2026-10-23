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

import '../models/attendance.dart';
import '../services/home_service.dart';
import '../services/location_streaming_service.dart';

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

  bool get isLoading => _isLoading;
  bool get isCheckinLoading => _isCheckinLoading;
  String? get error => _error;
  String? get actionError => _actionError;
  KpiRange get range => _range;
  bool get isCheckedIn => _attendance?.isOpen == true;
  AttendanceRecord? get attendance => _attendance;

  /// The KPIs for the currently selected range (empty if not yet loaded).
  DashboardKpis get kpis => _kpis[_range] ?? DashboardKpis.empty();

  /// Loads all three KPI ranges and today's attendance in parallel.
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
  }

  /// Switches the visible KPI range; no network call.
  void setRange(KpiRange range) {
    if (_range == range) return;
    _range = range;
    notifyListeners();
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
