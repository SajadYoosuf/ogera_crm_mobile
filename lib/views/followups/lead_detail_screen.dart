import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/reference/crm_options.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/followup.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/followups_view_model.dart';
import '../contacts/contact_detail_screen.dart';
import '../shell_scope.dart';

/// One lead: its stage, owner, due date, notes, and the immutable history of
/// everything that has happened to it.
class LeadDetailScreen extends StatefulWidget {
  const LeadDetailScreen({super.key, required this.lead});

  final Lead lead;

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  final _noteController = TextEditingController();

  List<Remark> _history = const [];
  bool _isLoadingHistory = true;
  bool _isPostingNote = false;
  bool _isBusy = false;

  /// The board refetches after every change, so the lead is re-read from the
  /// view model rather than held as a stale copy.
  Lead get _lead {
    final viewModel = context.read<FollowupsViewModel>();
    for (final lead in viewModel.visibleLeads) {
      if (lead.id == widget.lead.id) return lead;
    }
    return widget.lead;
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await context.read<FollowupsViewModel>().history(
        widget.lead.id,
      );
      if (!mounted) return;
      setState(() {
        _history = history;
        _isLoadingHistory = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _isBusy = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error != null) {
      showToast(context, error, isError: true);
      return;
    }
    await _loadHistory();
  }

  Future<void> _changeStage() async {
    final viewModel = context.read<FollowupsViewModel>();
    final lead = _lead;
    final picked = await showOptionPicker<Stage>(
      context,
      title: 'Move to stage',
      options: viewModel.stages,
      labelOf: (stage) => stage.label,
      selected: viewModel.stageById(lead.stage),
      searchable: false,
    );
    if (picked == null || !mounted) return;

    // The qualification rule is checked before the request so the user sees
    // exactly which details are missing, not a generic refusal.
    final blockers = viewModel.blockersForStageChange(lead, picked.id);
    if (blockers.isNotEmpty) {
      await _showQualificationSheet(blockers);
      return;
    }
    await _run(() => viewModel.moveStage(lead, picked.id));
  }

  Future<void> _showQualificationSheet(List<String> blockers) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: OgeraColors.warningSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_late_outlined,
                  color: OgeraColors.warning,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Complete the lead details first',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'A lead only moves past the first stage once these are filled in:',
                textAlign: TextAlign.center,
                style: TextStyle(color: OgeraColors.muted, height: 1.45),
              ),
              const SizedBox(height: 16),
              for (final blocker in blockers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.radio_button_unchecked_rounded,
                        size: 16,
                        color: OgeraColors.warning,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        blocker,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openContact();
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Open contact to complete'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeAssignee() async {
    final viewModel = context.read<FollowupsViewModel>();
    final lead = _lead;
    final picked = await showModalBottomSheet<StaffMember?>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Assign to',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Unassigned'),
                onTap: () => Navigator.of(context).pop(null),
              ),
              for (final member in viewModel.staff)
                ListTile(
                  leading: OgeraAvatar(name: member.name, size: 36),
                  title: Text(member.name),
                  selected: lead.followupAssignedTo == member.id,
                  onTap: () => Navigator.of(context).pop(member),
                ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    await _run(() => viewModel.assign(lead, picked?.id));
  }

  Future<void> _changeDueDate() async {
    final lead = _lead;
    final picked = await showDatePicker(
      context: context,
      initialDate: lead.dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null || !mounted) return;
    await _run(
      () =>
          context.read<FollowupsViewModel>().setDueDate(lead, isoDate(picked)),
    );
  }

  Future<void> _addNote() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) return;
    setState(() => _isPostingNote = true);
    final error = await context.read<FollowupsViewModel>().addNote(
      _lead.id,
      note,
    );
    if (!mounted) return;
    setState(() => _isPostingNote = false);
    if (error != null) {
      showToast(context, error, isError: true);
      return;
    }
    _noteController.clear();
    FocusScope.of(context).unfocus();
    await _loadHistory();
  }

  void _openContact() {
    pushShellRoute<void>(
      context,
      (_) => ContactDetailScreen(contactId: _lead.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FollowupsViewModel>();
    final lead = _lead;
    final stage = viewModel.stageById(lead.stage);
    final canAssign = viewModel.canAssign;

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: const Text('Lead'),
        actions: [
          IconButton(
            tooltip: 'Open contact record',
            onPressed: _openContact,
            icon: const Icon(Icons.badge_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (_isBusy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                OgeraSpacing.screen,
                OgeraSpacing.screen,
                OgeraSpacing.screen,
                24,
              ),
              children: [
                _LeadHeader(lead: lead, stage: stage),
                const SizedBox(height: OgeraSpacing.gap),
                _PipelineControls(
                  lead: lead,
                  stage: stage,
                  assignee: viewModel.assigneeLabel(lead),
                  canAssign: canAssign,
                  onChangeStage: _changeStage,
                  onChangeAssignee: _changeAssignee,
                  onChangeDueDate: _changeDueDate,
                ),
                const SizedBox(height: OgeraSpacing.gap),
                if (!lead.isQualified) ...[
                  _QualificationBanner(
                    missing: lead.missingQualification,
                    onComplete: _openContact,
                  ),
                  const SizedBox(height: OgeraSpacing.gap),
                ],
                _LeadDetails(lead: lead),
                const SizedBox(height: OgeraSpacing.gap),
                _HistoryTimeline(
                  history: _history,
                  isLoading: _isLoadingHistory,
                ),
              ],
            ),
          ),
          _NoteComposer(
            controller: _noteController,
            isPosting: _isPostingNote,
            onSend: _addNote,
          ),
        ],
      ),
    );
  }
}

class _LeadHeader extends StatelessWidget {
  const _LeadHeader({required this.lead, required this.stage});

  final Lead lead;
  final Stage? stage;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              OgeraAvatar(
                name: lead.name,
                phone: lead.phone,
                size: 54,
                color: stage?.color ?? OgeraColors.blue,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.displayName,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lead.phone,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: OgeraColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              QuickActionButton(
                icon: Icons.call_rounded,
                tooltip: 'Call',
                onPressed: () => Launchers.call(context, lead.phone),
              ),
              QuickActionButton(
                icon: Icons.chat_rounded,
                tooltip: 'WhatsApp',
                color: const Color(0xFF25D366),
                onPressed: () => Launchers.whatsapp(context, lead.phone),
              ),
              QuickActionButton(
                icon: Icons.directions_rounded,
                tooltip: 'Directions',
                color: OgeraColors.warning,
                onPressed: lead.lat != null || (lead.address ?? '').isNotEmpty
                    ? () => Launchers.directions(
                        context,
                        latitude: lead.lat,
                        longitude: lead.lng,
                        address: lead.address,
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stage, owner, and due date — the three things a follow-up is actually
/// managed by, each one tap from the top of the screen.
class _PipelineControls extends StatelessWidget {
  const _PipelineControls({
    required this.lead,
    required this.stage,
    required this.assignee,
    required this.canAssign,
    required this.onChangeStage,
    required this.onChangeAssignee,
    required this.onChangeDueDate,
  });

  final Lead lead;
  final Stage? stage;
  final String assignee;
  final bool canAssign;
  final VoidCallback onChangeStage;
  final VoidCallback onChangeAssignee;
  final VoidCallback onChangeDueDate;

  @override
  Widget build(BuildContext context) {
    final due = lead.dueDate;
    final bucket = lead.dueBucket;

    return OgeraCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          _ControlRow(
            icon: Icons.flag_outlined,
            label: 'Stage',
            value: stage?.label ?? 'No stage',
            valueColor: stage?.color,
            onTap: onChangeStage,
          ),
          const Divider(),
          _ControlRow(
            icon: Icons.person_outline_rounded,
            label: 'Assigned to',
            value: assignee,
            // Sales Staff can update their own leads but never reassign them.
            onTap: canAssign ? onChangeAssignee : null,
            lockedHint: canAssign ? null : 'Your Sales Head manages assignment',
          ),
          const Divider(),
          _ControlRow(
            icon: Icons.event_rounded,
            label: 'Due date',
            value: due == null ? 'Not set' : formatFullDate(due),
            valueColor: due == null ? null : bucket.color,
            onTap: onChangeDueDate,
          ),
        ],
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
    this.lockedHint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;
  final String? lockedHint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: OgeraColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: OgeraColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? OgeraColors.ink,
                    ),
                  ),
                  if (lockedHint != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      lockedHint!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: OgeraColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              onTap == null
                  ? Icons.lock_outline_rounded
                  : Icons.chevron_right_rounded,
              size: onTap == null ? 16 : 20,
              color: OgeraColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _QualificationBanner extends StatelessWidget {
  const _QualificationBanner({required this.missing, required this.onComplete});

  final List<String> missing;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OgeraColors.warningSoft,
        borderRadius: BorderRadius.circular(OgeraSpacing.cardRadius),
        border: Border.all(color: OgeraColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_late_outlined,
                size: 19,
                color: OgeraColors.warning,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${missing.length} detail${missing.length == 1 ? '' : 's'} '
                  'needed to qualify',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OgeraColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            missing.join(' · '),
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: OgeraColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onComplete,
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: const Text('Complete details'),
          ),
        ],
      ),
    );
  }
}

class _LeadDetails extends StatelessWidget {
  const _LeadDetails({required this.lead});

  final Lead lead;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Lead details',
            icon: Icons.info_outline_rounded,
          ),
          DetailRow(
            label: 'Address',
            value: lead.address,
            icon: Icons.home_outlined,
          ),
          DetailRow(label: 'Panchayath', value: lead.panchayath),
          DetailRow(label: 'Ward', value: lead.ward),
          DetailRow(label: 'District', value: lead.district),
          DetailRow(
            label: 'House stage',
            value: CrmOptions.houseStageLabel(lead.houseStage),
          ),
          DetailRow(label: 'Current tank', value: lead.currentTank),
          DetailRow(label: 'Water source', value: lead.waterSource),
          DetailRow(label: 'Tank interest', value: lead.tankSizeInterest),
          DetailRow(
            label: 'Created',
            value: formatMoment(lead.createdAt),
            icon: Icons.schedule_rounded,
          ),
        ],
      ),
    );
  }
}

/// Notes and system events on one timeline, newest first. Nothing here can be
/// edited or removed — that is the point of it.
class _HistoryTimeline extends StatelessWidget {
  const _HistoryTimeline({required this.history, required this.isLoading});

  final List<Remark> history;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'History',
            icon: Icons.history_rounded,
            action: history.isEmpty
                ? null
                : StatusChip(label: '${history.length}', dense: true),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  ShimmerBox(height: 44),
                  SizedBox(height: 10),
                  ShimmerBox(height: 44),
                ],
              ),
            )
          else if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No activity yet. Notes and stage changes will appear here.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: OgeraColors.muted,
                  height: 1.45,
                ),
              ),
            )
          else
            for (var index = 0; index < history.length; index++)
              _TimelineEntry(
                remark: history[index],
                isLast: index == history.length - 1,
              ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.remark, required this.isLast});

  final Remark remark;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isSystem = remark.isSystem;
    final color = isSystem ? OgeraColors.muted : OgeraColors.blue;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(top: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSystem
                      ? Icons.auto_awesome_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 13,
                  color: color,
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 1.5, color: OgeraColors.line)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 4 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    remark.remark,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontStyle: isSystem ? FontStyle.italic : FontStyle.normal,
                      color: isSystem ? OgeraColors.muted : OgeraColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${remark.author} · ${formatMoment(remark.createdAt)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: OgeraColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Notes are append-only, so the composer sits where a chat input would — the
/// gesture matches the semantics.
class _NoteComposer extends StatelessWidget {
  const _NoteComposer({
    required this.controller,
    required this.isPosting,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isPosting;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        OgeraSpacing.screen,
        10,
        OgeraSpacing.screen,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: OgeraColors.surface,
        border: Border(top: BorderSide(color: OgeraColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 14.5),
              decoration: const InputDecoration(
                hintText: 'Add a note…',
                counterText: '',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: isPosting ? null : onSend,
              child: isPosting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
