import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/staff_palette.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/performance.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/session_view_model.dart';
import '../shell_scope.dart';
import 'staff_contacts_screen.dart';

enum _Range { all, today, week, month, custom }

extension on _Range {
  String get label => switch (this) {
    _Range.all => 'All time',
    _Range.today => 'Today',
    _Range.week => 'Last 7 days',
    _Range.month => 'This month',
    _Range.custom => 'Custom',
  };
}

/// Leads and awareness records added per staff member. Heads see the team
/// ranked; a staff session gets only its own numbers (the server enforces it).
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  _Range _range = _Range.all;
  DateTimeRange? _custom;
  PerformanceReport? _report;
  bool _isLoading = true;
  String? _error;
  FailureKind _failure = FailureKind.server;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTimeRange get _dates {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_range) {
      _Range.all => DateTimeRange(start: DateTime(2000), end: today),
      _Range.today => DateTimeRange(start: today, end: today),
      _Range.week => DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
      _Range.month => DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: today,
      ),
      _Range.custom => _custom ?? DateTimeRange(start: today, end: today),
    };
  }

  Future<void> _load() async {
    final dates = _dates;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final report = await context.read<PerformanceService>().fetch(
        startDate: isoDate(dates.start),
        endDate: isoDate(dates.end),
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _failure = error.kind;
        _isLoading = false;
      });
    }
  }

  Future<void> _select(_Range range) async {
    if (range == _Range.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: now,
        initialDateRange: _custom,
      );
      if (picked == null || !mounted) return;
      _custom = picked;
    }
    setState(() => _range = range);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isHead = context.watch<SessionViewModel>().isHead;
    final dates = _dates;

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(title: Text(isHead ? 'Performance' : 'My performance')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          FilterChipBar<_Range>(
            values: _Range.values,
            labelOf: (range) => range.label,
            selected: _range,
            onSelected: _select,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OgeraSpacing.screen,
              10,
              OgeraSpacing.screen,
              4,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _range == _Range.all
                    ? 'All records to date'
                    : dates.start == dates.end
                    ? formatFullDate(dates.start)
                    : '${formatFullDate(dates.start)} – ${formatFullDate(dates.end)}',
                style: const TextStyle(fontSize: 12, color: OgeraColors.muted),
              ),
            ),
          ),
          // A refresh over existing data is shown as a thin bar, not a blank
          // screen, so the numbers never vanish while they update.
          SizedBox(
            height: 2,
            child: _isLoading && _report != null
                ? const LinearProgressIndicator(minHeight: 2)
                : null,
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  void _openContacts(String staffId, String name) {
    pushShellRoute<void>(
      context,
      (_) => StaffContactsScreen(staffId: staffId, name: name, range: _dates),
    );
  }

  Widget _body() {
    if (_isLoading && _report == null) return const _PerformanceSkeleton();
    if (_error != null && _report == null) {
      return RefreshableMessage(
        onRefresh: _load,
        child: ErrorStateView(
          message: _error!,
          kind: _failure,
          onRetry: _load,
        ),
      );
    }
    final report = _report;
    if (report == null) return const SizedBox.shrink();

    final maxTotal = report.staff.fold<int>(
      1,
      (max, member) => member.total > max ? member.total : max,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          8,
          OgeraSpacing.screen,
          32,
        ),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InlineErrorBanner(
                message: _error!,
                kind: _failure,
                onRetry: _load,
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Leads added',
                  value: report.leads,
                  color: OgeraColors.blue,
                ),
              ),
              const SizedBox(width: OgeraSpacing.gap),
              Expanded(
                child: _StatCard(
                  label: 'Awareness added',
                  value: report.awareness,
                  color: OgeraColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (report.isTeam)
            const SectionHeader(title: 'Team', icon: Icons.groups_outlined),
          if (report.isTeam && report.unattributed > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: OgeraSpacing.gap),
              child: OgeraCard(
                onTap: () => _openContacts('unattributed', 'Unattributed'),
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${report.unattributedLeads} leads and '
                        '${report.unattributedAwareness} awareness records are '
                        'older entries with no creator, so they are not '
                        'counted per person.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: OgeraColors.muted,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: OgeraColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          if (report.staff.isEmpty)
            const EmptyStateView(
              icon: Icons.insights_outlined,
              title: 'No activity',
              message: 'Nothing was added in this date range.',
            )
          else
            for (final member in report.staff) ...[
              _StaffRow(
                member: member,
                maxTotal: maxTotal,
                onTap: () => _openContacts('${member.id}', member.name),
              ),
              const SizedBox(height: OgeraSpacing.gap),
            ],
        ],
      ),
    );
  }
}

/// Same silhouette as the loaded screen (two stat cards, then staff rows), so
/// nothing jumps when the data arrives.
class _PerformanceSkeleton extends StatelessWidget {
  const _PerformanceSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        OgeraSpacing.screen,
        8,
        OgeraSpacing.screen,
        32,
      ),
      children: [
        const Row(
          children: [
            Expanded(child: ShimmerBox(height: 78)),
            SizedBox(width: OgeraSpacing.gap),
            Expanded(child: ShimmerBox(height: 78)),
          ],
        ),
        const SizedBox(height: 18),
        const ShimmerBox(height: 14, width: 80, radius: 6),
        const SizedBox(height: 12),
        for (var i = 0; i < 5; i++) ...[
          const ShimmerBox(height: 104),
          const SizedBox(height: OgeraSpacing.gap),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      accent: color,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: OgeraColors.muted),
          ),
        ],
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.member,
    required this.maxTotal,
    required this.onTap,
  });

  final StaffPerformance member;
  final int maxTotal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = StaffPalette.colorFor(member.id);
    return OgeraCard(
      accent: color,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OgeraAvatar(name: member.name, size: 40, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Text(
                '${member.total}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  if (member.leads > 0)
                    Expanded(
                      flex: member.leads,
                      child: const ColoredBox(color: OgeraColors.blue),
                    ),
                  if (member.awareness > 0)
                    Expanded(
                      flex: member.awareness,
                      child: const ColoredBox(color: OgeraColors.warning),
                    ),
                  // Empty remainder keeps bar length proportional to the top performer.
                  if (maxTotal > member.total)
                    Expanded(
                      flex: maxTotal - member.total,
                      child: const ColoredBox(color: OgeraColors.canvas),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              StatusChip(
                label: '${member.leads} leads',
                tone: StatusTone.info,
                dense: true,
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: '${member.awareness} awareness',
                tone: StatusTone.warning,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
