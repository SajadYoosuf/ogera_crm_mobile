import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';

/// The professions the CRM tracks. Each maps to the API's partner
/// `profession_type` value; one the app does not know falls back to [other].
enum ProfessionalType {
  contractor(
    'Contractor',
    'contractor',
    Icons.engineering_rounded,
    Color(0xFFEA580C),
  ),
  engineer(
    'Engineer',
    'engineer',
    Icons.architecture_rounded,
    Color(0xFF2563EB),
  ),
  architect(
    'Architect',
    'architect',
    Icons.foundation_rounded,
    Color(0xFF0D9488),
  ),
  plumber('Plumber', 'plumber', Icons.plumbing_rounded, Color(0xFF0891B2)),
  interiorDesigner(
    'Interior Designer',
    'interior_designer',
    Icons.chair_rounded,
    Color(0xFF9333EA),
  ),
  electrician(
    'Electrician',
    'electrician',
    Icons.electrical_services_rounded,
    Color(0xFFCA8A04),
  ),
  other('Other', 'other', Icons.handyman_rounded, Color(0xFF64748B));

  const ProfessionalType(this.id, this.apiValue, this.icon, this.color);

  /// The display name, also what the screens and referral snapshots carry.
  final String id;

  /// The `profession_type` the API stores.
  final String apiValue;
  final IconData icon;
  final Color color;

  String get label => id;

  /// Accepts either the display name or the API value, case-insensitively.
  /// Falls back to [other] rather than a real profession, so an unexpected
  /// value is never mislabelled as an engineer.
  static ProfessionalType fromId(String? value) {
    final key = (value ?? '').trim().toLowerCase().replaceAll(' ', '_');
    return ProfessionalType.values.firstWhere(
      (type) =>
          type.apiValue == key ||
          type.id.toLowerCase().replaceAll(' ', '_') == key,
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

  /// A partner contact: a `GET /contacts` row (or detail) with
  /// `contact_type = partner`. The partner's work area is the "place".
  factory Professional.fromJson(Map<String, dynamic> json) {
    final profile = json['partner_profile'] is Map<String, dynamic>
        ? json['partner_profile'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final creator = json['created_by'];
    return Professional(
      id: asInt(json['id']) ?? 0,
      phone: asText(json['phone']) ?? '',
      type: ProfessionalType.fromId(
        asText(json['profession_type'] ?? profile['profession_type']),
      ),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      name: asText(json['name']),
      place: asText(json['work_area'] ?? profile['work_area']),
      address: asText(json['address']),
      district: asText(json['district']),
      latitude: asText(json['latitude']),
      longitude: asText(json['longitude']),
      createdByUserId: creator is Map ? asInt(creator['id']) : asInt(creator),
      updatedAt: parseDate(json['updated_at']),
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

  /// The `POST /contacts` / `PUT /contacts/{id}` body for a partner.
  ///
  /// A location only travels with the Offline lead source (the API requires it
  /// there and rejects it elsewhere), so [offlineSourceId] is attached
  /// whenever coordinates are present.
  Map<String, dynamic> toApiJson({int? offlineSourceId}) {
    final trimmedName = (name ?? '').trim();
    final json = <String, dynamic>{
      'contact_type': 'partner',
      'phone': phone.trim(),
      'name': trimmedName.isEmpty ? phone.trim() : trimmedName,
      'partner_profile': {
        'profession_type': type.apiValue,
        if ((place ?? '').trim().isNotEmpty) 'work_area': place!.trim(),
      },
    };
    void put(String key, String? value) {
      if (value == null || value.trim().isEmpty) return;
      json[key] = value.trim();
    }

    put('address', address);
    put('district', district);
    final lat = double.tryParse((latitude ?? '').trim());
    final lng = double.tryParse((longitude ?? '').trim());
    if (lat != null && lng != null && offlineSourceId != null) {
      json['lead_source_id'] = offlineSourceId;
      json['latitude'] = lat;
      json['longitude'] = lng;
    }
    return json;
  }
}
