/// PipelineLeadDetailScreen — opened when a lead card on the Pipeline tab is tapped.
///
/// WHAT THE EMPLOYEE SEES
///   1. A compact header: name, phone, stage, district, owner, Call and WhatsApp.
///      The full contact record is one tap away (the icon in the app bar).
///   2. Three tabs, the same three the web lead panel uses:
///        - Activity log: calls, visits, notes and completed follow-ups.
///        - Follow-ups:   open and finished tasks for this lead.
///        - History:      stage moves, owner changes and every change, read-only.
///   3. A bottom button on the first two tabs: "Log activity" or "Schedule follow-up".
///
/// THE OWNER RULE
/// The bottom button and the Mark done buttons appear only when the signed-in
/// employee owns the lead. For anyone else's lead the screen is view-only and
/// shows who owns it instead.
///
/// HOW IT FITS TOGETHER
///   - [PipelineLeadDetailScreen] creates a [LeadWorkViewModel] for this lead.
///     Its `create` callback starts the three reads in parallel.
///   - [_LeadDetailView] owns the tab controller and the bottom button.
///   - Each tab reads only its own list with `context.select`, so a change to
///     the follow-up list does not rebuild the activity or history tabs.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/lead_work.dart';
import '../../services/lead_work_service.dart';
import '../../services/pipeline_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/lead_work_view_model.dart';
import '../contacts/contact_detail_screen.dart';
import '../home/quick_action_sheets.dart';
import '../shell_scope.dart';
import 'lead_work_sheets.dart';

class PipelineLeadDetailScreen extends StatelessWidget {
  const PipelineLeadDetailScreen({
    super.key,
    required this.contact,
    required this.isHead,
  });

  /// The lead as the Pipeline list showed it. The tabs load their own data.
  final PipelineContact contact;

  /// True for admin and manager, who may add to any lead.
  final bool isHead;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final api = context.read<ApiClient>();
        final viewModel = LeadWorkViewModel(
          service: LeadWorkService(api),
          contactId: contact.id,
          ownerId: contact.assignedToId,
          currentUserId: api.currentUserId,
          isHead: isHead,
        );
        // Not awaited: the screen shows loading states until the lists arrive.
        unawaited(viewModel.load());
        return viewModel;
      },
      child: _LeadDetailView(contact: contact),
    );
  }
}

class _LeadDetailView extends StatefulWidget {
  const _LeadDetailView({required this.contact});

  final PipelineContact contact;

  @override
  State<_LeadDetailView> createState() => _LeadDetailViewState();
}

class _LeadDetailViewState extends State<_LeadDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  static const _activityTab = 0;
  static const _followupTab = 1;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _message(String text) => showToast(context, text);

  /// Opens the existing log-activity form. It saves the row itself, so this
  /// only reloads the two lists that the new row changes.
  Future<void> _logActivity() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ActivityLogSheet(
        contactId: widget.contact.id,
        contactName: widget.contact.displayName,
      ),
    );
    if (saved != true || !mounted) return;
    await context.read<LeadWorkViewModel>().refreshAfterActivity();
    if (mounted) _message('Activity logged');
  }

  Future<void> _scheduleFollowup() async {
    final viewModel = context.read<LeadWorkViewModel>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ScheduleFollowupSheet(
        viewModel: viewModel,
        contactName: widget.contact.displayName,
      ),
    );
    if (saved == true && mounted) _message('Follow-up scheduled');
  }

  Future<void> _markDone(FollowupEntry item) async {
    final viewModel = context.read<LeadWorkViewModel>();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => CompleteFollowupSheet(
        viewModel: viewModel,
        item: item,
        typeLabel: _typeLabel(viewModel, item.channel),
      ),
    );
    if (saved == true && mounted) _message('Follow-up marked done');
  }

  /// Moves an open follow-up to a new day. No time is asked for: it becomes
  /// due for the whole day (23:59), the same default the web app uses.
  Future<void> _reschedule(FollowupEntry item) async {
    final viewModel = context.read<LeadWorkViewModel>();
    final today = DateUtils.dateOnly(DateTime.now());
    final due = DateUtils.dateOnly(item.dueAt);
    final picked = await showDatePicker(
      context: context,
      initialDate: due.isBefore(today) ? today : due,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (picked == null || !mounted) return;
    final message = await viewModel.rescheduleFollowup(
      item,
      DateTime(picked.year, picked.month, picked.day, 23, 59),
    );
    if (!mounted) return;
    showToast(
      context,
      message ?? 'Follow-up rescheduled',
      isError: message != null,
    );
  }

  void _openContact() {
    pushShellRoute<void>(
      context,
      (_) => ContactDetailScreen(contactId: widget.contact.id),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          _LeadHeader(contact: widget.contact),
          Container(
            color: OgeraColors.surface,
            child: Consumer<LeadWorkViewModel>(
              builder: (context, viewModel, _) => TabBar(
                controller: _tabs,
                labelColor: OgeraColors.ink,
                unselectedLabelColor: OgeraColors.muted,
                indicatorColor: OgeraColors.blue,
                tabs: [
                  Tab(text: _countLabel('Activity log', viewModel.activities)),
                  Tab(text: _countLabel('Follow-ups', viewModel.followups)),
                  const Tab(text: 'History'),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _ActivityTab(),
                _FollowupTab(onMarkDone: _markDone, onReschedule: _reschedule),
                const _HistoryTab(),
              ],
            ),
          ),
        ],
      ),
      // The bottom button sits outside the body, so it never covers list rows.
      bottomNavigationBar: AnimatedBuilder(
        animation: _tabs,
        builder: (context, _) {
          final canWrite = context.select<LeadWorkViewModel, bool>(
            (viewModel) => viewModel.canWrite,
          );
          final onAddableTab =
              _tabs.index == _activityTab || _tabs.index == _followupTab;
          if (!canWrite || !onAddableTab) return const SizedBox.shrink();
          return _AddBar(
            label: _tabs.index == _activityTab
                ? 'Log activity'
                : 'Schedule follow-up',
            icon: _tabs.index == _activityTab
                ? Icons.edit_note_rounded
                : Icons.event_available_rounded,
            onPressed: _tabs.index == _activityTab
                ? _logActivity
                : _scheduleFollowup,
          );
        },
      ),
    );
  }
}

/// "Activity log (3)" once the list has loaded, the plain name while it loads.
String _countLabel(String name, List<Object>? items) {
  if (items == null || items.isEmpty) return name;
  return '$name (${items.length})';
}

/// The activity type label from Settings, falling back to a readable form of the stored name.
String _typeLabel(LeadWorkViewModel viewModel, String? stored) {
  if (stored == null) return 'Follow-up';
  return viewModel.activityTypeLabels[stored] ?? humanizeSlug(stored);
}

// ─────────────────────────────────────────────────────────── header

/// Minimal contact details: who the lead is, how to reach them, and who owns it.
class _LeadHeader extends StatelessWidget {
  const _LeadHeader({required this.contact});

  final PipelineContact contact;

  @override
  Widget build(BuildContext context) {
    final isOwner = context.select<LeadWorkViewModel, bool>(
      (viewModel) => viewModel.isOwner,
    );
    final canWrite = context.select<LeadWorkViewModel, bool>(
      (viewModel) => viewModel.canWrite,
    );
    final stageName = contact.stageName ?? '';
    final district = contact.district ?? '';
    final owner = contact.assignedToName;

    return Container(
      color: OgeraColors.surface,
      padding: const EdgeInsets.fromLTRB(
        OgeraSpacing.screen,
        12,
        OgeraSpacing.screen,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OgeraAvatar(
                name: contact.displayName,
                phone: contact.phone,
                size: 50,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      contact.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: OgeraColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              QuickActionButton(
                icon: Icons.call_rounded,
                tooltip: 'Call',
                onPressed: () => Launchers.call(context, contact.phone),
              ),
              QuickActionButton(
                icon: Icons.chat_rounded,
                tooltip: 'WhatsApp',
                color: const Color(0xFF25D366),
                onPressed: () => Launchers.whatsapp(context, contact.phone),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (stageName.isNotEmpty)
                StatusChip(
                  label: stageName,
                  tone: StatusTone.brand,
                  icon: Icons.flag_outlined,
                  dense: true,
                ),
              if (district.isNotEmpty)
                StatusChip(
                  label: district,
                  icon: Icons.location_city_rounded,
                  dense: true,
                ),
              StatusChip(
                label: isOwner
                    ? 'Yours'
                    : canWrite
                    ? '${owner ?? 'Unassigned'} · head access'
                    : owner == null
                    ? 'Unassigned · view only'
                    : '$owner · view only',
                icon: canWrite
                    ? Icons.person_rounded
                    : Icons.visibility_outlined,
                tone: isOwner ? StatusTone.success : StatusTone.neutral,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── bottom button

/// The one action on the first two tabs. It sits in the Scaffold's bottom bar,
/// so the list above it never sits behind it.
class _AddBar extends StatelessWidget {
  const _AddBar({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

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
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────── tabs

/// One tab's body: a loading state, an error, an empty message, or the list.
/// Pull down to reload. An error with old data keeps the data and shows a banner.
class _TabBody<T> extends StatelessWidget {
  const _TabBody({
    required this.items,
    required this.error,
    required this.onRetry,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  /// Null while the first load is still running.
  final List<T>? items;
  final String? error;
  final Future<void> Function() onRetry;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final rows = items;
    if (rows == null) {
      if (error != null) {
        return ErrorStateView(message: error!, onRetry: () => onRetry());
      }
      return const LoadingListView(itemCount: 3, itemHeight: 84);
    }
    if (rows.isEmpty) {
      return RefreshableMessage(
        onRefresh: onRetry,
        child: EmptyStateView(
          icon: emptyIcon,
          title: emptyTitle,
          message: emptyMessage,
        ),
      );
    }

    final hasBanner = error != null;
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          12,
          OgeraSpacing.screen,
          16,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.length + (hasBanner ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: OgeraSpacing.gap),
        itemBuilder: (context, index) {
          if (hasBanner) {
            if (index == 0) return _ErrorBanner(message: error!);
            return itemBuilder(context, rows[index - 1]);
          }
          return itemBuilder(context, rows[index]);
        },
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OgeraColors.dangerSoft,
        borderRadius: BorderRadius.circular(OgeraSpacing.cardRadius),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: OgeraColors.danger),
      ),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = context.select<LeadWorkViewModel, List<ActivityEntry>?>(
      (viewModel) => viewModel.activities,
    );
    final error = context.select<LeadWorkViewModel, String?>(
      (viewModel) => viewModel.activitiesError,
    );
    final viewModel = context.read<LeadWorkViewModel>();

    return _TabBody<ActivityEntry>(
      items: items,
      error: error,
      onRetry: viewModel.reloadActivities,
      emptyIcon: Icons.history_rounded,
      emptyTitle: 'No activity logged yet',
      emptyMessage:
          'Calls, visits and WhatsApp messages appear here once logged.',
      itemBuilder: (context, entry) => _ActivityCard(
        entry: entry,
        typeLabel: _typeLabel(viewModel, entry.activityType),
      ),
    );
  }
}

class _FollowupTab extends StatelessWidget {
  const _FollowupTab({required this.onMarkDone, required this.onReschedule});

  final Future<void> Function(FollowupEntry item) onMarkDone;
  final Future<void> Function(FollowupEntry item) onReschedule;

  @override
  Widget build(BuildContext context) {
    final items = context.select<LeadWorkViewModel, List<FollowupEntry>?>(
      (viewModel) => viewModel.followups,
    );
    final error = context.select<LeadWorkViewModel, String?>(
      (viewModel) => viewModel.followupsError,
    );
    final viewModel = context.read<LeadWorkViewModel>();

    return _TabBody<FollowupEntry>(
      items: items,
      error: error,
      onRetry: viewModel.reloadFollowups,
      emptyIcon: Icons.event_available_outlined,
      emptyTitle: 'No follow-ups scheduled',
      emptyMessage: 'Schedule a reminder so this lead does not go cold.',
      itemBuilder: (context, entry) {
        // Each follow-up has its own assignee, so the check is per row.
        final canChange = entry.isOpen && viewModel.canChangeFollowup(entry);
        return _FollowupCard(
          entry: entry,
          typeLabel: _typeLabel(viewModel, entry.channel),
          canChange: canChange,
          onMarkDone: () => onMarkDone(entry),
          onReschedule: () => onReschedule(entry),
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    final items = context.select<LeadWorkViewModel, List<LeadHistoryEntry>?>(
      (viewModel) => viewModel.history,
    );
    final error = context.select<LeadWorkViewModel, String?>(
      (viewModel) => viewModel.historyError,
    );
    final viewModel = context.read<LeadWorkViewModel>();

    return _TabBody<LeadHistoryEntry>(
      items: items,
      error: error,
      onRetry: viewModel.reloadHistory,
      emptyIcon: Icons.timeline_rounded,
      emptyTitle: 'No history yet',
      emptyMessage: 'Stage moves and every change to this lead appear here.',
      itemBuilder: (context, entry) => _HistoryRow(entry: entry),
    );
  }
}

// ─────────────────────────────────────────────────────────── cards

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.entry, required this.typeLabel});

  final ActivityEntry entry;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    final outcome = entry.outcome;
    final who = entry.doneByName ?? 'Unknown';
    return OgeraCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _iconFor(entry.activityType),
                size: 18,
                color: OgeraColors.blue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (outcome != null)
                StatusChip(label: humanizeSlug(outcome), dense: true),
            ],
          ),
          if ((entry.title ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entry.title!,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if ((entry.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entry.notes!,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: OgeraColors.ink,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '$who · ${formatMoment(entry.loggedAt)}',
            style: const TextStyle(fontSize: 11.5, color: OgeraColors.muted),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String type) => switch (type) {
    'phone_call' => Icons.call_outlined,
    'field_visit' => Icons.place_outlined,
    'whatsapp' => Icons.chat_outlined,
    _ => Icons.edit_note_rounded,
  };
}

class _FollowupCard extends StatelessWidget {
  const _FollowupCard({
    required this.entry,
    required this.typeLabel,
    required this.canChange,
    required this.onMarkDone,
    required this.onReschedule,
  });

  final FollowupEntry entry;
  final String typeLabel;

  /// True when the signed-in employee may mark this open follow-up done or move it.
  final bool canChange;
  final VoidCallback onMarkDone;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    final title = (entry.title ?? '').trim();
    final due = formatFullDate(entry.dueAt);
    final assignee = entry.assignedToName;

    return OgeraCard(
      padding: const EdgeInsets.all(14),
      accent: entry.isOpen ? _accentFor(entry.taskState) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? typeLabel : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StateChip(entry: entry),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$typeLabel · due $due',
            style: const TextStyle(fontSize: 13, color: OgeraColors.muted),
          ),
          if ((entry.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entry.notes!,
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ],
          if (assignee != null) ...[
            const SizedBox(height: 6),
            Text(
              'Assigned to $assignee',
              style: const TextStyle(fontSize: 11.5, color: OgeraColors.muted),
            ),
          ],
          if (canChange) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onReschedule,
                  icon: const Icon(Icons.event_repeat_rounded, size: 17),
                  label: const Text('Reschedule'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onMarkDone,
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: const Text('Mark done'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Color _accentFor(String state) => switch (state) {
    'overdue' => OgeraColors.danger,
    'due_today' => OgeraColors.warning,
    _ => OgeraColors.info,
  };
}

/// The follow-up's state as a chip: overdue, due today, upcoming or done.
class _StateChip extends StatelessWidget {
  const _StateChip({required this.entry});

  final FollowupEntry entry;

  @override
  Widget build(BuildContext context) {
    if (!entry.isOpen) {
      return const StatusChip(
        label: 'Done',
        tone: StatusTone.success,
        dense: true,
      );
    }
    return switch (entry.taskState) {
      'overdue' => StatusChip(
        label: entry.overdueDays > 0
            ? 'Overdue ${entry.overdueDays}d'
            : 'Overdue',
        tone: StatusTone.danger,
        dense: true,
      ),
      'due_today' => const StatusChip(
        label: 'Due today',
        tone: StatusTone.warning,
        dense: true,
      ),
      _ => const StatusChip(
        label: 'Upcoming',
        tone: StatusTone.info,
        dense: true,
      ),
    };
  }
}

/// One History row: what happened, who did it, and when. Read-only by design.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final LeadHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final notes = entry.notes;
    return OgeraCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OgeraColors.blueSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconFor(entry.eventType),
              size: 14,
              color: OgeraColors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.summary,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: OgeraColors.ink,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${entry.actorName ?? 'System'} · ${formatMoment(entry.timestamp)}',
                  style: const TextStyle(
                    fontSize: 11.5,
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

  static IconData _iconFor(String type) => switch (type) {
    'stage' => Icons.flag_outlined,
    'activity' => Icons.chat_bubble_outline_rounded,
    'followup' || 'followup_rescheduled' => Icons.event_outlined,
    'assignment' => Icons.person_outline_rounded,
    _ => Icons.edit_outlined,
  };
}
