import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/contact.dart';
import '../../models/followup.dart';
import '../../models/staff_location.dart';
import '../../services/location_api_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/contacts_view_model.dart';
import '../../view_models/followups_view_model.dart';
import '../../view_models/sales_view_model.dart';
import '../../view_models/session_view_model.dart';
import '../contacts/contact_detail_screen.dart';
import '../followups/lead_detail_screen.dart';
import '../map/staff_route_sheet.dart';
import '../shell_scope.dart';

/// Two dashboards behind one tab.
///
/// Head sees the team: pipeline, sales, who is in the field right now. Staff
/// see only their own day — what is overdue and what is due today, because that
/// is the entire job on a phone.
///
/// Every figure here is read from the view models the shell already loaded, so
/// opening Home costs no extra requests.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isHead = context.select<SessionViewModel, bool>(
      (session) => session.isHead,
    );
    return isHead ? const _HeadHome() : const _StaffHome();
  }
}

// ------------------------------------------------------------------ greeting

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

// ----------------------------------------------------------------- head home

class _HeadHome extends StatelessWidget {
  const _HeadHome();

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<ContactsViewModel>();
    final followups = context.watch<FollowupsViewModel>();
    final sales = context.watch<SalesViewModel>();

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(title: const Text('Overview')),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            contacts.refresh(),
            followups.refresh(),
            sales.refresh(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            200,
          ),
          children: [
            const _Greeting(),
            _MetricGrid(
              metrics: [
                _MetricData(
                  label: 'Leads',
                  value: '${contacts.leadsCount}',
                  icon: Icons.trending_up_rounded,
                  color: OgeraColors.blue,
                ),
                _MetricData(
                  label: 'Awareness',
                  value: '${contacts.awarenessCount}',
                  icon: Icons.campaign_outlined,
                  color: OgeraColors.info,
                ),
                _MetricData(
                  label: 'Revenue',
                  value: formatCompactCurrency(sales.totalRevenue),
                  icon: Icons.payments_outlined,
                  color: OgeraColors.success,
                ),
                _MetricData(
                  label: 'Tanks sold',
                  value: '${sales.totalTanks}',
                  icon: Icons.water_drop_outlined,
                  color: OgeraColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _StaffOnDuty(),
            const SizedBox(height: 20),
            _PipelineBreakdown(viewModel: followups),
            const SizedBox(height: 20),
            _RecentContacts(contacts: contacts.contacts),
          ],
        ),
      ),
    );
  }
}

/// A live strip of who is in the field. It polls once when Home opens rather
/// than continuously — the Map tab is where live monitoring belongs.
class _StaffOnDuty extends StatefulWidget {
  const _StaffOnDuty();

  @override
  State<_StaffOnDuty> createState() => _StaffOnDutyState();
}

class _StaffOnDutyState extends State<_StaffOnDuty> {
  List<StaffLocation> _staff = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final staff = await context.read<LocationApiService>().live();
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _isLoading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = _staff.where((row) => row.state == StaffState.moving).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Staff in the field',
          icon: Icons.person_pin_circle_outlined,
          action: _isLoading || _error != null
              ? null
              : StatusChip(
                  label: '$live moving',
                  tone: live > 0 ? StatusTone.success : StatusTone.neutral,
                  icon: Icons.podcasts_rounded,
                  dense: true,
                ),
        ),
        if (_isLoading)
          const ShimmerBox(height: 96)
        else if (_error != null)
          OgeraCard(
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 18,
                  color: OgeraColors.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: OgeraColors.muted,
                    ),
                  ),
                ),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          )
        else if (_staff.isEmpty)
          const OgeraCard(
            child: Text(
              'No staff have shared a location yet. Locations appear once your '
              'Sales Staff sign in on mobile and allow location sharing.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: OgeraColors.muted,
              ),
            ),
          )
        else
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _staff.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _StaffChip(staff: _staff[index]),
            ),
          ),
      ],
    );
  }
}

class _StaffChip extends StatelessWidget {
  const _StaffChip({required this.staff});

  final StaffLocation staff;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: OgeraCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        onTap: () => showStaffRouteSheet(
          context,
          staff: staff,
          // Home has no map of its own, so focusing a stop is a no-op here;
          // the sheet still opens Directions for any point.
          onFocus: (LatLng _) {},
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                OgeraAvatar(name: staff.name, size: 42, color: staff.color),
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: staff.state.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: OgeraColors.surface, width: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              staff.name.split(RegExp(r'\s+')).first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              staff.lastSeenLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: OgeraColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the pipeline actually sits, as proportional bars — the shape of the
/// funnel is the point, not the individual counts.
class _PipelineBreakdown extends StatelessWidget {
  const _PipelineBreakdown({required this.viewModel});

  final FollowupsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Pipeline', icon: Icons.view_column_outlined),
          ShimmerBox(height: 150),
        ],
      );
    }

    final stages = viewModel.stages;
    final counts = {
      for (final stage in stages) stage.id: viewModel.countInStage(stage.id),
    };
    final total = counts.values.fold(0, (sum, value) => sum + value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Pipeline',
          icon: Icons.view_column_outlined,
          action: StatusChip(
            label: total == 1 ? '1 lead' : '$total leads',
            tone: StatusTone.brand,
            dense: true,
          ),
        ),
        OgeraCard(
          child: stages.isEmpty
              ? const Text(
                  'No pipeline stages yet. Add them from the Follow-ups tab.',
                  style: TextStyle(fontSize: 13.5, color: OgeraColors.muted),
                )
              : Column(
                  children: [
                    for (final stage in stages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _StageBar(
                          label: stage.label,
                          color: stage.color,
                          count: counts[stage.id] ?? 0,
                          total: total,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar({
    required this.label,
    required this.color,
    required this.count,
    required this.total,
  });

  final String label;
  final Color color;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: OgeraColors.canvas,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _RecentContacts extends StatelessWidget {
  const _RecentContacts({required this.contacts});

  final List<Contact> contacts;

  @override
  Widget build(BuildContext context) {
    final recent = contacts.take(5).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Recent activity',
          icon: Icons.history_rounded,
        ),
        if (recent.isEmpty)
          const OgeraCard(
            child: Text(
              'New contacts will appear here as your team adds them.',
              style: TextStyle(fontSize: 13.5, color: OgeraColors.muted),
            ),
          )
        else
          OgeraCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (var index = 0; index < recent.length; index++) ...[
                  if (index > 0) const Divider(),
                  _ActivityRow(contact: recent[index]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final isLead = contact.contactType == ContactType.lead;
    return InkWell(
      onTap: () => pushShellRoute<void>(
        context,
        (_) => ContactDetailScreen(contactId: contact.id, initial: contact),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            OgeraAvatar(
              name: contact.name,
              phone: contact.phone,
              size: 38,
              color: isLead ? OgeraColors.blue : OgeraColors.info,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${isLead ? 'Lead' : 'Awareness'} · ${formatRelative(contact.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: OgeraColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: OgeraColors.muted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- staff home

class _StaffHome extends StatelessWidget {
  const _StaffHome();

  @override
  Widget build(BuildContext context) {
    final followups = context.watch<FollowupsViewModel>();
    final grouped = followups.leadsByDueBucket;
    final overdue = grouped[DueBucket.overdue]!;
    final today = grouped[DueBucket.today]!;
    final upcoming = grouped[DueBucket.upcoming]!;

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(title: const Text('My day')),
      body: RefreshIndicator(
        onRefresh: followups.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            200,
          ),
          children: [
            const _Greeting(),
            const _TrackingBanner(),
            const SizedBox(height: 16),
            _MetricGrid(
              metrics: [
                _MetricData(
                  label: 'Overdue',
                  value: '${overdue.length}',
                  icon: Icons.error_outline_rounded,
                  color: OgeraColors.danger,
                ),
                _MetricData(
                  label: 'Due today',
                  value: '${today.length}',
                  icon: Icons.today_rounded,
                  color: OgeraColors.warning,
                ),
                _MetricData(
                  label: 'Upcoming',
                  value: '${upcoming.length}',
                  icon: Icons.event_rounded,
                  color: OgeraColors.info,
                ),
                _MetricData(
                  label: 'Assigned',
                  value: '${followups.visibleLeads.length}',
                  icon: Icons.assignment_outlined,
                  color: OgeraColors.blue,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (followups.isLoading) ...[
              const SectionHeader(
                title: 'Needs attention',
                icon: Icons.priority_high_rounded,
              ),
              const LoadingListView(itemCount: 2, itemHeight: 80),
            ] else if (overdue.isEmpty && today.isEmpty) ...[
              const SectionHeader(
                title: 'Needs attention',
                icon: Icons.priority_high_rounded,
              ),
              const OgeraCard(
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (overdue.isNotEmpty)
                _TaskGroup(
                  bucket: DueBucket.overdue,
                  leads: overdue,
                  viewModel: followups,
                ),
              if (today.isNotEmpty) ...[
                if (overdue.isNotEmpty) const SizedBox(height: 20),
                _TaskGroup(
                  bucket: DueBucket.today,
                  leads: today,
                  viewModel: followups,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// A quiet, permanent reminder that location is being shared, and whether
/// anything is still waiting to reach the server.
class _TrackingBanner extends StatelessWidget {
  const _TrackingBanner();

  @override
  Widget build(BuildContext context) {
    final tracking = context.read<SessionViewModel>().tracking;

    return ValueListenableBuilder<int>(
      valueListenable: tracking.pendingCount,
      builder: (context, pending, _) {
        final isQueued = pending > 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isQueued ? OgeraColors.warningSoft : OgeraColors.successSoft,
            borderRadius: BorderRadius.circular(OgeraSpacing.cardRadius),
            border: Border.all(
              color: (isQueued ? OgeraColors.warning : OgeraColors.success)
                  .withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isQueued ? Icons.cloud_upload_outlined : Icons.podcasts_rounded,
                size: 19,
                color: isQueued ? OgeraColors.warning : OgeraColors.success,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  isQueued
                      ? '$pending location${pending == 1 ? '' : 's'} waiting to sync. '
                            'They will upload when you are back online.'
                      : 'Location sharing is on. Your route is up to date.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: isQueued ? OgeraColors.warning : OgeraColors.success,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

// ------------------------------------------------------------------- metrics

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: OgeraSpacing.gap,
      mainAxisSpacing: OgeraSpacing.gap,
      childAspectRatio: 1.4,
      children: [
        for (final metric in metrics)
          OgeraCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: metric.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(metric.icon, size: 17, color: metric.color),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metric.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: OgeraColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
