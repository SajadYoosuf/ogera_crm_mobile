import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/auth_session.dart';
import '../models/followup.dart';
import '../services/crm_services.dart';

/// The follow-up board and the staff task list are the same data seen two ways,
/// so one view model serves both. Role decides the shape, never the screen.
class FollowupsViewModel extends ChangeNotifier {
  FollowupsViewModel(this._service, this._staffService, this._user);

  final FollowupsService _service;
  final StaffDirectoryService _staffService;
  final AuthUser _user;

  final List<Lead> _leads = [];
  final List<Stage> _stages = [];
  final List<StaffMember> _staff = [];

  bool _isLoading = true;
  String? _error;
  String _query = '';
  String? _assigneeFilter;

  List<Stage> get stages => List.unmodifiable(_stages);
  List<StaffMember> get staff => List.unmodifiable(_staff);
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get query => _query;
  String? get assigneeFilter => _assigneeFilter;
  bool get canAssign => _user.isHead;
  bool get canManageStages => _user.isHead;
  bool get canFilterByAssignee => _user.isHead;

  /// Everyone can see the full follow-up pipeline. Staff-only restrictions are
  /// applied to mutations, not to read visibility.
  List<Lead> get visibleLeads {
    Iterable<Lead> leads = _leads;
    if (_assigneeFilter != null) {
      leads = leads.where((lead) => lead.followupAssignedTo == _assigneeFilter);
    }
    if (_query.isNotEmpty) {
      final needle = _query.toLowerCase();
      final digits = _query.replaceAll(RegExp(r'\D'), '');
      leads = leads.where((lead) {
        final name = (lead.name ?? '').toLowerCase();
        final phone = lead.phone.replaceAll(RegExp(r'\D'), '');
        return name.contains(needle) ||
            (digits.isNotEmpty && phone.contains(digits)) ||
            (lead.panchayath ?? '').toLowerCase().contains(needle);
      });
    }
    return leads.toList(growable: false);
  }

  List<Lead> get assignedLeads =>
      _leads.where(isAssignedToMe).toList(growable: false);

  bool isAssignedToMe(Lead lead) {
    if (lead.followupAssignedUserId != null) {
      return lead.followupAssignedUserId == _user.id;
    }
    // Legacy rows carry only the display assignee, which stores the user id as
    // a string on the web board.
    return lead.followupAssignedTo == _user.id.toString() ||
        lead.followupAssignedTo == _user.name;
  }

  bool canUpdateLead(Lead lead) => _user.isHead || isAssignedToMe(lead);
  bool canDeleteLead(Lead lead) => canUpdateLead(lead);

  List<Lead> leadsInStage(String stageId) => visibleLeads
      .where((lead) => (lead.stage ?? '') == stageId)
      .toList(growable: false);

  int countInStage(String stageId) => leadsInStage(stageId).length;

  Map<DueBucket, List<Lead>> get leadsByDueBucket => _groupByDue(visibleLeads);

  /// The staff home still reports only the current user's own workload.
  Map<DueBucket, List<Lead>> get assignedLeadsByDueBucket =>
      _groupByDue(assignedLeads);

  Map<DueBucket, List<Lead>> _groupByDue(Iterable<Lead> source) {
    final grouped = <DueBucket, List<Lead>>{
      for (final bucket in DueBucket.values) bucket: <Lead>[],
    };
    for (final lead in source) {
      grouped[lead.dueBucket]!.add(lead);
    }
    for (final list in grouped.values) {
      list.sort((a, b) {
        final left = a.dueDate;
        final right = b.dueDate;
        if (left == null && right == null) {
          return b.createdAt.compareTo(a.createdAt);
        }
        if (left == null) return 1;
        if (right == null) return -1;
        return left.compareTo(right);
      });
    }
    return grouped;
  }

  int get overdueCount => assignedLeadsByDueBucket[DueBucket.overdue]!.length;
  int get dueTodayCount => assignedLeadsByDueBucket[DueBucket.today]!.length;

  Stage? stageById(String? id) {
    if (id == null) return null;
    for (final stage in _stages) {
      if (stage.id == id) return stage;
    }
    return null;
  }

  String stageLabel(String? id) => stageById(id)?.label ?? 'No stage';

  String assigneeLabel(Lead lead) {
    final assigned = lead.followupAssignedTo;
    if (assigned == null || assigned.isEmpty) return 'Unassigned';
    for (final member in _staff) {
      if (member.id == assigned) return member.name;
    }
    return assigned;
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final results = await Future.wait([
        _service.leads(),
        _service.stages(),
        _staffService.list(),
      ]);
      _leads
        ..clear()
        ..addAll(results[0] as List<Lead>);
      _stages
        ..clear()
        ..addAll(results[1] as List<Stage>);
      _staff
        ..clear()
        ..addAll(results[2] as List<StaffMember>);
      _error = null;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(silent: true);

  void search(String value) {
    _query = value.trim();
    notifyListeners();
  }

  void filterByAssignee(String? staffId) {
    _assigneeFilter = staffId;
    notifyListeners();
  }

  /// Guards the qualification rule before touching the network: a lead may not
  /// leave the first stage until its five qualifying details are filled.
  List<String> blockersForStageChange(Lead lead, String targetStageId) {
    if (!canUpdateLead(lead)) return const [];
    if (_stages.isEmpty) return const [];
    final first = _stages.first;
    final leavingFirst =
        (lead.stage ?? first.id) == first.id && targetStageId != first.id;
    if (!leavingFirst) return const [];
    return lead.missingQualification;
  }

  Future<String?> moveStage(Lead lead, String stageId) async {
    final denied = _assignedOnlyError(lead);
    if (denied != null) return denied;
    final blockers = blockersForStageChange(lead, stageId);
    if (blockers.isNotEmpty) {
      return 'Complete ${blockers.join(', ')} before moving this lead forward.';
    }
    return _apply(lead.id, () => _service.updateLead(lead.id, stage: stageId));
  }

  Future<String?> assign(Lead lead, String? staffId) {
    if (!canAssign) {
      return Future.value('Only Admin or Sales Head can reassign follow-ups.');
    }
    return _apply(
      lead.id,
      () => _service.updateLead(
        lead.id,
        assignedTo: staffId,
        clearAssignee: staffId == null,
      ),
    );
  }

  Future<String?> setDueDate(Lead lead, String? dueDate) {
    final denied = _assignedOnlyError(lead);
    if (denied != null) return Future.value(denied);
    return _apply(
      lead.id,
      () => _service.updateLead(
        lead.id,
        dueDate: dueDate,
        clearDueDate: dueDate == null,
      ),
    );
  }

  /// Every mutation refetches the lead list, because the API also writes system
  /// history rows that the detail timeline needs to show.
  Future<String?> _apply(int leadId, Future<void> Function() action) async {
    try {
      await action();
      await refresh();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> addNote(int leadId, String note) async {
    final lead = _leadById(leadId);
    if (lead != null) {
      final denied = _assignedOnlyError(lead);
      if (denied != null) return denied;
    } else if (_user.isStaff) {
      return 'Only the assigned staff member can update this follow-up.';
    }
    try {
      await _service.addRemark(leadId, note);
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<List<Remark>> history(int leadId) => _service.remarks(leadId);

  Future<String?> deleteLead(Lead lead) async {
    final denied = _assignedOnlyError(lead);
    if (denied != null) return denied;
    try {
      await _service.deleteLead(lead.id);
      _leads.removeWhere((item) => item.id == lead.id);
      notifyListeners();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> createStage(String label) async {
    if (!canManageStages) return 'Only Admin or Sales Head can manage stages.';
    try {
      await _service.createStage(label);
      await refresh();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> renameStage(String id, String label) async {
    if (!canManageStages) return 'Only Admin or Sales Head can manage stages.';
    try {
      await _service.updateStage(id, label: label);
      await refresh();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> reorderStage(String id, int orderIndex) async {
    if (!canManageStages) return 'Only Admin or Sales Head can manage stages.';
    try {
      await _service.updateStage(id, orderIndex: orderIndex);
      await refresh();
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Lead? _leadById(int leadId) {
    for (final lead in _leads) {
      if (lead.id == leadId) return lead;
    }
    return null;
  }

  String? _assignedOnlyError(Lead lead) {
    if (canUpdateLead(lead)) return null;
    return 'Only the assigned staff member can update this follow-up.';
  }
}
