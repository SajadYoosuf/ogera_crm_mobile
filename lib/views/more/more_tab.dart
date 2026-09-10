import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/ogera_widgets.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/session_view_model.dart';
import '../sales/sales_screen.dart';
import 'my_route_screen.dart';
import 'profile_screen.dart';
import 'staff_directory_screen.dart';
import '../shell_scope.dart';

/// Everything that does not earn a permanent tab.
///
/// The Sales Ledger and the Staff Directory are Head-only and are simply absent
/// for a staff session — not greyed out.
class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final user = session.user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          OgeraSpacing.screen,
          OgeraSpacing.screen,
          40,
        ),
        children: [
          _ProfileHeader(
            name: user.name,
            email: user.email,
            role: user.role.label,
            isHead: user.isHead,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          const SizedBox(height: 22),

          if (user.isHead) ...[
            const SectionHeader(title: 'Team', icon: Icons.groups_outlined),
            _MenuGroup(
              items: [
                _MenuItem(
                  icon: Icons.receipt_long_rounded,
                  color: OgeraColors.success,
                  label: 'Sales Ledger',
                  caption: 'Record and review completed sales',
                  onTap: () =>
                      pushShellRoute<void>(context, (_) => const SalesScreen()),
                ),
                _MenuItem(
                  icon: Icons.badge_outlined,
                  color: OgeraColors.blue,
                  label: 'Staff directory',
                  caption: 'Everyone who can be assigned work',
                  onTap: () => pushShellRoute<void>(
                    context,
                    (_) => const StaffDirectoryScreen(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
          ],

          if (user.isStaff) ...[
            const SectionHeader(
              title: 'My activity',
              icon: Icons.route_outlined,
            ),
            _MenuGroup(
              items: [
                _MenuItem(
                  icon: Icons.timeline_rounded,
                  color: OgeraColors.warning,
                  label: 'My route today',
                  caption: 'The path and distance recorded for you',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyRouteScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
          ],

          const SectionHeader(
            title: 'Account',
            icon: Icons.person_outline_rounded,
          ),
          _MenuGroup(
            items: [
              _MenuItem(
                icon: Icons.manage_accounts_outlined,
                color: OgeraColors.info,
                label: 'Profile and settings',
                caption: 'Your details, location state, and app version',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
              _MenuItem(
                icon: Icons.logout_rounded,
                color: OgeraColors.danger,
                label: 'Sign out',
                caption: user.isStaff
                    ? 'Stops location sharing immediately'
                    : 'End this session on this device',
                onTap: () => _signOut(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _signOut(BuildContext context) async {
  final session = context.read<SessionViewModel>();
  final confirmed = await confirmAction(
    context,
    title: 'Sign out?',
    message: session.isStaff
        ? 'Location sharing stops as soon as you sign out, and anything still '
              'queued is discarded.'
        : 'You will need to sign in again on this device.',
    confirmLabel: 'Sign out',
  );
  if (!confirmed) return;
  await session.signOut();
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.role,
    required this.isHead,
    required this.onTap,
  });

  final String name;
  final String email;
  final String role;
  final bool isHead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          OgeraAvatar(
            name: name,
            size: 54,
            color: isHead ? OgeraColors.ink : OgeraColors.blue,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: OgeraColors.muted,
                  ),
                ),
                const SizedBox(height: 9),
                StatusChip(
                  label: role,
                  tone: isHead ? StatusTone.brand : StatusTone.info,
                  icon: isHead ? Icons.insights_rounded : Icons.badge_outlined,
                  dense: true,
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

class _MenuItem {
  const _MenuItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.caption,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String caption;
  final VoidCallback onTap;
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0) const Divider(),
            _MenuRow(item: items[index]),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});

  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(item.icon, size: 19, color: item.color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.caption,
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
