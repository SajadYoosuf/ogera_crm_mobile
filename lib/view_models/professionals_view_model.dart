import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/professional.dart';
import '../services/crm_services.dart';

enum ProfessionalSort { newest, name }

class ProfessionalsViewModel extends ChangeNotifier {
  ProfessionalsViewModel(this._service);

  final ProfessionalsService _service;

  static const _debounce = Duration(milliseconds: 350);

  final List<Professional> _professionals = [];
  Timer? _debounceTimer;
  int _sequence = 0;

  bool _isLoading = true;
  String? _error;
  FailureKind? _errorKind;
  String _query = '';

  /// `null` means every profession — the list endpoint filters one type at a
  /// time, so the service fans out and merges.
  ProfessionalType? _type;
  ProfessionalSort _sort = ProfessionalSort.newest;

  List<Professional> get professionals => List.unmodifiable(_professionals);
  bool get isLoading => _isLoading;
  String? get error => _error;
  FailureKind? get errorKind => _errorKind;
  String get query => _query;
  ProfessionalType? get type => _type;
  ProfessionalSort get sort => _sort;
  int get total => _professionals.length;

  int countFor(ProfessionalType type) =>
      _professionals.where((item) => item.type == type).length;

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      _errorKind = null;
      notifyListeners();
    }
    final sequence = ++_sequence;
    try {
      final result = await _service.list(
        type: _type,
        query: _query.isEmpty ? null : _query,
      );
      if (sequence != _sequence) return;
      _professionals
        ..clear()
        ..addAll(result);
      _applySort();
      _error = null;
      _errorKind = null;
    } on ApiException catch (error) {
      if (sequence != _sequence) return;
      _error = error.message;
      _errorKind = error.kind;
      _professionals.clear();
    } finally {
      if (sequence == _sequence) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() => load(silent: true);

  void search(String value) {
    _query = value.trim();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => load());
  }

  void selectType(ProfessionalType? type) {
    if (_type == type) return;
    _type = type;
    load();
  }

  void setSort(ProfessionalSort sort) {
    if (_sort == sort) return;
    _sort = sort;
    _applySort();
    notifyListeners();
  }

  void _applySort() {
    _professionals.sort(
      (a, b) => switch (_sort) {
        ProfessionalSort.newest => b.createdAt.compareTo(a.createdAt),
        ProfessionalSort.name => a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        ),
      },
    );
  }

  void upsert(Professional professional) {
    final index = _professionals.indexWhere(
      (item) => item.id == professional.id,
    );
    if (index == -1) {
      _professionals.insert(0, professional);
    } else {
      _professionals[index] = professional;
    }
    _applySort();
    notifyListeners();
  }

  void removeById(int id) {
    _professionals.removeWhere((professional) => professional.id == id);
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

class ProfessionalFormViewModel extends ChangeNotifier {
  ProfessionalFormViewModel(this._service, {Professional? existing})
    : _existing = existing,
      draft = existing == null
          ? ProfessionalDraft(phone: '')
          : ProfessionalDraft.fromProfessional(existing);

  final ProfessionalsService _service;
  final Professional? _existing;
  final ProfessionalDraft draft;

  bool _isSaving = false;
  String? _error;

  bool get isEditing => _existing != null;
  bool get isSaving => _isSaving;
  String? get error => _error;

  String? validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Enter a phone number.';
    if (digits.length < 10) return 'Enter at least 10 digits.';
    return null;
  }

  void setType(ProfessionalType type) {
    draft.type = type;
    notifyListeners();
  }

  void setLocation({String? latitude, String? longitude, String? address}) {
    draft.latitude = latitude;
    draft.longitude = longitude;
    if (address != null && address.isNotEmpty) draft.address = address;
    notifyListeners();
  }

  /// The API requires a district and an address on every contact.
  String? validateBeforeSave() {
    if ((draft.district ?? '').trim().isEmpty) return 'Select the district.';
    if ((draft.address ?? '').trim().isEmpty) return 'Enter the address.';
    return null;
  }

  Future<Professional?> save() async {
    final problem = validateBeforeSave();
    if (problem != null) {
      _error = problem;
      notifyListeners();
      return null;
    }
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      return _existing == null
          ? await _service.create(draft)
          : await _service.update(_existing.id, draft);
    } on ApiException catch (error) {
      _error = error.message;
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
