import '../core/utils/formatters.dart';

/// Mobile model for the `/contacts` API.
///
/// Mirrors the backend contract in `ogera_crm_backend/schemas/contact.py`,
/// `consumer_profile.py`, `partner_profile.py`, `dealer_profile.py`,
/// `lead_stage.py`, `lead_source.py` and `employee.py`.
///
/// Two response shapes share one [Contact] class:
///   - `GET /contacts` (list row, `ContactListItem`): identity, headline
///     fields, `lead_stage`, `lead_source`, `assigned_to` and `created_by` as
///     `{id, name}`, `is_verified`, `missing_fields`.
///   - `GET /contacts/{id}`, `POST`, `PUT` (`ContactResponse`): everything,
///     including the profile blocks, `current_stage`, `referred_by`,
///     `interested_products` and `referrals_count`.
/// Fields a shape does not send stay null (or empty for lists).
///
/// Awareness is not a contact type. It is the `aware` pipeline stage
/// (see [LeadStageInfo.isAware]).

/// The API's contact types (`ContactType` in `schemas/enums.py`). The value
/// of `contact_type` in every request and response.
enum ContactKind {
  consumer('consumer', 'Consumer'),
  partner('partner', 'Partner'),
  dealer('dealer', 'Dealer');

  const ContactKind(this.id, this.label);

  final String id;
  final String label;

  /// Reads `contact_type`. Anything unknown is treated as a consumer, the same
  /// default the backend uses.
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

/// The lead source of a contact (`LeadSourceSummary`).
class LeadSourceRef {
  const LeadSourceRef({
    required this.id,
    required this.name,
    required this.slug,
  });

  final int id;
  final String name;

  /// Stable key such as `meta`, `website` or `offline`.
  final String slug;

  /// Null when the API sent no source.
  static LeadSourceRef? fromJson(dynamic value) {
    final map = _asMap(value);
    final id = asInt(map?['id']);
    if (map == null || id == null) return null;
    return LeadSourceRef(
      id: id,
      name: asText(map['name']) ?? '',
      slug: asText(map['slug']) ?? '',
    );
  }
}

/// An employee attached to a contact. The detail shape (`EmployeeSummary`)
/// fills every field; the list shape (`NameRef`) fills only [id] and [name].
class EmployeeRef {
  const EmployeeRef({
    required this.id,
    required this.name,
    this.email,
    this.role,
    this.phone,
    this.branch,
  });

  final int id;
  final String name;
  final String? email;
  final String? role;
  final String? phone;
  final String? branch;

  static EmployeeRef? fromJson(dynamic value) {
    final map = _asMap(value);
    final id = asInt(map?['id']);
    if (map == null || id == null) return null;
    return EmployeeRef(
      id: id,
      name: asText(map['name']) ?? '',
      email: asText(map['email']),
      role: asText(map['role']),
      phone: asText(map['phone']),
      branch: asText(map['branch']),
    );
  }
}

/// The referrer of a contact (`ContactSummary`). Kept shallow on purpose:
/// the backend does not nest a full contact inside another one.
class ContactSummary {
  const ContactSummary({
    required this.id,
    required this.phone,
    required this.contactType,
    this.name,
    this.district,
  });

  final int id;
  final String? name;
  final String phone;
  final ContactKind contactType;
  final String? district;

  String get displayName => (name ?? '').trim().isEmpty ? phone : name!.trim();

  static ContactSummary? fromJson(dynamic value) {
    final map = _asMap(value);
    final id = asInt(map?['id']);
    if (map == null || id == null) return null;
    return ContactSummary(
      id: id,
      name: asText(map['name']),
      phone: asText(map['phone']) ?? '',
      contactType: ContactKind.fromId(asText(map['contact_type'])),
      district: asText(map['district']),
    );
  }
}

/// A product the contact is interested in (`ProductRef`).
class ProductRef {
  const ProductRef({required this.id, required this.name});

  final int id;
  final String name;

  static ProductRef? fromJson(dynamic value) {
    final map = _asMap(value);
    final id = asInt(map?['id']);
    if (map == null || id == null) return null;
    return ProductRef(id: id, name: asText(map['name']) ?? '');
  }
}

/// A contact's pipeline stage. Used in both shapes: the list sends
/// `LeadStageSummary` (no `id`, `changed_by` or notes); the detail sends the
/// full `LeadStageResponse`.
class LeadStageInfo {
  const LeadStageInfo({
    required this.stageId,
    required this.stageSlug,
    required this.stageName,
    this.id,
    this.contactType,
    this.changedBy,
    this.changedByName,
    this.changedAt,
    this.lossReason,
    this.lossNotes,
    this.awarenessNote,
  });

  final int? id;
  final int stageId;
  final String stageSlug;
  final String stageName;
  final String? contactType;
  final int? changedBy;
  final String? changedByName;
  final DateTime? changedAt;
  final String? lossReason;
  final String? lossNotes;
  final String? awarenessNote;

  /// True once the contact has reached the awareness stage. This replaces
  /// the old "awareness" contact type.
  bool get isAware => stageSlug == 'aware';

  bool get isLost => stageSlug == 'lost';

  static LeadStageInfo? fromJson(dynamic value) {
    final map = _asMap(value);
    if (map == null) return null;
    return LeadStageInfo(
      id: asInt(map['id']),
      stageId: asInt(map['stage_id']) ?? 0,
      stageSlug: asText(map['stage_slug']) ?? '',
      stageName: asText(map['stage_name']) ?? '',
      contactType: asText(map['contact_type']),
      changedBy: asInt(map['changed_by']),
      changedByName: asText(map['changed_by_name']),
      changedAt: parseDate(map['changed_at']),
      lossReason: asText(map['loss_reason']),
      lossNotes: asText(map['loss_notes']),
      awarenessNote: asText(map['awareness_note']),
    );
  }
}

/// Consumer details (`ConsumerProfileResponse`). Only consumers have one.
class ConsumerProfile {
  const ConsumerProfile({
    required this.id,
    required this.contactId,
    this.houseStage,
    this.currentTankType,
    this.currentTankCapacity,
    this.currentTankAge,
  });

  final int id;
  final int contactId;

  /// One of the fixed house stages: `ready`, `under_construction`, `renovation`.
  final String? houseStage;

  /// One of the fixed tank types: `plastic`, `concrete`, `steel`, `other`.
  final String? currentTankType;

  /// Litres.
  final int? currentTankCapacity;

  /// Years.
  final int? currentTankAge;

  static ConsumerProfile? fromJson(dynamic value) {
    final map = _asMap(value);
    if (map == null) return null;
    return ConsumerProfile(
      id: asInt(map['id']) ?? 0,
      contactId: asInt(map['contact_id']) ?? 0,
      houseStage: asText(map['house_stage']),
      currentTankType: asText(map['current_tank_type']),
      currentTankCapacity: asInt(map['current_tank_capacity']),
      currentTankAge: asInt(map['current_tank_age']),
    );
  }
}

/// Partner details (`PartnerProfileResponse`). Only partners have one.
class PartnerProfile {
  const PartnerProfile({
    required this.id,
    required this.contactId,
    required this.professionType,
    this.workArea,
  });

  final int id;
  final int contactId;

  /// Profession key such as `plumber` or `interior_designer`.
  final String professionType;
  final String? workArea;

  static PartnerProfile? fromJson(dynamic value) {
    final map = _asMap(value);
    if (map == null) return null;
    return PartnerProfile(
      id: asInt(map['id']) ?? 0,
      contactId: asInt(map['contact_id']) ?? 0,
      professionType: asText(map['profession_type']) ?? '',
      workArea: asText(map['work_area']),
    );
  }
}

/// Dealer details (`DealerProfileResponse`). Only dealers have one.
class DealerProfile {
  const DealerProfile({
    required this.id,
    required this.contactId,
    required this.ownerName,
    this.email,
  });

  final int id;
  final int contactId;

  /// The person at the dealer. The dealer's account name is [Contact.name].
  final String ownerName;
  final String? email;

  static DealerProfile? fromJson(dynamic value) {
    final map = _asMap(value);
    if (map == null) return null;
    return DealerProfile(
      id: asInt(map['id']) ?? 0,
      contactId: asInt(map['contact_id']) ?? 0,
      ownerName: asText(map['owner_name']) ?? '',
      email: asText(map['email']),
    );
  }
}

/// A contact as returned by `GET /contacts` (list row) or
/// `GET /contacts/{id}`, `POST /contacts`, `PUT /contacts/{id}` (detail).
/// See the file comment for which fields each shape sends.
class Contact {
  const Contact({
    required this.id,
    required this.phone,
    required this.createdAt,
    this.contactType = ContactKind.consumer,
    this.name,
    this.phoneAlt,
    this.district,
    this.address,
    this.notes,
    this.latitude,
    this.longitude,
    this.referredById,
    this.referredBy,
    this.leadSourceId,
    this.leadSource,
    this.assignedTo,
    this.assignedEmployee,
    this.createdBy,
    this.createdByEmployee,
    this.updatedAt,
    this.deletedAt,
    this.referralsCount = 0,
    this.isVerified = false,
    this.missingFields = const [],
    this.currentStage,
    this.consumerProfile,
    this.partnerProfile,
    this.dealerProfile,
    this.interestedProducts = const [],
    this.autoFollowupNeeded = false,
    this.professionType,
    this.workArea,
    this.houseStage,
    this.ownerName,
  });

  final int id;
  final String phone;
  final ContactKind contactType;
  final DateTime createdAt;

  /// Account or person name. Optional in the API; use [displayName] for UI.
  final String? name;
  final String? phoneAlt;
  final String? district;
  final String? address;

  /// Free-text note.
  final String? notes;

  final double? latitude;
  final double? longitude;

  final int? referredById;

  /// Detail only.
  final ContactSummary? referredBy;

  final int? leadSourceId;
  final LeadSourceRef? leadSource;

  /// The employee who owns the lead now. Null while unassigned.
  final int? assignedTo;

  /// Detail: full employee. List: `{id, name}` only.
  final EmployeeRef? assignedEmployee;

  /// The employee who entered the contact.
  final int? createdBy;
  final EmployeeRef? createdByEmployee;

  final DateTime? updatedAt;

  /// Always null for live contacts (deleted ones are not returned).
  final DateTime? deletedAt;

  /// Detail only: how many contacts this one referred.
  final int referralsCount;

  /// Computed by the API. True when [missingFields] is empty.
  final bool isVerified;

  /// What the API still needs before this contact counts as verified
  /// (`name`, `district`, `house_stage`, `location`, ...).
  final List<String> missingFields;

  final LeadStageInfo? currentStage;

  final ConsumerProfile? consumerProfile;
  final PartnerProfile? partnerProfile;
  final DealerProfile? dealerProfile;

  /// Detail only.
  final List<ProductRef> interestedProducts;

  /// Detail, create and update only: true when the web should ask for the
  /// first follow-up (the creator is an admin or manager).
  final bool autoFollowupNeeded;

  /// Headline fields. The list sends them at the top level; the detail fills
  /// them from [partnerProfile], [consumerProfile] and [dealerProfile].
  final String? professionType;
  final String? workArea;
  final String? houseStage;
  final String? ownerName;

  String get displayName => (name ?? '').trim().isEmpty ? phone : name!.trim();

  bool get hasLocation => latitude != null && longitude != null;

  /// The referral source shown on the detail screen.
  String? get referralSummary {
    final referrer = referredBy;
    if (referrer != null) {
      return 'Contact · ${referrer.displayName}';
    }
    return null;
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    final consumer = ConsumerProfile.fromJson(json['consumer_profile']);
    final partner = PartnerProfile.fromJson(json['partner_profile']);
    final dealer = DealerProfile.fromJson(json['dealer_profile']);

    // `assigned_to` is an int in the detail and {id, name} in the list.
    final assigned = json['assigned_to'];
    // `created_by` is an int in the detail and {id, name} in the list.
    final creator = json['created_by'];
    final creatorRef = EmployeeRef.fromJson(creator);
    final creatorBranch = asText(json['created_by_branch']);
    final creatorEmployee = creatorRef == null
        ? null
        : EmployeeRef(
            id: creatorRef.id,
            name: creatorRef.name,
            email: creatorRef.email,
            role: creatorRef.role,
            phone: creatorRef.phone,
            branch: creatorRef.branch ?? creatorBranch,
          );

    return Contact(
      id: asInt(json['id']) ?? 0,
      contactType: ContactKind.fromId(asText(json['contact_type'])),
      name: asText(json['name']),
      phone: asText(json['phone']) ?? '',
      phoneAlt: asText(json['phone_alt']),
      district: asText(json['district']),
      address: asText(json['address']),
      notes: asText(json['notes']),
      latitude: asDouble(json['latitude']),
      longitude: asDouble(json['longitude']),
      referredById: asInt(json['referred_by_id']),
      referredBy: ContactSummary.fromJson(json['referred_by']),
      leadSourceId:
          asInt(json['lead_source_id']) ??
          LeadSourceRef.fromJson(json['lead_source'])?.id,
      leadSource: LeadSourceRef.fromJson(json['lead_source']),
      assignedTo: assigned is Map ? asInt(assigned['id']) : asInt(assigned),
      assignedEmployee:
          EmployeeRef.fromJson(json['assigned_employee']) ??
          EmployeeRef.fromJson(assigned),
      createdBy: creator is Map ? asInt(creator['id']) : asInt(creator),
      createdByEmployee: creatorEmployee,
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at']),
      deletedAt: parseDate(json['deleted_at']),
      referralsCount: asInt(json['referrals_count']) ?? 0,
      isVerified: json['is_verified'] == true,
      missingFields: [
        for (final field in (json['missing_fields'] as List?) ?? const [])
          field.toString(),
      ],
      // The list sends `lead_stage`; the detail sends `current_stage`.
      currentStage: LeadStageInfo.fromJson(
        json['current_stage'] ?? json['lead_stage'],
      ),
      consumerProfile: consumer,
      partnerProfile: partner,
      dealerProfile: dealer,
      interestedProducts: [
        for (final item in (json['interested_products'] as List?) ?? const [])
          ?ProductRef.fromJson(item),
      ],
      autoFollowupNeeded: json['auto_followup_needed'] == true,
      professionType:
          partner?.professionType ?? asText(json['profession_type']),
      workArea: partner?.workArea ?? asText(json['work_area']),
      houseStage: consumer?.houseStage ?? asText(json['house_stage']),
      ownerName: dealer?.ownerName ?? asText(json['owner_name']),
    );
  }

  /// Client-side edit rule for the mobile UI. Admins and managers may edit
  /// any contact. Staff may edit only contacts they created. The backend
  /// enforces visibility, not this rule.
  bool isEditableBy({required int userId, required bool isPrivileged}) {
    if (isPrivileged) return true;
    return createdBy == userId;
  }
}

/// Payload for `POST /contacts` (`ContactCreate`) and `PUT /contacts/{id}`
/// (`ContactUpdate`). The form fills this in; [toApiJson] turns it into the
/// request body.
class ContactDraft {
  ContactDraft({
    this.name,
    required this.phone,
    this.phoneAlt,
    this.source,
    this.district,
    this.address,
    this.notes,
    this.contactType = ContactKind.consumer,
    this.houseStage,
    this.currentTank,
    this.tankCapacity,
    this.tankAge,
    this.professionType,
    this.workArea,
    this.ownerName,
    this.email,
    this.latitude,
    this.longitude,
    this.referredByContactId,
    this.assignedTo,
    this.interestedProductIds,
  });

  String? name;
  String phone;
  String? phoneAlt;

  /// The lead source slug (`meta`, `offline`, ...). The service resolves it to
  /// `lead_source_id` before sending.
  String? source;
  String? district;
  String? address;
  String? notes;
  ContactKind contactType;

  // Consumer fields
  String? houseStage;
  String? currentTank;
  int? tankCapacity;
  int? tankAge;

  // Partner fields
  String? professionType;
  String? workArea;

  // Dealer fields
  String? ownerName;
  String? email;

  /// Kept as text because the form edits them as text.
  String? latitude;
  String? longitude;

  int? referredByContactId;
  int? assignedTo;

  /// `null` means "do not send" (keep the existing product on update).
  /// An empty list clears the product on update; otherwise this contains one id.
  List<int>? interestedProductIds;

  factory ContactDraft.fromContact(Contact contact) {
    return ContactDraft(
      name: contact.name,
      phone: contact.phone,
      phoneAlt: contact.phoneAlt,
      source: contact.leadSource?.slug,
      district: contact.district,
      address: contact.address,
      notes: contact.notes,
      contactType: contact.contactType,
      houseStage: contact.consumerProfile?.houseStage,
      currentTank: contact.consumerProfile?.currentTankType,
      tankCapacity: contact.consumerProfile?.currentTankCapacity,
      tankAge: contact.consumerProfile?.currentTankAge,
      professionType: contact.partnerProfile?.professionType,
      workArea: contact.partnerProfile?.workArea,
      ownerName: contact.dealerProfile?.ownerName,
      email: contact.dealerProfile?.email,
      latitude: contact.latitude?.toString(),
      longitude: contact.longitude?.toString(),
      referredByContactId: contact.referredById,
      assignedTo: contact.assignedTo,
      interestedProductIds: [for (final p in contact.interestedProducts) p.id],
    );
  }

  /// The request body for create or update.
  ///
  /// [leadSourceId] is resolved by the service from [source]. Only non-blank
  /// fields are sent, so an edit never blanks a field the form did not touch.
  /// Coordinates are sent only with the Offline source (`offline: true`),
  /// because the backend rejects them for any other source.
  /// Only the profile block for [contactType] is sent.
  Map<String, dynamic> toApiJson({int? leadSourceId, bool offline = false}) {
    final trimmedName = (name ?? '').trim();
    final json = <String, dynamic>{
      'contact_type': contactType.id,
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

    put('phone_alt', phoneAlt);
    put('district', district);
    put('address', address);
    put('notes', notes);
    put('lead_source_id', leadSourceId);
    put('referred_by_id', referredByContactId);
    put('assigned_to', assignedTo);
    if (offline) {
      final lat = double.tryParse((latitude ?? '').trim());
      final lng = double.tryParse((longitude ?? '').trim());
      if (lat != null && lng != null) {
        json['latitude'] = lat;
        json['longitude'] = lng;
      }
    }
    if (interestedProductIds != null) {
      json['interested_product_ids'] = interestedProductIds;
    }

    switch (contactType) {
      case ContactKind.consumer:
        final profile = <String, dynamic>{};
        _putText(profile, 'house_stage', houseStage);
        _putText(profile, 'current_tank_type', currentTank);
        if (tankCapacity != null) {
          profile['current_tank_capacity'] = tankCapacity;
        }
        if (tankAge != null) profile['current_tank_age'] = tankAge;
        if (profile.isNotEmpty) json['consumer_profile'] = profile;
      case ContactKind.partner:
        final profile = <String, dynamic>{};
        _putText(profile, 'profession_type', professionType);
        _putText(profile, 'work_area', workArea);
        json['partner_profile'] = profile;
      case ContactKind.dealer:
        final profile = <String, dynamic>{};
        _putText(profile, 'owner_name', ownerName);
        _putText(profile, 'email', email);
        json['dealer_profile'] = profile;
    }
    return json;
  }
}

/// Adds [value] under [key] when it is not blank.
void _putText(Map<String, dynamic> target, String key, String? value) {
  final trimmed = (value ?? '').trim();
  if (trimmed.isNotEmpty) target[key] = trimmed;
}

/// Returns [value] as a JSON object, or null when it is not one.
Map<String, dynamic>? _asMap(dynamic value) =>
    value is Map<String, dynamic> ? value : null;

/// One page of the contacts list (`ContactListResponse`). The API pages by
/// `skip`/`limit`; this keeps the page arithmetic in one place for the view model.
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
