import '../core/utils/formatters.dart';

enum ContactType {
  lead('lead', 'Lead'),
  awareness('awareness', 'Awareness');

  const ContactType(this.id, this.label);

  final String id;
  final String label;

  static ContactType fromId(String? value) =>
      value == 'awareness' ? ContactType.awareness : ContactType.lead;
}

/// Mirrors the `contacts` row exposed by `/api/contacts`. Every field the web
/// app stores is preserved, including the referral snapshot and campaign flags.
class Contact {
  const Contact({
    required this.id,
    required this.phone,
    required this.contactType,
    required this.createdAt,
    this.name,
    this.countryCode,
    this.source,
    this.address,
    this.district,
    this.panchayath,
    this.ward,
    this.houseStage,
    this.currentTank,
    this.waterSource,
    this.tankSizeInterest,
    this.awarenessLevel,
    this.remarks,
    this.latitude,
    this.longitude,
    this.referredBySaleId,
    this.referredByContactId,
    this.referredBySaleBuyerName,
    this.referredByContactName,
    this.referredByContactPhone,
    this.professionalType,
    this.professionalName,
    this.professionalPhone,
    this.professionalAddress,
    this.professionalLatitude,
    this.professionalLongitude,
    this.isCampaignTarget = false,
    this.campaignStaffId,
    this.addedBy,
    this.createdByUserId,
    this.stage,
    this.followupAssignedTo,
    this.followupAssignedUserId,
    this.followupDueDate,
    this.updatedAt,
  });

  final int id;
  final String phone;
  final ContactType contactType;
  final DateTime createdAt;
  final String? name;
  final String? countryCode;
  final String? source;
  final String? address;
  final String? district;
  final String? panchayath;
  final String? ward;
  final String? houseStage;
  final String? currentTank;
  final String? waterSource;
  final String? tankSizeInterest;
  final String? awarenessLevel;
  final String? remarks;
  final String? latitude;
  final String? longitude;
  final int? referredBySaleId;
  final int? referredByContactId;
  final String? referredBySaleBuyerName;
  final String? referredByContactName;
  final String? referredByContactPhone;
  final String? professionalType;
  final String? professionalName;
  final String? professionalPhone;
  final String? professionalAddress;
  final String? professionalLatitude;
  final String? professionalLongitude;
  final bool isCampaignTarget;
  final String? campaignStaffId;
  final String? addedBy;
  final int? createdByUserId;
  final String? stage;
  final String? followupAssignedTo;
  final int? followupAssignedUserId;
  final String? followupDueDate;
  final DateTime? updatedAt;

  String get displayName => (name ?? '').trim().isEmpty ? phone : name!.trim();

  double? get lat => asDouble(latitude);
  double? get lng => asDouble(longitude);
  bool get hasLocation => lat != null && lng != null;

  /// The referral source shown on the detail screen, whichever path was used.
  String? get referralSummary {
    if (professionalName != null || professionalPhone != null) {
      final type = professionalType ?? 'Professional';
      return '$type · ${professionalName ?? professionalPhone}';
    }
    if (referredByContactName != null) {
      return 'Contact · $referredByContactName';
    }
    if (referredBySaleBuyerName != null) {
      return 'Sale · $referredBySaleBuyerName';
    }
    return null;
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: asInt(json['id']) ?? 0,
      phone: asText(json['phone']) ?? '',
      contactType: ContactType.fromId(asText(json['contactType'])),
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      name: asText(json['name']),
      countryCode: asText(json['countryCode']),
      source: asText(json['source']),
      address: asText(json['address']),
      district: asText(json['district']),
      panchayath: asText(json['panchayath']),
      ward: asText(json['ward']),
      houseStage: asText(json['houseStage']),
      currentTank: asText(json['currentTank']),
      waterSource: asText(json['waterSource']),
      tankSizeInterest: asText(json['tankSizeInterest']),
      awarenessLevel: asText(json['awarenessLevel']),
      remarks: asText(json['remarks']),
      latitude: asText(json['latitude']),
      longitude: asText(json['longitude']),
      referredBySaleId: asInt(json['referredBySaleId']),
      referredByContactId: asInt(json['referredByContactId']),
      referredBySaleBuyerName: asText(json['referredBySaleBuyerName']),
      referredByContactName: asText(json['referredByContactName']),
      referredByContactPhone: asText(json['referredByContactPhone']),
      professionalType: asText(json['professionalType']),
      professionalName: asText(json['professionalName']),
      professionalPhone: asText(json['professionalPhone']),
      professionalAddress: asText(json['professionalAddress']),
      professionalLatitude: asText(json['professionalLatitude']),
      professionalLongitude: asText(json['professionalLongitude']),
      isCampaignTarget: json['isCampaignTarget'] == true,
      campaignStaffId: asText(json['campaignStaffId']),
      addedBy: asText(json['addedBy']),
      createdByUserId: asInt(json['createdByUserId']),
      stage: asText(json['stage']),
      followupAssignedTo: asText(json['followupAssignedTo']),
      followupAssignedUserId: asInt(json['followupAssignedUserId']),
      followupDueDate: asText(json['followupDueDate'])?.substring(0, 10),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  /// True when this staff member may edit or delete the record. Admins and
  /// sales heads always may; staff may only touch what they created. Legacy
  /// rows with no creator id belong to nobody and stay read-only for staff.
  bool isEditableBy({required int userId, required bool isPrivileged}) {
    if (isPrivileged) return true;
    if (createdByUserId != null) return createdByUserId == userId;
    return addedBy != null && addedBy == userId.toString();
  }
}

/// Payload for create and update. Only non-null fields are sent, so an edit
/// never blanks a column the form did not touch.
class ContactDraft {
  ContactDraft({
    this.name,
    required this.phone,
    this.source,
    this.address,
    this.district,
    this.panchayath,
    this.ward,
    this.houseStage,
    this.currentTank,
    this.waterSource,
    this.tankSizeInterest,
    this.contactType = ContactType.lead,
    this.awarenessLevel,
    this.remarks,
    this.latitude,
    this.longitude,
    this.referredBySaleId,
    this.referredByContactId,
    this.professionalType,
    this.professionalName,
    this.professionalPhone,
    this.professionalAddress,
    this.professionalLatitude,
    this.professionalLongitude,
    this.isCampaignTarget = false,
    this.campaignStaffId,
  });

  String? name;
  String phone;
  String? source;
  String? address;
  String? district;
  String? panchayath;
  String? ward;
  String? houseStage;
  String? currentTank;
  String? waterSource;
  String? tankSizeInterest;
  ContactType contactType;
  String? awarenessLevel;
  String? remarks;
  String? latitude;
  String? longitude;
  int? referredBySaleId;
  int? referredByContactId;
  String? professionalType;
  String? professionalName;
  String? professionalPhone;
  String? professionalAddress;
  String? professionalLatitude;
  String? professionalLongitude;
  bool isCampaignTarget;
  String? campaignStaffId;

  factory ContactDraft.fromContact(Contact contact) {
    return ContactDraft(
      name: contact.name,
      phone: contact.phone,
      source: contact.source,
      address: contact.address,
      district: contact.district,
      panchayath: contact.panchayath,
      ward: contact.ward,
      houseStage: contact.houseStage,
      currentTank: contact.currentTank,
      waterSource: contact.waterSource,
      tankSizeInterest: contact.tankSizeInterest,
      contactType: contact.contactType,
      awarenessLevel: contact.awarenessLevel,
      remarks: contact.remarks,
      latitude: contact.latitude,
      longitude: contact.longitude,
      referredBySaleId: contact.referredBySaleId,
      referredByContactId: contact.referredByContactId,
      professionalType: contact.professionalType,
      professionalName: contact.professionalName,
      professionalPhone: contact.professionalPhone,
      professionalAddress: contact.professionalAddress,
      professionalLatitude: contact.professionalLatitude,
      professionalLongitude: contact.professionalLongitude,
      isCampaignTarget: contact.isCampaignTarget,
      campaignStaffId: contact.campaignStaffId,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'phone': phone.trim(),
      'contactType': contactType.id,
      'isCampaignTarget': isCampaignTarget,
    };
    void put(String key, Object? value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      json[key] = value is String ? value.trim() : value;
    }

    put('name', name);
    put('source', source);
    put('address', address);
    put('district', district);
    put('panchayath', panchayath);
    put('ward', ward);
    put('houseStage', houseStage);
    put('currentTank', currentTank);
    put('waterSource', waterSource);
    put('tankSizeInterest', tankSizeInterest);
    put('awarenessLevel', awarenessLevel);
    put('remarks', remarks);
    put('latitude', latitude);
    put('longitude', longitude);
    put('referredBySaleId', referredBySaleId);
    put('referredByContactId', referredByContactId);
    put('professionalType', professionalType);
    put('professionalName', professionalName);
    put('professionalPhone', professionalPhone);
    put('professionalAddress', professionalAddress);
    put('professionalLatitude', professionalLatitude);
    put('professionalLongitude', professionalLongitude);
    put('campaignStaffId', campaignStaffId);
    return json;
  }
}

/// Result envelope for the paged contacts list.
class ContactPage {
  const ContactPage({
    required this.contacts,
    required this.total,
    required this.page,
    required this.totalPages,
    required this.leadsCount,
    required this.awarenessCount,
  });

  final List<Contact> contacts;
  final int total;
  final int page;
  final int totalPages;
  final int leadsCount;
  final int awarenessCount;

  factory ContactPage.fromJson(Map<String, dynamic> json) {
    final rows = (json['contacts'] as List?) ?? const [];
    return ContactPage(
      contacts: rows
          .whereType<Map<String, dynamic>>()
          .map(Contact.fromJson)
          .toList(growable: false),
      total: asInt(json['total']) ?? 0,
      page: asInt(json['page']) ?? 1,
      totalPages: asInt(json['totalPages']) ?? 1,
      leadsCount: asInt(json['leadsCount']) ?? 0,
      awarenessCount: asInt(json['awarenessCount']) ?? 0,
    );
  }
}

/// The trimmed shape returned by `/api/contacts?fields=map`.
class ContactPin {
  const ContactPin({
    required this.id,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.contactType,
    this.name,
    this.stage,
    this.address,
  });

  final int id;
  final String phone;
  final double latitude;
  final double longitude;
  final ContactType contactType;
  final String? name;
  final String? stage;
  final String? address;

  String get displayName => (name ?? '').trim().isEmpty ? phone : name!.trim();

  static ContactPin? fromJson(Map<String, dynamic> json) {
    final lat = asDouble(json['latitude']);
    final lng = asDouble(json['longitude']);
    if (lat == null || lng == null) return null;
    return ContactPin(
      id: asInt(json['id']) ?? 0,
      phone: asText(json['phone']) ?? '',
      latitude: lat,
      longitude: lng,
      contactType: ContactType.fromId(asText(json['contactType'])),
      name: asText(json['name']),
      stage: asText(json['stage']),
      address: asText(json['address']),
    );
  }
}
