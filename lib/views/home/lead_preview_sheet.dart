/// Bottom sheet that shows a quick preview of a lead/contact from the home
/// tab's "Recent Leads" list.
///
/// WHY A BOTTOM SHEET?
///   Tapping a lead on the home screen should not push a full route — the user
///   wants a quick glance, not a navigation jump. A DraggableScrollableSheet at
///   85 % height gives enough room without losing context.
///
/// INPUTS:
///   [lead] — the Lead model selected from the home tab.
///   [stageName] — optional human label for the stage slug on the lead.
///
/// OUTPUTS: none (read-only preview; actions live on LeadDetailScreen).
library;

import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../models/followup.dart';
import '../../theme/ogera_colors.dart';

/// Opens [LeadPreviewSheet] as a modal bottom sheet.
///
/// Pass [stageName] when you have already resolved the stage slug to a human
/// label (e.g. from [FollowupsViewModel.stageById]).
Future<void> showLeadPreview(
  BuildContext context,
  Lead lead, {
  String? stageName,
  Color? stageColor,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => LeadPreviewSheet(
      lead: lead,
      stageName: stageName,
      stageColor: stageColor,
    ),
  );
}

/// The draggable bottom sheet content for a lead preview.
class LeadPreviewSheet extends StatelessWidget {
  const LeadPreviewSheet({
    super.key,
    required this.lead,
    this.stageName,
    this.stageColor,
  });

  final Lead lead;
  final String? stageName;
  final Color? stageColor;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // ── Drag handle (matches BottomSheetTheme) ──────────────────────
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: OgeraColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OgeraSpacing.screen,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OgeraAvatar(
                    name: lead.name,
                    phone: lead.phone,
                    color: OgeraColors.forestInteractive,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          lead.phone,
                          style: const TextStyle(
                            fontSize: 14,
                            color: OgeraColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (stageName != null)
                    StatusChip(
                      label: stageName!,
                      color: stageColor,
                      dense: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            // ── Scrollable detail rows ───────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  OgeraSpacing.screen,
                  12,
                  OgeraSpacing.screen,
                  32,
                ),
                children: [
                  // Contact type — always Consumer for leads fetched here
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Type',
                    value: 'Consumer',
                  ),
                  if (lead.district != null)
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'District',
                      value: lead.district!,
                    ),
                  if (lead.address != null)
                    _InfoRow(
                      icon: Icons.home_outlined,
                      label: 'Address',
                      value: lead.address!,
                    ),
                  _InfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Added',
                    value: '${formatFullDate(lead.createdAt)}'
                        ' · ${formatRelative(lead.createdAt)}',
                  ),
                  if (lead.followupAssignedTo != null)
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Assigned to',
                      value: lead.followupAssignedTo!,
                    ),
                  if (lead.houseStage != null)
                    _InfoRow(
                      icon: Icons.construction_outlined,
                      label: 'House stage',
                      value: humanizeSlug(lead.houseStage!),
                    ),
                  if (lead.remarks != null && lead.remarks!.trim().isNotEmpty)
                    _InfoRow(
                      icon: Icons.notes_rounded,
                      label: 'Remarks',
                      value: lead.remarks!,
                    ),
                  // ── Missing fields warning ─────────────────────────────
                  if (lead.missingFields.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _MissingFieldsBanner(fields: lead.missingQualification),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// One labelled detail row: icon + label on the left, value on the right.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: OgeraColors.muted),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: OgeraColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Yellow banner listing any qualification fields the API still expects.
///
/// A lead is blocked from advancing in the pipeline until these are filled.
class _MissingFieldsBanner extends StatelessWidget {
  const _MissingFieldsBanner({required this.fields});

  final List<String> fields;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OgeraColors.warningSoft,
        borderRadius: BorderRadius.circular(OgeraSpacing.chipRadius),
        border: Border.all(
          color: OgeraColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 17,
            color: OgeraColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Missing: ${fields.join(', ')}',
              style: const TextStyle(
                fontSize: 13,
                color: OgeraColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
