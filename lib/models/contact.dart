import '../core/utils/formatters.dart';

/// The mobile app's two kinds of consumer contact. The API has no such type:
/// both are `consumer` contacts, told apart by the consumer profile's
/// `awareness_mode` (1 = still needs education, 0 or unset = sales-ready).
enum ContactType {
  lead('lead', 'Lead'),
  awareness('awareness', 'Awareness');

  const ContactType(this.id, this.label);

  final String id;
  final String label;

  static ContactType fromId(String? value) =>
      value == 'awareness' ? ContactType.awareness : ContactType.lead;

  /// The `awareness_mode` the API stores for this kind of contact.
  int get awarenessMode => this == ContactType.awareness ? 1 : 0;
}

/// The three contact types the Contacts tab lists, matching the web tabs.
/// `contact_type` in the API is one of these ids. Lead and awareness are not
/// types; they are a stage or profile detail (see [ContactType]).
enum ContactKind {
  consumer('consumer', 'Consumer'),
  partner('partner', 'Partner'),
  dealer('dealer', 'Dealer');

  const ContactKind(this.id, this.label);

  final String id;
  final String label;

  /// Reads the API's `contact_type`. Anything unknown is treated as a consumer,
  /// the same default the API uses.
  static ContactKind fromId(String? value) => switch (value) {
    'partner' => ContactKind.partner,
    'dealer' => ContactKind.dealer,
    _ => ContactKind.consumer,
  };
}

/// Row counts for the Contacts tabs, from `GET /contacts/type-counts`.
/// The counts ignore search and filters, the same as the web tabs.
class ContactTypeCounts {
  const ContactTypeCounts({
    this.all = 0,
    this.consumer = 0,
    this.partner = 0,
    this.dealer = 0,
  });

  factory ContactTypeCounts.fromJson(Map<String, dynamic> json) {
    return ContactTypeCounts(
      all: asInt(json['all']) ?? 0,
      consumer: asInt(json['consumer']) ?? 0,
      partner: asInt(json['partner']) ?? 0,
      dealer: asInt(json['dealer']) ?? 0,
    );
  }

  final int all;
  final int consumer;
  final int partner;
  final int dealer;

  /// The count for one tab. `null` is the "All Contacts" tab.
  int of(ContactKind? kind) => switch (kind) {
    null => all,
    ContactKind.consumer => consumer,
    ContactKind.partner => partner,
    ContactKind.dealer => dealer,
  };
}

/// A consumer contact as returned by `GET /contacts` (slim row) or
/// `GET /contacts/{id}` (full detail). Fields the API has no column for
/// (panchayath, ward, water source, campaign flags and the like) stay null.
class Contact {
  const Contact({
    required this.id,
    required this.phone,
    required this.contactType,
    required this.createdAt,
    this.kind = ContactKind.consumer,
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
    this.referredByContactId,
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
    this.leadSourceId,
    this.assignedToName,
    this.missingFields = const [],
  });

  final int id;
  final String phone;
  final ContactType contactType;

  /// Consumer, partner or dealer. Drives the type badge on the Contacts tab.
  final ContactKind kind;
  final DateTime createdAt;
  final String? name;
  final String? countryCode;

  /// The lead source's slug (`meta`, `website`, `offline`, ...).
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
  final int? referredByContactId;
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

  /// The employee who owns the contact (`assigned_to`), as a string id.
  final String? followupAssignedTo;
  final int? followupAssignedUserId;
  final String? followupDueDate;
  final DateTime? updatedAt;
  final int? leadSourceId;
  final String? assignedToName;

  /// What the API still wants before this contact counts as verified
  /// (`district`, `house_stage`, `lead_source`, ...). Empty when verified.
  final List<String> missingFields;

  bool get isVerified => missingFields.isEmpty;

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
    return null;
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    final profile = _map(json['consumer_profile']);
    final stage = _map(json['lead_stage'] ?? json['current_stage']);
    final source = _map(json['lead_source']);
    final referrer = _map(json['referred_by']);
    final assigned = json['assigned_to'];
    final assignedEmployee = _map(
      assigned is Map ? assigned : json['assigned_employee'],
    );
    final creator = json['created_by'];
    final awarenessMode =
        asInt(json['awareness_mode']) ?? asInt(profile['awareness_mode']);
    final assignedId = assigned is Map
        ? asInt(assigned['id'])
        : asInt(assigned) ?? asInt(assignedEmployee['id']);
    final createdBy = creator is Map ? asInt(creator['id']) : asInt(creator);

    return Contact(
      id: asInt(json['id']) ?? 0,
      phone: asText(json['phone']) ?? '',
      contactType: awarenessMode == 1
          ? ContactType.awareness
          : ContactType.lead,
      kind: ContactKind.fromId(asText(json['contact_type'])),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      name: asText(json['name']),
      source: asText(source['slug']),
      leadSourceId: asInt(source['id']) ?? asInt(json['lead_source_id']),
      address: asText(json['address']),
      district: asText(json['district']),
      houseStage: asText(profile['house_stage']),
      currentTank: asText(profile['current_tank_type']),
      latitude: asText(json['latitude']),
      longitude: asText(json['longitude']),
      referredByContactId:
          asInt(referrer['id']) ?? asInt(json['referred_by_id']),
      referredByContactName: asText(referrer['name']),
      referredByContactPhone: asText(referrer['phone']),
      addedBy: createdBy?.toString(),
      createdByUserId: createdBy,
      stage: asText(stage['stage']),
      followupAssignedTo: assignedId?.toString(),
      followupAssignedUserId: assignedId,
      assignedToName: asText(assignedEmployee['name']),
      updatedAt: parseDate(json['updated_at']),
      missingFields: [
        for (final field in (json['missing_fields'] as List?) ?? const [])
          field.toString(),
      ],
    );
  }

  /// True when this staff member may edit or delete the record. Admins and
  /// managers always may; staff may only touch what they created. Legacy
  /// rows with no creator id belong to nobody and stay read-only for staff.
  bool isEditableBy({required int userId, required bool isPrivileged}) {
    if (isPrivileged) return true;
    if (createdByUserId != null) return createdByUserId == userId;
    return addedBy != null && addedBy == userId.toString();
  }
}

/// Payload for create and update.
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

  /// The `POST /contacts` / `PUT /contacts/{id}` body.
  ///
  /// [leadSourceId] is resolved by the service from the source slug. Only
  /// non-blank fields are sent, so an edit never blanks a column the form did
  /// not touch. Coordinates travel only with the Offline source: the API
  /// requires them there and rejects them anywhere else.
  Map<String, dynamic> toApiJson({int? leadSourceId, bool offline = false}) {
    final trimmedName = (name ?? '').trim();
    final json = <String, dynamic>{
      'contact_type': 'consumer',
      'phone': phone.trim(),
      // The API requires a name; fall back to the phone number so a quick
      // capture is still saved and findable.
      'name': trimmedName.isEmpty ? phone.trim() : trimmedName,
    };
    void put(String key, Object? value) {
      if (value == null) return;
      if (value is String && value.trim().isEmpty) return;
      json[key] = value is String ? value.trim() : value;
    }

    put('district', district);
    put('address', address);
    put('lead_source_id', leadSourceId);
    put('referred_by_id', referredByContactId);
    if (offline) {
      final lat = double.tryParse((latitude ?? '').trim());
      final lng = double.tryParse((longitude ?? '').trim());
      if (lat != null && lng != null) {
        json['latitude'] = lat;
        json['longitude'] = lng;
      }
    }
    json['consumer_profile'] = {
      'awareness_mode': contactType.awarenessMode,
      if ((houseStage ?? '').trim().isNotEmpty)
        'house_stage': houseStage!.trim(),
      if ((currentTank ?? '').trim().isNotEmpty)
        'current_tank_type': currentTank!.trim(),
    };
    return json;
  }
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map<String, dynamic> ? value : const {};

/// One page of the contacts list. The API pages by `skip`/`limit`; this keeps
/// the page arithmetic in one place for the view model.
class ContactPage {
  const ContactPage({
    required this.contacts,
    required this.total,
    required this.page,
    required this.totalPages,
  });

  final List<Contact> contacts;
  final int total;
  final int page;
  final int totalPages;

  factory ContactPage.fromJson(Map<String, dynamic> json) {
    final rows = (json['items'] as List?) ?? const [];
    final total = asInt(json['total']) ?? 0;
    final limit = (asInt(json['limit']) ?? 20).clamp(1, 1 << 20);
    final skip = asInt(json['skip']) ?? 0;
    return ContactPage(
      contacts: rows
          .whereType<Map<String, dynamic>>()
          .map(Contact.fromJson)
          .toList(growable: false),
      total: total,
      page: skip ~/ limit + 1,
      totalPages: total == 0 ? 1 : (total + limit - 1) ~/ limit,
    );
  }
}

/// The trimmed shape returned by `GET /contacts/map`.
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
      contactType: asInt(json['awareness_mode']) == 1
          ? ContactType.awareness
          : ContactType.lead,
      name: asText(json['name']),
      stage: asText(json['stage']),
      address: asText(json['address']),
    );
  }
}
