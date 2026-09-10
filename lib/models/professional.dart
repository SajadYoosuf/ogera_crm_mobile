import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';

/// The professions the CRM tracks. These ids must match the `professionals.type`
/// enum in the database exactly — an id the server does not know is rejected
/// with a 400 rather than silently coerced.
enum ProfessionalType {
  contractor('Contractor', Icons.engineering_rounded, Color(0xFFEA580C)),
  engineer('Engineer', Icons.architecture_rounded, Color(0xFF2563EB)),
  plumber('Plumber', Icons.plumbing_rounded, Color(0xFF0891B2)),
  interiorDesigner('Interior Designer', Icons.chair_rounded, Color(0xFF9333EA)),
  electrician(
    'Electrician',
    Icons.electrical_services_rounded,
    Color(0xFFCA8A04),
  ),
  other('Other', Icons.handyman_rounded, Color(0xFF64748B));

  const ProfessionalType(this.id, this.icon, this.color);

  final String id;
  final IconData icon;
  final Color color;

  String get label => id;

  /// Falls back to [other] rather than a real profession, so an unexpected
  /// value is never mislabelled as an engineer.
  static ProfessionalType fromId(String? value) {
    return ProfessionalType.values.firstWhere(
      (type) => type.id.toLowerCase() == (value ?? '').toLowerCase(),
      orElse: () => ProfessionalType.other,
    );
  }
}

class Professional {
  const Professional({
    required this.id,
    required this.phone,
    required this.type,
    required this.createdAt,
    this.name,
    this.place,
    this.address,
    this.district,
    this.panchayath,
    this.latitude,
    this.longitude,
    this.createdByUserId,
    this.updatedAt,
  });

  final int id;
  final String phone;
  final ProfessionalType type;
  final DateTime createdAt;
  final String? name;
  final String? place;
  final String? address;
  final String? district;
  final String? panchayath;
  final String? latitude;
  final String? longitude;
  final int? createdByUserId;
  final DateTime? updatedAt;

  String get displayName => (name ?? '').trim().isEmpty ? phone : name!.trim();

  double? get lat => asDouble(latitude);
  double? get lng => asDouble(longitude);
  bool get hasLocation => lat != null && lng != null;

  /// Place, panchayath, district — whichever are present, in that order.
  String? get locationSummary {
    final parts = [place, panchayath, district]
        .map((part) => (part ?? '').trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory Professional.fromJson(Map<String, dynamic> json) {
    return Professional(
      id: asInt(json['id']) ?? 0,
      phone: asText(json['phone']) ?? '',
      type: ProfessionalType.fromId(asText(json['type'])),
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      name: asText(json['name']),
      place: asText(json['place']),
      address: asText(json['address']),
      district: asText(json['district']),
      panchayath: asText(json['panchayath']),
      latitude: asText(json['latitude']),
      longitude: asText(json['longitude']),
      createdByUserId: asInt(json['createdByUserId']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  bool isEditableBy({required int userId, required bool isPrivileged}) {
    if (isPrivileged) return true;
    return createdByUserId != null && createdByUserId == userId;
  }
}

class ProfessionalDraft {
  ProfessionalDraft({
    this.name,
    required this.phone,
    this.type = ProfessionalType.engineer,
    this.place,
    this.address,
    this.district,
    this.panchayath,
    this.latitude,
    this.longitude,
  });

  String? name;
  String phone;
  ProfessionalType type;
  String? place;
  String? address;
  String? district;
  String? panchayath;
  String? latitude;
  String? longitude;

  factory ProfessionalDraft.fromProfessional(Professional professional) {
    return ProfessionalDraft(
      name: professional.name,
      phone: professional.phone,
      type: professional.type,
      place: professional.place,
      address: professional.address,
      district: professional.district,
      panchayath: professional.panchayath,
      latitude: professional.latitude,
      longitude: professional.longitude,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'phone': phone.trim(), 'type': type.id};
    void put(String key, String? value) {
      if (value == null || value.trim().isEmpty) return;
      json[key] = value.trim();
    }

    put('name', name);
    put('place', place);
    put('address', address);
    put('district', district);
    put('panchayath', panchayath);
    put('latitude', latitude);
    put('longitude', longitude);
    return json;
  }
}
