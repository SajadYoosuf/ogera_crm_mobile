import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/session_view_model.dart';

/// Own profile and settings.
///
/// User, role, and password administration stay outside the CRM until HRMS
/// integration, so everything here is read-only except sign-out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final user = session.user;
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          OgeraSpacing.screen,
          OgeraSpacing.screen,
          32,
        ),
        children: [
          OgeraCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                OgeraAvatar(
                  name: user.name,
                  size: 76,
                  color: user.isHead ? OgeraColors.ink : OgeraColors.blue,
                ),
                const SizedBox(height: 14),
                Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                StatusChip(
                  label: user.role.label,
                  tone: user.isHead ? StatusTone.brand : StatusTone.info,
                  icon: user.isHead
                      ? Icons.insights_rounded
                      : Icons.badge_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: OgeraSpacing.gap),
          OgeraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Details',
                  icon: Icons.person_outline_rounded,
                ),
                DetailRow(
                  label: 'Email',
                  value: user.email,
                  icon: Icons.alternate_email_rounded,
                ),
                DetailRow(
                  label: 'Phone',
                  value: user.phone,
                  icon: Icons.call_outlined,
                  onTap: (user.phone ?? '').isEmpty
                      ? null
                      : () => Launchers.call(context, user.phone!),
                ),
                DetailRow(
                  label: 'CRM role',
                  value: user.role.label,
                  icon: Icons.shield_outlined,
                ),
                const DetailRow(
                  label: 'Managed in',
                  value: 'Venting Next — ask an administrator to change these',
                  icon: Icons.info_outline_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: OgeraSpacing.gap),
          OgeraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'App',
                  icon: Icons.smartphone_rounded,
                ),
                const DetailRow(
                  label: 'Version',
                  value: '1.0.0',
                  icon: Icons.tag_rounded,
                ),
                DetailRow(
                  label: 'Server',
                  value: AppConfig.apiBaseUrl,
                  icon: Icons.dns_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: OgeraColors.danger,
              side: BorderSide(
                color: OgeraColors.danger.withValues(alpha: 0.35),
              ),
              minimumSize: const Size(0, 52),
            ),
            onPressed: () async {
              final confirmed = await confirmAction(
                context,
                title: 'Sign out?',
                message: 'You will need to sign in again on this device.',
                confirmLabel: 'Sign out',
              );
              if (confirmed) await session.signOut();
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
