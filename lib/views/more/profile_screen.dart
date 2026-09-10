import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../services/location_tracking_service.dart';
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
          if (user.isStaff)
            const _LocationCard()
          else
            const _HeadLocationNote(),
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
                message: session.isStaff
                    ? 'Location sharing stops as soon as you sign out.'
                    : 'You will need to sign in again on this device.',
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

/// For a staff member, location sharing is a condition of using the app, so it
/// is shown as a state — not a switch they can turn off.
class _LocationCard extends StatelessWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final tracking = session.tracking;
    final permission = session.permission;

    return OgeraCard(
      accent: permission.canTrack ? OgeraColors.success : OgeraColors.danger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Location sharing',
            icon: Icons.my_location_rounded,
          ),
          Row(
            children: [
              Icon(
                permission.canTrack
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                size: 20,
                color: permission.canTrack
                    ? OgeraColors.success
                    : OgeraColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  switch (permission) {
                    LocationPermissionState.granted =>
                      'On — sharing in the background',
                    LocationPermissionState.grantedForeground =>
                      'On — sharing while the app is open',
                    LocationPermissionState.serviceDisabled =>
                      'Device location services are switched off',
                    LocationPermissionState.deniedForever =>
                      'Blocked in system settings',
                    _ => 'Off',
                  },
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Required while you are signed in. Your Sales Head can see your '
            'current location and today’s route.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: OgeraColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(),
          ValueListenableBuilder<int>(
            valueListenable: tracking.pendingCount,
            builder: (context, pending, _) => DetailRow(
              label: 'Waiting to sync',
              value: pending == 0
                  ? 'Nothing queued'
                  : '$pending point${pending == 1 ? '' : 's'}',
              icon: Icons.cloud_upload_outlined,
              valueColor: pending == 0 ? null : OgeraColors.warning,
            ),
          ),
          ValueListenableBuilder<DateTime?>(
            valueListenable: tracking.lastUpload,
            builder: (context, lastUpload, _) => DetailRow(
              label: 'Last upload',
              value: lastUpload == null
                  ? 'Not yet'
                  : formatRelative(lastUpload),
              icon: Icons.schedule_rounded,
            ),
          ),
          const SizedBox(height: 6),
          _LiveReadout(tracking: tracking),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => tracking.flush(force: true),
            icon: const Icon(Icons.sync_rounded, size: 17),
            label: const Text('Sync now'),
          ),
        ],
      ),
    );
  }
}

class _HeadLocationNote extends StatelessWidget {
  const _HeadLocationNote();

  @override
  Widget build(BuildContext context) {
    return const OgeraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Location', icon: Icons.my_location_rounded),
          Text(
            'Your own location is never shared. You can see where your Sales '
            'Staff are from the Staff layer on the Map tab.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: OgeraColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The ten-second heartbeat, on screen.
///
/// The upload cadence is 60 s at best and 5 minutes when standing still, so
/// without this there is no way to tell a working tracker from a broken one
/// while holding the phone. It listens to a stream the service already emits —
/// it never asks for a fix of its own, so it adds no battery cost.
class _LiveReadout extends StatelessWidget {
  const _LiveReadout({required this.tracking});

  final LocationTrackingService tracking;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LocationDebugTick>(
      stream: tracking.debugTicks,
      initialData: tracking.currentDebugTick,
      builder: (context, snapshot) {
        final tick = snapshot.data;
        if (tick == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: OgeraColors.ink,
            borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.satellite_alt_rounded,
                    size: 14,
                    color: tick.hasFix
                        ? const Color(0xFF86EFAC)
                        : Colors.white54,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    tick.isTracking
                        ? 'LIVE — updates every 10s'
                        : 'TRACKING STOPPED',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              _Line(
                label: 'GPS now',
                value: tick.fixLabel,
                highlight: tick.hasFix,
              ),
              _Line(label: 'To database', value: tick.queuedLabel),
              _Line(label: 'Queued', value: '${tick.pending} point(s)'),
              if (tick.lastError != null)
                _Line(label: 'Error', value: tick.lastError!, isError: true),
            ],
          ),
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.highlight = false,
    this.isError = false,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Colors.white54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: isError
                    ? const Color(0xFFFCA5A5)
                    : (highlight ? const Color(0xFF86EFAC) : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
