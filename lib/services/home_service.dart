/// Home screen data service.
///
/// Wraps two backend endpoints:
///   GET /dashboard/summary  — KPIs, contacts count, follow-up counts
///   GET /attendance/today   — today's check-in / check-out record
///   POST /attendance/checkin
///   POST /attendance/checkout
///
/// The dashboard summary can be fetched for different time ranges
/// (today, 7d, month). The home screen fetches all three ranges once
/// and switches between them client-side without extra network calls.
library;

import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';
import '../models/attendance.dart';

/// Holds the numeric KPIs the home screen shows.
class DashboardKpis {
  const DashboardKpis({
    required this.totalContacts,
    required this.newLeads,
    required this.openFollowups,
    required this.overdueFollowups,
    required this.won,
  });

  final int totalContacts;
  final int newLeads;
  final int openFollowups;
  final int overdueFollowups;
  final int won;

  factory DashboardKpis.empty() => const DashboardKpis(
    totalContacts: 0,
    newLeads: 0,
    openFollowups: 0,
    overdueFollowups: 0,
    won: 0,
  );

  factory DashboardKpis.fromJson(Map<String, dynamic> json) {
    final kpis = asMap(json['kpis']);
    final newLeads = asMap(kpis['new_leads']);
    final openFollowups = asMap(kpis['open_followups']);
    final won = asMap(kpis['won']);
    return DashboardKpis(
      totalContacts: asInt(kpis['total_contacts']) ?? 0,
      newLeads: asInt(newLeads['value']) ?? 0,
      openFollowups: asInt(openFollowups['value']) ?? 0,
      overdueFollowups: asInt(openFollowups['overdue']) ?? 0,
      won: asInt(won['value']) ?? 0,
    );
  }
}

class HomeService {
  HomeService(this._api);

  final ApiClient _api;

  /// Fetches dashboard KPIs for one time range.
  /// [range] is 'today', '7d', or 'month'.
  Future<DashboardKpis> summary(String range) async {
    final data = asMap(await _api.get('/dashboard/summary', query: {'range': range}));
    return DashboardKpis.fromJson(data);
  }

  /// Returns today's attendance record, or null when not checked in yet.
  Future<AttendanceRecord?> getToday() async {
    final data = await _api.get('/attendance/today');
    if (data == null) return null;
    return AttendanceRecord.fromJson(asMap(data));
  }

  /// Starts a field session. [lat] and [lng] are optional GPS coordinates.
  Future<AttendanceRecord> checkin({double? lat, double? lng}) async {
    final data = asMap(
      await _api.post('/attendance/checkin', body: {
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
      }),
    );
    return AttendanceRecord.fromJson(data);
  }

  /// Ends the current field session.
  Future<AttendanceRecord> checkout() async {
    final data = asMap(await _api.post('/attendance/checkout'));
    return AttendanceRecord.fromJson(data);
  }

  /// Sends a single GPS ping to the server (background streaming).
  Future<void> sendLocationPing(double lat, double lng) async {
    await _api.post('/staff/location', body: {'latitude': lat, 'longitude': lng});
  }
}
