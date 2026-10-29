/// PipelineViewModel manages state for the Pipeline tab.
///
/// ## What the Pipeline tab shows
/// The user sees contacts bucketed into pipeline stages for one contact type
/// at a time. They switch between Consumer, Partner and Dealer with chips at
/// the top. Below that, a horizontal stage strip lets them focus on one stage.
///
/// ## How it works
/// 1. `load()` is called when the tab becomes active (or when the user pulls
///    down to refresh).
/// 2. It fetches the ordered stages for the current contact type from
///    `GET /pipeline/stages?contact_type=...`.
/// 3. It fetches all matching contacts from `GET /contacts?contact_type=...`.
/// 4. It buckets the contacts into stages by matching `contact.stageSlug` to
///    `stage.slug`. Contacts without a stage go into `_unstaged`.
/// 5. Selecting a stage chip calls `selectStage()`, which flips the list.
///    Selecting "All" clears the filter and shows every contact.
///
/// ## Why bucket locally instead of fetching per stage?
/// The stage count badges (e.g. "New Lead 12") need counts for every stage at
/// once. One request is cheaper than N parallel requests.
library;

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../services/pipeline_service.dart';

// ─── contact type enum ─────────────────────────────────────────────────────

/// Which of the three contact-type boards is open.
enum PipelineContactType {
  consumer('Consumer', 'consumer'),
  partner('Partner', 'partner'),
  dealer('Dealer', 'dealer');

  const PipelineContactType(this.label, this.apiValue);

  final String label;
  final String apiValue; // the value sent in contact_type= query param
}

// ─── view model ────────────────────────────────────────────────────────────

class PipelineViewModel extends ChangeNotifier {
  PipelineViewModel(this._service);

  final PipelineService _service;

  // ── state ────────────────────────────────────────────────────────────────

  bool _isLoading = false;
  String? _error;
  FailureKind? _errorKind;

  PipelineContactType _activeType = PipelineContactType.consumer;

  /// Ordered stages from the API for the current contact type.
  List<PipelineStageModel> _stages = [];

  /// All contacts for the current type, unsorted.
  List<PipelineContact> _contacts = [];

  /// The selected stage. Null means "All" — show every contact.
  PipelineStageModel? _selectedStage;

  // ── getters ──────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get error => _error;
  FailureKind? get errorKind => _errorKind;
  PipelineContactType get activeType => _activeType;
  List<PipelineStageModel> get stages => List.unmodifiable(_stages);
  PipelineStageModel? get selectedStage => _selectedStage;

  /// The contacts shown in the list.
  ///
  /// When [_selectedStage] is null (the "All" pseudo-stage), every contact is
  /// returned. Otherwise only contacts whose stageSlug matches.
  List<PipelineContact> get visibleContacts {
    final sel = _selectedStage;
    if (sel == null) return List.unmodifiable(_contacts);
    return _contacts.where((c) => c.stageSlug == sel.slug).toList();
  }

  /// How many contacts sit in [stage].
  int countInStage(PipelineStageModel stage) =>
      _contacts.where((c) => c.stageSlug == stage.slug).length;

  /// Total contacts loaded (across all stages).
  int get totalCount => _contacts.length;

  // ── public actions ───────────────────────────────────────────────────────

  /// Initial load and pull-to-refresh.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _errorKind = null;
    notifyListeners();

    try {
      final typeValue = _activeType.apiValue;
      final results = await Future.wait([
        _service.stages(typeValue),
        _service.contacts(typeValue),
      ]);
      _stages = results[0] as List<PipelineStageModel>;
      _contacts = results[1] as List<PipelineContact>;
      // Keep selected stage valid after reload.
      if (_selectedStage != null) {
        _selectedStage = _stages.firstWhere(
          (s) => s.slug == _selectedStage!.slug,
          orElse: () => _stages.isNotEmpty ? _stages.first : _selectedStage!,
        );
      }
    } catch (e) {
      final failure = describeFailure(e);
      _error = failure.message;
      _errorKind = failure.kind;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Switches to a different contact type and reloads.
  Future<void> setContactType(PipelineContactType type) async {
    if (_activeType == type) return;
    _activeType = type;
    _selectedStage = null;
    _stages = [];
    _contacts = [];
    notifyListeners();
    await load();
  }

  /// Selects a stage chip to focus the list. Calling with the same stage
  /// again clears the filter back to "All".
  void selectStage(PipelineStageModel? stage) {
    if (stage == null || _selectedStage?.slug == stage.slug) {
      _selectedStage = null;
    } else {
      _selectedStage = stage;
    }
    notifyListeners();
  }
}
