import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';

/// One staff member's leads and awareness records added in the report range.
class StaffPerformance {
  const StaffPerformance({
    required this.id,
    required this.name,
    required this.leads,
    required this.awareness,
  });

  factory StaffPerformance.fromJson(Map<String, dynamic> json) {
    return StaffPerformance(
      id: asInt(json['id']) ?? 0,
      name: asText(json['name']) ?? 'Ogera user',
      leads: asInt(json['leads']) ?? 0,
      awareness: asInt(json['awareness']) ?? 0,
    );
  }

  final int id;
  final String name;
  final int leads;
  final int awareness;

  int get total => leads + awareness;
}

class PerformanceReport {
  const PerformanceReport({
    required this.leads,
    required this.awareness,
    required this.staff,
    required this.isTeam,
    required this.unattributedLeads,
    required this.unattributedAwareness,
  });

  factory PerformanceReport.fromJson(dynamic data) {
    final json = asMap(data);
    final totals = asMap(json['totals']);
    final orphans = asMap(json['unattributed']);
    return PerformanceReport(
      leads: asInt(totals['leads']) ?? 0,
      awareness: asInt(totals['awareness']) ?? 0,
      staff: asList(
        json['staff'],
      ).map(StaffPerformance.fromJson).toList(growable: false),
      isTeam: json['scope'] != 'self',
      unattributedLeads: asInt(orphans['leads']) ?? 0,
      unattributedAwareness: asInt(orphans['awareness']) ?? 0,
    );
  }

  final int leads;
  final int awareness;
  final List<StaffPerformance> staff;

  /// False when the server pinned the report to the signed-in staff member.
  final bool isTeam;

  /// Older records with no creator; only reported to heads.
  final int unattributedLeads;
  final int unattributedAwareness;

  int get unattributed => unattributedLeads + unattributedAwareness;
}
