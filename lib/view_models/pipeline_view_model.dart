/// PipelineViewModel manages state for the Pipeline tab.
///
/// ## What the Pipeline tab shows
/// The user sees contacts bucketed into pipeline stages for one contact type
/// at a time. They switch between Consumer and Partner with chips at
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

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../local_db/pipeline_cache.dart';
import '../services/pipeline_service.dart';

// ─── contact type enum ─────────────────────────────────────────────────────

/// Which of the two contact-type boards is open.
enum PipelineContactType {
  consumer('Consumer', 'consumer'),
  partner('Partner', 'partner');

  const PipelineContactType(this.label, this.apiValue);

  final String label;
  final String apiValue; // the value sent in contact_type= query param
}

// ─── view model ────────────────────────────────────────────────────────────

class PipelineViewModel extends ChangeNotifier {
  PipelineViewModel(this._service, {PipelineCache? cache})
    : _cache = cache ?? PipelineCache();

  final PipelineService _service;
  final PipelineCache _cache;

  // ── state ────────────────────────────────────────────────────────────────

  bool _isLoading = false;
  bool _isOffline = false;
  String? _error;
  FailureKind? _errorKind;
  int _latestLoad = 0;

  PipelineContactType _activeType = PipelineContactType.consumer;

  /// Ordered stages from the API for the current contact type.
  List<PipelineStageModel> _stages = [];

  /// All contacts for the current type, unsorted.
  List<PipelineContact> _contacts = [];

  /// The selected stage. Null means "All" — show every contact.
  PipelineStageModel? _selectedStage;

  // ── getters ──────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  /// True when the last load fell back to the local cache (no internet).
  bool get isOffline => _isOffline;
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
    final request = ++_latestLoad;
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
      if (request != _latestLoad) return;
      _stages = results[0] as List<PipelineStageModel>;
      _contacts = results[1] as List<PipelineContact>;
      _isOffline = false;
      // Keep selected stage valid after reload.
      if (_selectedStage != null) {
        _selectedStage = _stages.firstWhere(
          (s) => s.slug == _selectedStage!.slug,
          orElse: () => _stages.isNotEmpty ? _stages.first : _selectedStage!,
        );
      }
      // Cache the contacts so the board works offline next time.
      await _cache.save(contactType: typeValue, contacts: _contacts);
    } on SocketException {
      // No internet — serve the cached contacts so the board is still usable.
      if (request != _latestLoad) return;
      final cached = await _cache.load(contactType: _activeType.apiValue);
      _contacts = cached;
      _isOffline = true;
      _error = cached.isEmpty ? 'No internet connection.' : null;
      _errorKind = cached.isEmpty ? FailureKind.offline : null;
    } catch (e) {
      if (request != _latestLoad) return;
      final failure = describeFailure(e);
      _error = failure.message;
      _errorKind = failure.kind;
      _isOffline = false;
    } finally {
      if (request == _latestLoad) {
        _isLoading = false;
        notifyListeners();
      }
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
