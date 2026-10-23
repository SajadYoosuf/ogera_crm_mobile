/// PipelineViewModel manages the Pipeline tab's state.
///
/// The pipeline tab shows contacts grouped by stage. The user switches
/// between three contact types (Consumer, Partner, Dealer) via top chips,
/// then optionally filters by stage.
///
/// Consumer contacts → ContactsService (GET /contacts?contact_type=consumer)
/// Partner contacts  → ProfessionalsService (GET /contacts?contact_type=partner
///                       &profession_type=partner)
/// Dealer contacts   → ProfessionalsService (GET /contacts?contact_type=partner
///                       &profession_type=dealer)
///
/// The backend returns all rows; this view model extracts the distinct stages
/// and exposes them as chip options.
library;

import 'package:flutter/foundation.dart';

import '../services/crm_services.dart';

/// The three contact types shown on the Pipeline tab.
enum PipelineContactType {
  consumer('Consumer'),
  partner('Partner'),
  dealer('Dealer');

  const PipelineContactType(this.label);
  final String label;
}

/// A slim row the pipeline card needs, regardless of whether the underlying
/// record is a Contact (consumer) or a Professional (partner/dealer).
class PipelineEntry {
  const PipelineEntry({
    required this.id,
    required this.name,
    required this.phone,
    this.stage,
  });

  final int id;
  final String? name;
  final String phone;
  final String? stage;
}

class PipelineViewModel extends ChangeNotifier {
  PipelineViewModel({
    required ContactsService contactsService,
    required ProfessionalsService professionalsService,
  }) : _contacts = contactsService,
       _professionals = professionalsService;

  final ContactsService _contacts;
  final ProfessionalsService _professionals;

  bool _isLoading = false;
  String? _error;

  final List<PipelineEntry> _entries = [];
  PipelineContactType _contactType = PipelineContactType.consumer;
  List<String> _stages = [];
  String? _selectedStage;

  List<PipelineEntry> get entries {
    if (_selectedStage == null) return List.unmodifiable(_entries);
    return _entries.where((e) => e.stage == _selectedStage).toList();
  }

  bool get isLoading => _isLoading;
  String? get error => _error;
  PipelineContactType get contactType => _contactType;
  List<String> get stages => List.unmodifiable(_stages);
  String? get selectedStage => _selectedStage;

  /// Loads entries for the current contact type.
  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _fetchEntries();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Switches the active contact type and reloads.
  Future<void> setContactType(PipelineContactType type) async {
    if (_contactType == type) return;
    _contactType = type;
    _selectedStage = null;
    _stages = [];
    _entries.clear();
    await load();
  }

  /// Filters by a stage chip. Passing the same stage again clears the filter.
  void setStage(String? stage) {
    _selectedStage = (_selectedStage == stage) ? null : stage;
    notifyListeners();
  }

  Future<void> _fetchEntries() async {
    _entries.clear();

    if (_contactType == PipelineContactType.consumer) {
      final page = await _contacts.list(limit: 200);
      _entries.addAll(
        page.contacts.map(
          (c) => PipelineEntry(
            id: c.id,
            name: c.name,
            phone: c.phone,
            stage: c.stage,
          ),
        ),
      );
    } else {
      // Partners and dealers use the ProfessionalsService.
      // profession_type values: 'partner' and 'dealer' are the sprint's two
      // new categories. For now we pass the label as an apiValue fallback;
      // the server ignores unknown profession_type values gracefully.
      final rows = await _professionals.list();
      final typeLabel = _contactType == PipelineContactType.partner
          ? 'partner'
          : 'dealer';
      final filtered = rows.where((p) => p.type.apiValue == typeLabel).toList();
      _entries.addAll(
        filtered.map(
          (p) => PipelineEntry(
            id: p.id,
            name: p.name,
            phone: p.phone,
            // Professionals have no stage field in this version.
            stage: null,
          ),
        ),
      );
    }

    // Collect distinct non-empty stage values for the chip row.
    final seen = <String>{};
    for (final e in _entries) {
      final s = e.stage;
      if (s != null && s.isNotEmpty) seen.add(s);
    }
    _stages = seen.toList();
  }
}
