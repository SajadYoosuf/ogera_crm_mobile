/// PipelineLeadCard — one contact row on the Pipeline tab.
///
/// WHAT IT SHOWS:
///   - Display name and phone number.
///   - Current pipeline stage chip (colour-coded by stage slug).
///   - District tag and an "unverified" warning when details are incomplete.
///   - Assigned-to label at the bottom.
///   - Quick-action call and WhatsApp buttons.
///   - Tap anywhere on the card to open the ContactDetailScreen.
///
/// WHY NO SCHEDULE / ACTIVITY BUTTONS:
///   The Pipeline tab is a read-only stage view; scheduling and logging are
///   done from the contact's detail screen. Keeping the card minimal avoids
///   navigation ambiguity and matches the rule that the Pipeline tab has no FAB.
library;

import 'package:flutter/material.dart';

import '../../core/utils/launchers.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../services/pipeline_service.dart';
import '../../theme/ogera_colors.dart';
import '../../views/contacts/contact_detail_screen.dart';
import '../shell_scope.dart';

/// Stage accent colour — follows the same ramp used by the followups pipeline.
Color _stageColor(String? slug, int orderIndex) {
  final key = (slug ?? '').toLowerCase();
  if (key.contains('won') || key.contains('closed')) return OgeraColors.success;
  if (key.contains('lost')) return OgeraColors.danger;
  if (key.contains('not_interest')) return const Color(0xFF9CA3AF);
  const ramp = [
    OgeraColors.blue,
    Color(0xFF6366F1),
    Color(0xFF0891B2),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
  ];
  return ramp[orderIndex.abs() % ramp.length];
}

class PipelineLeadCard extends StatelessWidget {
  const PipelineLeadCard({
    super.key,
    required this.contact,
    required this.stageOrderIndex,
  });

  final PipelineContact contact;

  /// Position of the stage in the ordered list — used only to pick an accent
  /// colour when the slug is not a well-known one like "won" or "lost".
  final int stageOrderIndex;

  @override
  Widget build(BuildContext context) {
    final accentColor = _stageColor(contact.stageSlug, stageOrderIndex);
    final stageName = _humanize(contact.stageName ?? contact.stageSlug ?? '');

    return OgeraCard(
      accent: (contact.stageSlug ?? '').isNotEmpty ? accentColor : null,
      onTap: () => pushShellRoute<void>(
        context,
        (_) => ContactDetailScreen(contactId: contact.id),
      ),
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── name + stage chip ──────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
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
              if (stageName.isNotEmpty)
                StatusChip(
                  label: stageName,
                  color: accentColor,
                  dense: true,
                ),
            ],
          ),

          // ── tags row ────────────────────────────────────────────────────────
          if ((contact.district ?? '').isNotEmpty || !contact.isVerified) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if ((contact.district ?? '').isNotEmpty)
                  StatusChip(
                    label: contact.district!,
                    icon: Icons.location_city_rounded,
                    dense: true,
                  ),
                if (!contact.isVerified)
                  const StatusChip(
                    label: 'Details missing',
                    tone: StatusTone.warning,
                    icon: Icons.info_outline_rounded,
                    dense: true,
                  ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // ── assignee + call/WhatsApp buttons ────────────────────────────────
          Row(
            children: [
              if ((contact.assignedToName ?? '').isNotEmpty)
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 15,
                        color: OgeraColors.muted,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          contact.assignedToName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: OgeraColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),
              QuickActionButton(
                icon: Icons.call_rounded,
                tooltip: 'Call ${contact.displayName}',
                onPressed: () => Launchers.call(context, contact.phone),
              ),
              QuickActionButton(
                icon: Icons.chat_rounded,
                tooltip: 'WhatsApp ${contact.displayName}',
                color: const Color(0xFF25D366),
                onPressed: () => Launchers.whatsapp(context, contact.phone),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "new_lead" → "New Lead". Handles null gracefully.
  static String _humanize(String slug) {
    return slug
        .split(RegExp(r'[_\-]'))
        .map(
          (w) => w.isEmpty
              ? w
              : w[0].toUpperCase() + w.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}
