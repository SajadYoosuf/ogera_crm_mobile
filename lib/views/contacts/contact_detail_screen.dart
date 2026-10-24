/// Full contact record, opened from a card on the Contacts tab (or from a lead).
///
/// Beginner note: the screen loads the contact once with
/// `ContactsService.detail` and the timeline with `FollowupsService.remarks`.
/// Every change (edit, stage, note, follow-up, delete) calls the API first and
/// only then reloads, so the screen never shows a change the server rejected.
///
/// Who can change what: the rule lives in `Contact.isEditableBy`. Admins and
/// managers can edit any contact. Staff can edit only the contacts they added.
/// For everyone else the edit, stage, note, follow-up and delete controls are
/// not shown at all, so the screen never offers an action the API would refuse.
///
/// Returns `true` to the caller when something changed, so the list reloads.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/reference/crm_options.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/utils/phone_numbers.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/contact.dart';
import '../../models/followup.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/session_view_model.dart';
import 'add_contact_sheet.dart';

class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({super.key, required this.contactId, this.initial});

  final int contactId;

  /// The row from the list. Shown at once while the full record loads.
  final Contact? initial;

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

/// Which list the timeline shows: plain activity, or scheduled follow-ups.
enum _Timeline { activity, followups }

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  Contact? _contact;
  List<Remark> _entries = const [];
  bool _isLoading = true;
  String? _error;
  _Timeline _timeline = _Timeline.activity;

  /// Set once anything changes, and handed back to the list on exit.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _contact = widget.initial;
    _load();
  }

  /// Loads the full contact and its timeline. Each failure is shown on screen,
  /// not thrown, so a network drop never leaves a blank page.
  Future<void> _load() async {
    // Read the services before the first await. Reading context after a
    // screen has been closed throws, and these requests can take seconds.
    final service = context.read<ContactsService>();
    final followups = context.read<FollowupsService>();
    try {
      final contact = await service.detail(widget.contactId);
      if (!mounted) return;
      final entries = await _timelineOrEmpty(followups);
      if (!mounted) return;
      setState(() {
        _contact = contact;
        _entries = entries;
        _error = null;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  /// The timeline is secondary. If it fails, the contact details still show.
  Future<List<Remark>> _timelineOrEmpty(FollowupsService followups) async {
    try {
      return await followups.remarks(widget.contactId);
    } on ApiException {
      return const [];
    }
  }

  Future<void> _reloadTimeline() async {
    final followups = context.read<FollowupsService>();
    final entries = await _timelineOrEmpty(followups);
    if (mounted) setState(() => _entries = entries);
  }

  void _showError(ApiException error) {
    if (mounted) showToast(context, error.message, isError: true);
  }

  Future<void> _edit(Contact contact) async {
    final updated = await showEditContactSheet(context, contact);
    if (updated == null || !mounted) return;
    setState(() {
      _contact = updated;
      _changed = true;
    });
    showToast(context, 'Contact updated');
  }

  Future<void> _changeStage(Contact contact) async {
    final followups = context.read<FollowupsService>();
    final List<Stage> stages;
    try {
      stages = await followups.stages();
    } on ApiException catch (error) {
      _showError(error);
      return;
    }
    if (!mounted) return;

    final current = contact.currentStage?.stageSlug;
    final picked = await showOptionPicker<String>(
      context,
      title: 'Lead stage',
      options: [for (final stage in stages) stage.id],
      labelOf: (id) => stages
          .firstWhere(
            (stage) => stage.id == id,
            orElse: () => Stage(id: id, label: humanizeSlug(id), orderIndex: 0),
          )
          .label,
      selected: current,
      searchable: false,
    );
    if (picked == null || picked == current || !mounted) return;

    try {
      await followups.updateLead(contact.id, stage: picked);
      if (!mounted) return;
      _changed = true;
      showToast(context, 'Stage updated');
      await _load();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _addNote(Contact contact) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _NoteDialog(),
    );
    if (text == null || !mounted) return;
    try {
      await context.read<FollowupsService>().addRemark(contact.id, text);
      if (!mounted) return;
      showToast(context, 'Note added');
      await _reloadTimeline();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _scheduleFollowup(Contact contact) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    try {
      await context.read<FollowupsService>().addFollowup(
        contact.id,
        date: isoDate(picked),
        assignedTo: contact.assignedTo,
      );
      if (!mounted) return;
      showToast(context, 'Follow-up set for ${formatFullDate(picked)}');
      setState(() => _timeline = _Timeline.followups);
      await _reloadTimeline();
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  Future<void> _delete(Contact contact) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete this contact?',
      message:
          '${contact.displayName} will be removed from the CRM. This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<ContactsService>().delete(contact.id);
      if (!mounted) return;
      showToast(context, 'Contact deleted.');
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = _contact;
    if (contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contact')),
        body: _isLoading
            ? const LoadingListView()
            : ErrorStateView(
                message: _error ?? 'Contact not found',
                onRetry: _load,
              ),
      );
    }

    final session = context.watch<SessionViewModel>();
    final canEdit = contact.isEditableBy(
      userId: session.userId,
      isPrivileged: session.isPrivileged,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: OgeraColors.canvas,
        appBar: AppBar(
          backgroundColor: OgeraColors.surface,
          surfaceTintColor: Colors.transparent,
          title: Text(contact.displayName, overflow: TextOverflow.ellipsis),
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          actions: [
            if (canEdit)
              IconButton(
                tooltip: 'Edit contact',
                onPressed: () => _edit(contact),
                icon: const Icon(Icons.edit_outlined),
              ),
            if (canEdit)
              PopupMenuButton<String>(
                tooltip: 'More actions',
                onSelected: (value) {
                  if (value == 'delete') _delete(contact);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete contact',
                      style: TextStyle(color: OgeraColors.danger),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              OgeraSpacing.screen,
              12,
              OgeraSpacing.screen,
              32,
            ),
            children: [
              _HeaderCard(contact: contact, canEdit: canEdit),
              const SizedBox(height: 12),
              _QuickActions(contact: contact),
              const SizedBox(height: 12),
              _Section(
                title: 'Phone numbers',
                child: _PhoneSection(contact: contact),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Lead',
                trailing: canEdit
                    ? TextButton(
                        onPressed: () => _changeStage(contact),
                        child: const Text('Change stage'),
                      )
                    : null,
                child: _LeadSection(contact: contact),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Details',
                child: _DetailsSection(contact: contact),
              ),
              const SizedBox(height: 12),
              _TimelineSection(
                entries: _entries,
                timeline: _timeline,
                onTimelineChanged: (value) => setState(() => _timeline = value),
                canEdit: canEdit,
                onAddNote: () => _addNote(contact),
                onScheduleFollowup: () => _scheduleFollowup(contact),
              ),
              if (!canEdit) ...[
                const SizedBox(height: 14),
                const Text(
                  'You can view this contact. Only the staff who added it, '
                  'or an admin or manager, can change it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: OgeraColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header and quick actions
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.contact, required this.canEdit});

  final Contact contact;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final stage = contact.currentStage;
    return OgeraCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: OgeraColors.blueSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  initialsOf(contact.name, fallback: contact.phone),
                  style: const TextStyle(
                    color: OgeraColors.forest,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  contact.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: OgeraColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusChip(label: contact.contactType.label, dense: true),
              if (stage != null)
                StatusChip(
                  label: stage.stageName,
                  tone: stage.isLost
                      ? StatusTone.danger
                      : stage.isAware
                      ? StatusTone.info
                      : StatusTone.brand,
                  dense: true,
                ),
              StatusChip(
                label: contact.isVerified ? 'Verified' : 'Incomplete',
                tone: contact.isVerified
                    ? StatusTone.success
                    : StatusTone.warning,
                dense: true,
              ),
              if (!canEdit)
                const StatusChip(
                  label: 'View only',
                  icon: Icons.lock_outline_rounded,
                  dense: true,
                ),
            ],
          ),
          if (!contact.isVerified && contact.missingFields.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Still needed: ${contact.missingFields.map(humanizeSlug).join(', ')}',
              style: const TextStyle(
                fontSize: 12.5,
                color: OgeraColors.warning,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Call, WhatsApp and directions. Each one reads the same parsed number that
/// the phone section shows, so the buttons and the number always agree.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final hasPlace = contact.hasLocation || (contact.address ?? '').isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Launchers.call(context, contact.phone),
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text('Call'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Launchers.whatsapp(context, contact.phone),
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: const Text('WhatsApp'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: hasPlace
                ? () => Launchers.directions(
                    context,
                    latitude: contact.latitude,
                    longitude: contact.longitude,
                    address: contact.address,
                  )
                : null,
            icon: const Icon(Icons.directions_rounded, size: 18),
            label: const Text('Directions'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

/// A titled white block. [trailing] is an optional action on the right of the
/// title, such as "Change stage".
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: OgeraColors.ink,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// One label and value line. A missing value shows an em dash, so a blank
/// field is visible rather than silently absent.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = (value ?? '').trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: OgeraColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              text.isEmpty ? '—' : text,
              style: const TextStyle(fontSize: 14, color: OgeraColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every phone number the contact has, with the exact number that calls and
/// WhatsApp use. A number that cannot be parsed is flagged, not hidden.
class _PhoneSection extends StatelessWidget {
  const _PhoneSection({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final alt = (contact.phoneAlt ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PhoneTile(label: 'Mobile', raw: contact.phone),
        if (alt.isNotEmpty) _PhoneTile(label: 'Alternate', raw: alt),
      ],
    );
  }
}

class _PhoneTile extends StatelessWidget {
  const _PhoneTile({required this.label, required this.raw});

  final String label;
  final String raw;

  @override
  Widget build(BuildContext context) {
    final parsed = parseContactPhone(raw);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: OgeraColors.muted),
              ),
              const SizedBox(width: 8),
              if (parsed != null)
                StatusChip(
                  label: parsed.isGcc
                      ? 'GCC · ${parsed.countryName}'
                      : parsed.countryName,
                  tone: parsed.isGcc ? StatusTone.info : StatusTone.neutral,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            parsed?.display ?? raw,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: OgeraColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          if (parsed != null)
            // Shows the exact number the call and WhatsApp buttons use.
            Text(
              'Dials ${parsed.e164} · WhatsApp wa.me/${parsed.whatsAppDigits}',
              style: const TextStyle(fontSize: 12.5, color: OgeraColors.muted),
            )
          else
            const Text(
              'This number cannot be dialled. Edit the contact to fix it.',
              style: TextStyle(fontSize: 12.5, color: OgeraColors.warning),
            ),
        ],
      ),
    );
  }
}

class _LeadSection extends StatelessWidget {
  const _LeadSection({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final stage = contact.currentStage;
    final products = [for (final p in contact.interestedProducts) p.name];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(
          label: 'Stage',
          value: stage == null
              ? null
              : stage.changedAt == null
              ? stage.stageName
              : '${stage.stageName} · since ${formatFullDate(stage.changedAt!)}',
        ),
        _InfoRow(label: 'Lead source', value: contact.leadSource?.name),
        _InfoRow(label: 'Assigned to', value: contact.assignedEmployee?.name),
        _InfoRow(label: 'Added by', value: contact.createdByEmployee?.name),
        _InfoRow(label: 'Added on', value: formatFullDate(contact.createdAt)),
        _InfoRow(label: 'Referred by', value: contact.referralSummary),
        _InfoRow(label: 'Referrals', value: '${contact.referralsCount}'),
        _InfoRow(
          label: 'Interested in',
          value: products.isEmpty ? null : products.join(', '),
        ),
      ],
    );
  }
}

/// Fields that depend on the contact type, then the shared address fields.
class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final consumer = contact.consumerProfile;
    final partner = contact.partnerProfile;
    final dealer = contact.dealerProfile;
    final location = contact.hasLocation
        ? '${contact.latitude!.toStringAsFixed(5)}, '
              '${contact.longitude!.toStringAsFixed(5)}'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        switch (contact.contactType) {
          ContactKind.consumer => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: 'House stage',
                value: CrmOptions.houseStageLabel(consumer?.houseStage),
              ),
              _InfoRow(
                label: 'Current tank',
                value: consumer?.currentTankType == null
                    ? null
                    : humanizeSlug(consumer!.currentTankType!),
              ),
              _InfoRow(
                label: 'Tank capacity',
                value: consumer?.currentTankCapacity == null
                    ? null
                    : '${consumer!.currentTankCapacity} litres',
              ),
              _InfoRow(
                label: 'Tank age',
                value: consumer?.currentTankAge == null
                    ? null
                    : '${consumer!.currentTankAge} years',
              ),
            ],
          ),
          ContactKind.partner => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: 'Profession',
                value: partner == null
                    ? null
                    : humanizeSlug(partner.professionType),
              ),
              _InfoRow(label: 'Work area', value: partner?.workArea),
            ],
          ),
          ContactKind.dealer => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(label: 'Owner name', value: dealer?.ownerName),
              _InfoRow(label: 'Email', value: dealer?.email),
            ],
          ),
        },
        _InfoRow(label: 'District', value: contact.district),
        _InfoRow(label: 'Address', value: contact.address),
        _InfoRow(label: 'GPS location', value: location),
        _InfoRow(label: 'Notes', value: contact.notes),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Activity log and follow-ups
// ---------------------------------------------------------------------------

/// The timeline, split into two views: the activity log (notes and stage
/// changes) and the scheduled follow-ups. Both come from the same list.
class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.entries,
    required this.timeline,
    required this.onTimelineChanged,
    required this.canEdit,
    required this.onAddNote,
    required this.onScheduleFollowup,
  });

  final List<Remark> entries;
  final _Timeline timeline;
  final ValueChanged<_Timeline> onTimelineChanged;
  final bool canEdit;
  final VoidCallback onAddNote;
  final VoidCallback onScheduleFollowup;

  @override
  Widget build(BuildContext context) {
    final rows = timeline == _Timeline.followups
        ? entries.where((entry) => entry.isFollowup).toList()
        : entries.where((entry) => !entry.isFollowup).toList();

    return _Section(
      title: 'Activity & follow-ups',
      trailing: canEdit
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: onAddNote, child: const Text('Add note')),
                TextButton(
                  onPressed: onScheduleFollowup,
                  child: const Text('Follow-up'),
                ),
              ],
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          SegmentedButton<_Timeline>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _Timeline.activity,
                label: Text('Activity log'),
              ),
              ButtonSegment(
                value: _Timeline.followups,
                label: Text('Follow-ups'),
              ),
            ],
            selected: {timeline},
            onSelectionChanged: (value) => onTimelineChanged(value.first),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                timeline == _Timeline.followups
                    ? 'No follow-ups scheduled yet.'
                    : 'No activity recorded yet.',
                style: const TextStyle(fontSize: 13, color: OgeraColors.muted),
              ),
            )
          else
            for (final entry in rows) _TimelineRow(entry: entry),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry});

  final Remark entry;

  @override
  Widget build(BuildContext context) {
    final icon = entry.isFollowup
        ? Icons.event_rounded
        : entry.isSystem
        ? Icons.swap_horiz_rounded
        : Icons.notes_rounded;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: OgeraColors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.remark,
                  style: const TextStyle(fontSize: 14, color: OgeraColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.author} · ${formatMoment(entry.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: OgeraColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for a note. The controller lives in this widget, so it is disposed
/// only after the dialog has closed.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add note'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'What happened on the call or visit?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            Navigator.of(context).pop(text.isEmpty ? null : text);
          },
          child: const Text('Save note'),
        ),
      ],
    );
  }
}
