/// Stats for the Home tab: a Today / This Week / This Month switch and four KPI
/// tiles for the chosen range.
///
/// Switching range only changes what is shown. All three ranges were loaded
/// when the tab opened, so there is no network call.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../services/home_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/home_view_model.dart';

class StatsRow extends StatelessWidget {
  const StatsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterChipBar<KpiRange>(
          values: KpiRange.values,
          selected: home.range,
          labelOf: (range) => range.label,
          onSelected: home.setRange,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        _body(context, home),
      ],
    );
  }

  /// Loading, error, or the four tiles. Nothing shows as a blank card.
  Widget _body(BuildContext context, HomeViewModel home) {
    if (home.isLoading) return const ShimmerBox(height: 170);
    if (home.error != null) {
      return ErrorStateView(
        message: home.errorKind == FailureKind.offline
            ? 'Check your internet connection, then try again.'
            : 'We could not load your numbers. Please try again.',
        kind: home.errorKind ?? FailureKind.server,
        onRetry: home.load,
      );
    }
    return _KpiGrid(kpis: home.kpis);
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});

  final DashboardKpis kpis;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _KpiData(
        label: 'New leads',
        value: kpis.newLeads,
        icon: Icons.person_add_alt_rounded,
        color: OgeraColors.forestInteractive,
      ),
      _KpiData(
        label: 'Open follow-ups',
        value: kpis.openFollowups,
        icon: Icons.event_note_rounded,
        color: OgeraColors.info,
      ),
      _KpiData(
        label: 'Overdue',
        value: kpis.overdueFollowups,
        icon: Icons.error_outline_rounded,
        color: OgeraColors.danger,
      ),
      _KpiData(
        label: 'Won',
        value: kpis.won,
        icon: Icons.emoji_events_rounded,
        color: OgeraColors.success,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: OgeraSpacing.gap,
      mainAxisSpacing: OgeraSpacing.gap,
      childAspectRatio: 1.4,
      children: [for (final tile in tiles) _KpiTile(data: tile)],
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    // Icon on the left, value and label on the right. A row needs less height
    // than a stacked column, so the tile fits the narrow phone grid cells.
    return OgeraCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, size: 17, color: data.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data.value}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                Text(
                  data.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
