import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../theme/ogera_colors.dart';

/// A lead on the follow-up board. It is a `contacts` row with a stage, which is
/// why it carries the qualification fields the pipeline gates on.
class Lead {
  const Lead({
    required this.id,
    required this.phone,
    required this.createdAt,
    this.name,
    this.address,
    this.district,
    this.panchayath,
    this.ward,
    this.houseStage,
    this.currentTank,
    this.waterSource,
    this.tankSizeInterest,
    this.remarks,
    this.latitude,
    this.longitude,
    this.stage,
    this.followupAssignedTo,
    this.followupAssignedUserId,
    this.followupDueDate,
  });

  final int id;
  final String phone;
  final DateTime createdAt;
  final String? name;
  final String? address;
  final String? district;
  final String? panchayath;
  final String? ward;
  final String? houseStage;
  final String? currentTank;
  final String? waterSource;
  final String? tankSizeInterest;
  final String? remarks;
  final String? latitude;
  final String? longitude;
  final String? stage;
  final String? followupAssignedTo;
  final int? followupAssignedUserId;
  final String? followupDueDate;

  String get displayName => (name ?? '').trim().isEmpty ? phone : name!.trim();

  double? get lat => asDouble(latitude);
  double? get lng => asDouble(longitude);

  DateTime? get dueDate =>
      followupDueDate == null ? null : DateTime.tryParse(followupDueDate!);

  /// A lead only moves past the first stage once these five details are filled
  /// in — the same rule the web board enforces.
  static const qualificationFields = [
    'Panchayath',
    'Ward',
    'Water source',
    'House stage',
    'Tank size interest',
  ];

  List<String> get missingQualification {
    final missing = <String>[];
    if ((panchayath ?? '').isEmpty) missing.add('Panchayath');
    if ((ward ?? '').isEmpty) missing.add('Ward');
    if ((waterSource ?? '').isEmpty) missing.add('Water source');
    if ((houseStage ?? '').isEmpty) missing.add('House stage');
    if ((tankSizeInterest ?? '').isEmpty) missing.add('Tank size interest');
    return missing;
  }

  bool get isQualified => missingQualification.isEmpty;

  DueBucket get dueBucket {
    final due = dueDate;
    if (due == null) return DueBucket.noDate;
    final today = DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final dueMidnight = DateTime(due.year, due.month, due.day);
    if (dueMidnight.isBefore(midnight)) return DueBucket.overdue;
    if (dueMidnight == midnight) return DueBucket.today;
    return DueBucket.upcoming;
  }

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: asInt(json['id']) ?? 0,
      phone: asText(json['phone']) ?? '',
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      name: asText(json['name']),
      address: asText(json['address']),
      district: asText(json['district']),
      panchayath: asText(json['panchayath']),
      ward: asText(json['ward']),
      houseStage: asText(json['houseStage']),
      currentTank: asText(json['currentTank']),
      waterSource: asText(json['waterSource']),
      tankSizeInterest: asText(json['tankSizeInterest']),
      remarks: asText(json['remarks']),
      latitude: asText(json['latitude']),
      longitude: asText(json['longitude']),
      stage: asText(json['stage']),
      followupAssignedTo: asText(json['followupAssignedTo']),
      followupAssignedUserId: asInt(json['followupAssignedUserId']),
      followupDueDate: asText(json['followupDueDate'])?.substring(0, 10),
    );
  }
}

enum DueBucket {
  overdue('Overdue', OgeraColors.danger, Icons.error_outline_rounded),
  today('Due today', OgeraColors.warning, Icons.today_rounded),
  upcoming('Upcoming', OgeraColors.info, Icons.event_rounded),
  noDate('No due date', OgeraColors.muted, Icons.event_busy_rounded);

  const DueBucket(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

/// Stages come from the `pipeline_stages` table; the app never hardcodes them.
class Stage {
  const Stage({
    required this.id,
    required this.label,
    required this.orderIndex,
  });

  final String id;
  final String label;
  final int orderIndex;

  factory Stage.fromJson(Map<String, dynamic> json) {
    return Stage(
      id: asText(json['id']) ?? '',
      label: asText(json['label']) ?? humanizeSlug(asText(json['id']) ?? ''),
      orderIndex: asInt(json['orderIndex']) ?? 0,
    );
  }

  /// A deterministic accent so each column and card reads consistently. Won and
  /// lost stages get semantic colours; the rest walk a neutral ramp.
  Color get color {
    final key = id.toLowerCase();
    if (key.contains('won') || key.contains('closed')) {
      return OgeraColors.success;
    }
    if (key.contains('lost')) return OgeraColors.danger;
    if (key.contains('not_interested') || key.contains('not-interested')) {
      return const Color(0xFF9CA3AF);
    }
    const ramp = [
      OgeraColors.blue,
      Color(0xFF6366F1),
      Color(0xFF0891B2),
      Color(0xFFD97706),
      Color(0xFF7C3AED),
    ];
    return ramp[orderIndex.abs() % ramp.length];
  }
}

/// One entry on the immutable lead history. `isSystem` rows are generated by
/// the API for stage, assignment, and due-date changes; the rest are notes.
class Remark {
  const Remark({
    required this.id,
    required this.staffId,
    required this.remark,
    required this.isSystem,
    required this.createdAt,
    this.staffName,
  });

  final int id;
  final String staffId;
  final String remark;
  final bool isSystem;
  final DateTime createdAt;
  final String? staffName;

  String get author =>
      (staffName ?? '').trim().isEmpty ? 'System' : staffName!.trim();

  factory Remark.fromJson(Map<String, dynamic> json) {
    return Remark(
      id: asInt(json['id']) ?? 0,
      staffId: asText(json['staffId']) ?? '',
      remark: asText(json['remark']) ?? '',
      isSystem: json['isSystem'] == true,
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      staffName: asText(json['staffName']),
    );
  }
}

/// A selectable staff member, from `/api/staff`.
class StaffMember {
  const StaffMember({required this.id, required this.name});

  final String id;
  final String name;

  int get numericId => int.tryParse(id) ?? id.hashCode;

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: asText(json['id']) ?? '',
      name: asText(json['name']) ?? 'Unnamed',
    );
  }
}
