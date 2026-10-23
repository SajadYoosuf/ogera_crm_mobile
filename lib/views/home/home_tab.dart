import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/followup.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/followups_view_model.dart';
import '../../view_models/home_view_model.dart';
import '../../view_models/session_view_model.dart';
import '../followups/lead_detail_screen.dart';
import '../shell_scope.dart';
import 'checkin_button.dart';
import 'stats_row.dart';

/// Home tab: greeting, the check-in card, the stats for the chosen range, and
/// the follow-ups that need attention today.
///
/// The shell loads the KPIs, attendance and follow-ups when the tab first
/// opens. Pull down to reload all of them.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) => const _StaffHome();
}

// ─────────────────────────────────────────────────────────────────────────────

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionViewModel>().user;
    if (user == null) return const SizedBox.shrink();

    final hour = DateTime.now().hour;
    final salutation = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final firstName = user.name.split(RegExp(r'\s+')).first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$salutation, $firstName',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatFullDate(DateTime.now()),
                  style: const TextStyle(
                    fontSize: 13,
                    color: OgeraColors.muted,
                  ),
                ),
              ],
            ),
          ),
          StatusChip(
            label: user.role.label,
            tone: user.isHead ? StatusTone.brand : StatusTone.info,
            icon: user.isHead ? Icons.insights_rounded : Icons.badge_outlined,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StaffHome extends StatelessWidget {
  const _StaffHome();

  @override
  Widget build(BuildContext context) {
    final home = context.read<HomeViewModel>();
    final followups = context.watch<FollowupsViewModel>();

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(title: const Text('Home')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([home.load(), followups.refresh()]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            120,
          ),
          children: [
            const _Greeting(),
            const CheckinCard(),
            const SizedBox(height: 20),
            const StatsRow(),
            const SizedBox(height: 20),
            const _NeedsAttention(),
          ],
        ),
      ),
    );
  }
}

/// Overdue and due-today follow-ups. Each group shows at most four cards.
class _NeedsAttention extends StatelessWidget {
  const _NeedsAttention();

  @override
  Widget build(BuildContext context) {
    final followups = context.watch<FollowupsViewModel>();
    final grouped = followups.leadsByDueBucket;
    final overdue = grouped[DueBucket.overdue]!;
    final today = grouped[DueBucket.today]!;

    if (followups.isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Needs attention',
            icon: Icons.priority_high_rounded,
          ),
          LoadingListView(itemCount: 2, itemHeight: 80),
        ],
      );
    }

    if (overdue.isEmpty && today.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Needs attention',
            icon: Icons.priority_high_rounded,
          ),
          OgeraCard(
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: OgeraColors.success,
                  size: 22,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nothing overdue and nothing due today. Well done.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (overdue.isNotEmpty)
          _TaskGroup(
            bucket: DueBucket.overdue,
            leads: overdue,
            viewModel: followups,
          ),
        if (overdue.isNotEmpty && today.isNotEmpty) const SizedBox(height: 20),
        if (today.isNotEmpty)
          _TaskGroup(
            bucket: DueBucket.today,
            leads: today,
            viewModel: followups,
          ),
      ],
    );
  }
}

class _TaskGroup extends StatelessWidget {
  const _TaskGroup({
    required this.bucket,
    required this.leads,
    required this.viewModel,
  });

  final DueBucket bucket;
  final List<Lead> leads;
  final FollowupsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: bucket.label,
          icon: bucket.icon,
          action: StatusChip(
            label: '${leads.length}',
            color: bucket.color,
            dense: true,
          ),
        ),
        for (final lead in leads.take(4)) ...[
          _TaskCard(lead: lead, bucket: bucket, viewModel: viewModel),
          const SizedBox(height: 10),
        ],
        if (leads.length > 4)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${leads.length - 4} more in the Follow-ups tab',
              style: const TextStyle(fontSize: 12.5, color: OgeraColors.muted),
            ),
          ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.lead,
    required this.bucket,
    required this.viewModel,
  });

  final Lead lead;
  final DueBucket bucket;
  final FollowupsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final stage = viewModel.stageById(lead.stage);
    final due = lead.dueDate;

    return OgeraCard(
      accent: bucket.color,
      onTap: () =>
          pushShellRoute<void>(context, (_) => LeadDetailScreen(lead: lead)),
      padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lead.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    if (stage != null) ...[
                      StatusChip(
                        label: stage.label,
                        color: stage.color,
                        dense: true,
                      ),
                      const SizedBox(width: 7),
                    ],
                    if (due != null)
                      Text(
                        formatDayMonth(due),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: bucket.color,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: OgeraColors.muted),
        ],
      ),
    );
  }
}
