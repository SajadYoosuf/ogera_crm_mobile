import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../theme/ogera_colors.dart';
import 'contact.dart';
import 'lead_work.dart';

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
    this.missingFields = const [],
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

  /// Details the API still wants before this lead may leave the first stage
  /// (`district`, `house_stage`, `lead_source`, ...). Empty once verified.
  final List<String> missingFields;

  String get displayName => (name ?? '').trim().isEmpty ? phone : name!.trim();

  double? get lat => asDouble(latitude);
  double? get lng => asDouble(longitude);

  DateTime? get dueDate =>
      followupDueDate == null ? null : DateTime.tryParse(followupDueDate!);

  /// A lead only moves past the first stage once its required details are
  /// filled in; the API enforces the same rule with a 409 listing the gaps.
  static const qualificationFields = [
    'Name',
    'Phone',
    'District',
    'Address',
    'Lead source',
    'House stage',
  ];

  static const _fieldLabels = <String, String>{
    'name': 'Name',
    'phone': 'Phone',
    'district': 'District',
    'address': 'Address',
    'lead_source': 'Lead source',
    'house_stage': 'House stage',
    'work_area': 'Work area',
    'created_by': 'Added by',
  };

  /// Human labels for [missingFields].
  List<String> get missingQualification => [
    for (final field in missingFields)
      _fieldLabels[field] ?? humanizeSlug(field),
  ];

  bool get isQualified => missingFields.isEmpty;

  /// The same lead with a follow-up date taken from its open tasks.
  Lead withDueDate(String? dueDate) => Lead(
    id: id,
    phone: phone,
    createdAt: createdAt,
    name: name,
    address: address,
    district: district,
    panchayath: panchayath,
    ward: ward,
    houseStage: houseStage,
    currentTank: currentTank,
    waterSource: waterSource,
    tankSizeInterest: tankSizeInterest,
    remarks: remarks,
    latitude: latitude,
    longitude: longitude,
    stage: stage,
    followupAssignedTo: followupAssignedTo,
    followupAssignedUserId: followupAssignedUserId,
    followupDueDate: dueDate,
    missingFields: missingFields,
  );

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

  /// A lead is a consumer contact on the board: a `GET /contacts` row. Its
  /// follow-up date is not on the row; the service fills it in from `/tasks`.
  factory Lead.fromJson(Map<String, dynamic> json) {
    final contact = Contact.fromJson(json);
    return Lead(
      id: contact.id,
      phone: contact.phone,
      createdAt: contact.createdAt,
      name: contact.name,
      address: contact.address,
      district: contact.district,
      houseStage: contact.houseStage,
      // currentTankType lives on the consumer sub-profile, not on Contact directly.
      currentTank: contact.consumerProfile?.currentTankType,
      // latitude/longitude are double? on Contact but String? on Lead.
      latitude: contact.latitude?.toString(),
      longitude: contact.longitude?.toString(),
      // The pipeline stage slug lives on currentStage after the model refactor.
      stage: contact.currentStage?.stageSlug,
      // followupAssignedTo / followupAssignedUserId were removed from Contact;
      // follow-up assignment now lives on the Task model, not the contact row.
      // TODO(followup): populate from open tasks if needed.
      followupAssignedTo: null,
      followupAssignedUserId: null,
      missingFields: contact.missingFields,
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

/// Pipeline stages, from `GET /pipeline/stages`. The API fixes the list;
/// the app never hardcodes it.
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
      orderIndex: asInt(json['order_index'] ?? json['orderIndex']) ?? 0,
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
    this.isFollowup = false,
  });

  final int id;
  final String staffId;
  final String remark;
  final bool isSystem;
  final DateTime createdAt;
  final String? staffName;

  /// True for a scheduled follow-up row (an activity with a due date), so the
  /// contact screen can list follow-ups apart from the activity log.
  final bool isFollowup;

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

  /// One row of `GET /contacts/{id}/history`, read through [LeadHistoryEntry].
  ///
  /// - A logged activity is a note the employee wrote, so its text is the notes.
  /// - A follow-up (scheduled or rescheduled) is a follow-up line with its due day.
  /// - Stage moves, owner changes and field edits are system lines.
  ///
  /// [id] is the row's position in the list. History rows have no shared id.
  factory Remark.fromHistory(LeadHistoryEntry entry, int id) {
    final isNote = entry.eventType == 'activity';
    final isFollowup =
        entry.eventType == 'followup' ||
        entry.eventType == 'followup_rescheduled';
    final due = entry.dueAt;
    final text = isNote
        ? (entry.notes ?? entry.summary)
        : [
            entry.summary,
            if (due != null) 'due ${formatDayMonth(due)}',
          ].join(' · ');
    return Remark(
      id: id,
      staffId: entry.actorId?.toString() ?? '',
      remark: text,
      isSystem: !isNote,
      createdAt: entry.timestamp,
      staffName: entry.actorName,
      isFollowup: isFollowup,
    );
  }
}

/// A selectable staff member, from `GET /employees/directory`.
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
