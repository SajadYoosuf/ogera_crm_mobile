/// PipelineService fetches the pipeline stages and contacts for the
/// Pipeline tab.
///
/// ## Why a separate service?
/// The existing ContactsService and ProfessionalsService are shaped for their
/// own tabs (paged lists, search, edit). The Pipeline tab reads the same
/// `/contacts` endpoint but needs:
///   - Stages from `GET /pipeline/stages?contact_type=...` (integer IDs)
///   - Contacts from `GET /contacts?contact_type=...` matched to those stages
///     by the `lead_stage.stage_slug` field on each row.
///
/// Keeping this in its own service makes the view model simple and avoids
/// changing the shared ContactsService contract.
library;

import '../core/network/api_client.dart';
import '../core/utils/formatters.dart';

// ─── domain models ────────────────────────────────────────────────────────────

/// One pipeline stage, from `GET /pipeline/stages`.
///
/// [id] is the integer primary key — send it as `stage_id` to move a contact.
/// [slug] is the short code ("new_lead", "interested", …).
/// [label] is the display name shown to users.
/// [orderIndex] controls the left-to-right order of the stage strip.
class PipelineStageModel {
  const PipelineStageModel({
    required this.id,
    required this.slug,
    required this.label,
    required this.orderIndex,
    required this.contactType,
  });

  final int id;
  final String slug;
  final String label;
  final int orderIndex;
  final String contactType;

  factory PipelineStageModel.fromJson(Map<String, dynamic> json) {
    return PipelineStageModel(
      id: asInt(json['id']) ?? 0,
      slug: asText(json['slug']) ?? '',
      label: asText(json['label']) ?? humanizeSlug(asText(json['slug']) ?? ''),
      orderIndex: asInt(json['order_index']) ?? 0,
      contactType: asText(json['contact_type']) ?? 'consumer',
    );
  }
}

/// A slim contact row for the Pipeline card.
///
/// We only need id, name, phone, stage slug (so we can bucket the row into a
/// stage column), district (for geography context) and assignee.
class PipelineContact {
  const PipelineContact({
    required this.id,
    required this.phone,
    required this.contactType,
    this.name,
    this.stageSlug,
    this.stageName,
    this.district,
    this.assignedToName,
    this.assignedToId,
    this.missingFields = const [],
  });

  final int id;
  final String phone;
  final String contactType; // 'consumer' | 'partner' | 'dealer'
  final String? name;
  final String? stageSlug;
  final String? stageName;
  final String? district;
  final String? assignedToName;

  /// The employee who owns this lead. Null when nobody is assigned yet.
  final int? assignedToId;
  final List<String> missingFields;

  String get displayName => (name ?? '').trim().isEmpty ? phone : name!.trim();
  bool get isVerified => missingFields.isEmpty;

  /// Parses one row from the contacts list endpoint.
  ///
  /// The API returns:
  ///   `lead_stage: { stage_id, stage_slug, stage_name, changed_at }`
  /// We read `stage_slug` here — the field name matches what the backend sends.
  factory PipelineContact.fromJson(Map<String, dynamic> json) {
    final stageMap = asMap(json['lead_stage'] ?? json['current_stage']);
    final assignedTo = json['assigned_to'];
    final assignedEmployee = asMap(
      assignedTo is Map ? assignedTo : json['assigned_employee'],
    );

    return PipelineContact(
      id: asInt(json['id']) ?? 0,
      phone: asText(json['phone']) ?? '',
      contactType: asText(json['contact_type']) ?? 'consumer',
      name: asText(json['name']),
      stageSlug: asText(stageMap['stage_slug']) ?? asText(stageMap['stage']),
      stageName: asText(stageMap['stage_name']),
      district: asText(json['district']),
      assignedToName: asText(assignedEmployee['name']),
      assignedToId: asInt(assignedEmployee['id']),
      missingFields: [
        for (final f in (json['missing_fields'] as List?) ?? const [])
          f.toString(),
      ],
    );
  }
}

// ─── service ──────────────────────────────────────────────────────────────────

class PipelineService {
  const PipelineService(this._api);

  final ApiClient _api;

  /// Ordered stages for one contact type, from `GET /pipeline/stages`.
  ///
  /// The [contactType] must be 'consumer', 'partner', or 'dealer'.
  Future<List<PipelineStageModel>> stages(String contactType) async {
    final data = await _api.get(
      '/pipeline/stages',
      query: {'contact_type': contactType},
    );
    final rows = asList(data);
    final stages = rows
        .map((r) => PipelineStageModel.fromJson(asMap(r)))
        .toList();
    stages.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return stages;
  }

  /// All contacts of [contactType], up to [pageSize] × 20 pages.
  ///
  /// Does not filter by stage on the server so we get counts for every stage
  /// column in one request — the view model does the bucketing locally.
  Future<List<PipelineContact>> contacts(
    String contactType, {
    String? search,
    int pageSize = 100,
  }) async {
    final rows = <Map<String, dynamic>>[];
    for (var page = 0; page < 20; page++) {
      final data = asMap(
        await _api.get(
          '/contacts',
          query: {
            'contact_type': contactType,
            if ((search ?? '').isNotEmpty) 'search': search,
            'skip': page * pageSize,
            'limit': pageSize,
          },
        ),
      );
      final items = asList(data['items']);
      rows.addAll(items);
      final total = asInt(data['total']) ?? rows.length;
      if (items.length < pageSize || rows.length >= total) break;
    }
    return rows
        .map((r) => PipelineContact.fromJson(asMap(r)))
        .toList(growable: false);
  }
}
