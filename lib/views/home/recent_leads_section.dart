/// Recent Leads section for the Home tab.
///
/// WHAT IT DOES:
///   Shows the 10 most recently added consumer contacts, filtered by the
///   selected time period (Today / This Week / This Month). Tapping a card
///   opens a quick-look bottom sheet — no route push — so the user keeps the
///   home context.
///
/// WHY NOT FOLLOW-UPS?
///   Follow-ups are grouped by due date (overdue / today / upcoming). This
///   section is about *recency* — which leads were added most recently — so
///   it draws from a different API call in HomeViewModel.
///
/// STATE:
///   Reads [HomeViewModel.recentLeads], [HomeViewModel.recentLeadsRange], and
///   [HomeViewModel.isRecentLeadsLoading]. Calls
///   [HomeViewModel.setRecentLeadsRange] when the user taps a chip.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/followup.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/home_view_model.dart';
import 'lead_preview_sheet.dart';

class RecentLeadsSection extends StatelessWidget {
  const RecentLeadsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Period filter chips ──────────────────────────────────────────────
        FilterChipBar<KpiRange>(
          values: KpiRange.values,
          selected: home.recentLeadsRange,
          labelOf: (r) => r.label,
          onSelected: home.setRecentLeadsRange,
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        // ── Body ─────────────────────────────────────────────────────────────
        _body(context, home),
      ],
    );
  }

  Widget _body(BuildContext context, HomeViewModel home) {
    if (home.isRecentLeadsLoading) {
      // Three shimmer placeholders while the first fetch runs.
      return const Column(
        children: [
          ShimmerBox(height: 72),
          SizedBox(height: 10),
          ShimmerBox(height: 72),
          SizedBox(height: 10),
          ShimmerBox(height: 72),
        ],
      );
    }

    if (home.recentLeadsError != null) {
      return ErrorStateView(
        message: 'Could not load recent leads.',
        onRetry: () => home.setRecentLeadsRange(home.recentLeadsRange),
      );
    }

    if (home.recentLeads.isEmpty) {
      return const _EmptyLeads();
    }

    return Column(
      children: [
        for (final lead in home.recentLeads) ...[
          _LeadRow(lead: lead),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// One lead card in the recent list.
///
/// Shows name + added time, phone, contact type chip, and assigned staff.
/// Taps open [LeadPreviewSheet] as a bottom sheet.
class _LeadRow extends StatelessWidget {
  const _LeadRow({required this.lead});

  final Lead lead;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      accent: OgeraColors.forestInteractive,
      padding: const EdgeInsets.fromLTRB(13, 12, 12, 12),
      onTap: () => showLeadPreview(context, lead),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: avatar
          OgeraAvatar(
            name: lead.name,
            phone: lead.phone,
            color: OgeraColors.forestInteractive,
            size: 40,
          ),
          const SizedBox(width: 12),
          // Center: name, phone, chips
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row + time ago
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lead.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatRelative(lead.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: OgeraColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Phone
                Text(
                  lead.phone,
                  style: const TextStyle(
                    fontSize: 13,
                    color: OgeraColors.muted,
                  ),
                ),
                const SizedBox(height: 6),
                // Chips row: type + district + assigned staff
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const StatusChip(
                      label: 'Consumer',
                      tone: StatusTone.info,
                      dense: true,
                    ),
                    if (lead.district != null)
                      StatusChip(
                        label: lead.district!,
                        dense: true,
                      ),
                    if (lead.followupAssignedTo != null)
                      StatusChip(
                        label: lead.followupAssignedTo!,
                        icon: Icons.person_outline_rounded,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: OgeraColors.muted),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Shown when no leads were added in the selected period.
class _EmptyLeads extends StatelessWidget {
  const _EmptyLeads();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.eco_outlined,
              size: 36,
              color: OgeraColors.forestInteractive.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'No leads added in this period',
              style: TextStyle(fontSize: 14, color: OgeraColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
