import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/home_view_model.dart';
import '../../view_models/session_view_model.dart';
import '../notifications/notifications_screen.dart';
import 'checkin_button.dart';
import 'recent_leads_section.dart';
import 'recent_tasks_section.dart';
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

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: const Text('Home'),
        actions: const [NotificationBellButton(), SizedBox(width: 4)],
      ),
      body: RefreshIndicator(
        onRefresh: home.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            120,
          ),
          children: [
            // Greeting: "Good morning, Sajad" + role badge
            const _Greeting(),
            // Field check-in status card
            const CheckinCard(),
            const SizedBox(height: 20),
            // KPI tiles: New leads / Open follow-ups / Overdue / Won
            const StatsRow(),
            const SizedBox(height: 24),
            // Recent leads section — contacts added in the chosen period
            const SectionHeader(
              title: 'Leads',
              icon: Icons.person_add_alt_1_rounded,
            ),
            const RecentLeadsSection(),
            const SizedBox(height: 24),
            // Tasks section — tasks due in the chosen period
            const SectionHeader(
              title: 'Tasks',
              icon: Icons.task_alt_rounded,
            ),
            const RecentTasksSection(),
          ],
        ),
      ),
    );
  }
}

