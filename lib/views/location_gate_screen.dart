import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/widgets/ogera_widgets.dart';
import '../services/location_tracking_service.dart';
import '../theme/ogera_colors.dart';
import '../view_models/session_view_model.dart';

/// The staff app is not operable without location permission.
///
/// This screen stands in front of the whole shell: there is no tab, no back
/// gesture, and no "not now". The only ways out are granting permission,
/// opening system settings, or signing out.
class LocationGateScreen extends StatefulWidget {
  const LocationGateScreen({super.key});

  @override
  State<LocationGateScreen> createState() => _LocationGateScreenState();
}

class _LocationGateScreenState extends State<LocationGateScreen> {
  bool _isRequesting = false;

  Future<void> _request() async {
    setState(() => _isRequesting = true);
    final session = context.read<SessionViewModel>();
    final state = await session.requestLocationPermission();
    if (!mounted) return;
    setState(() => _isRequesting = false);

    if (!state.canTrack && state.needsSettings) {
      showToast(
        context,
        state == LocationPermissionState.serviceDisabled
            ? 'Turn on location services for this device, then come back.'
            : 'Location is blocked for Ogera CRM. Enable it in app settings.',
        isError: true,
      );
    }
  }

  Future<void> _openSettings() async {
    final session = context.read<SessionViewModel>();
    if (session.permission == LocationPermissionState.serviceDisabled) {
      await session.tracking.openLocationSettings();
    } else {
      await session.tracking.openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final permission = session.permission;
    final isBlocked =
        permission != LocationPermissionState.unknown && !permission.canTrack;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: OgeraColors.blueDeep,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.read<SessionViewModel>().signOut(),
                    icon: const Icon(
                      Icons.logout_rounded,
                      size: 18,
                      color: Colors.white70,
                    ),
                    label: const Text(
                      'Sign out',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _PulsingPin(),
                          const SizedBox(height: 32),
                          Text(
                            isBlocked
                                ? 'Location access is blocked'
                                : 'Location sharing is required',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            isBlocked
                                ? _blockedMessage(permission)
                                : 'Ogera CRM shares your location with your Sales Head '
                                      'while you are signed in, so field visits and routes '
                                      'can be verified.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14.5,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: 28),
                          const _Assurances(),
                        ],
                      ),
                    ),
                  ),
                ),
                _Actions(
                  isBlocked: isBlocked,
                  isRequesting: _isRequesting,
                  onRequest: _request,
                  onSettings: _openSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _blockedMessage(LocationPermissionState permission) {
    return switch (permission) {
      LocationPermissionState.serviceDisabled =>
        'Location services are switched off for this device. Turn them on, then '
            'return to continue.',
      LocationPermissionState.deniedForever =>
        'Location is permanently denied for Ogera CRM. Open app settings and '
            'allow location access to continue.',
      _ =>
        'Without location access the staff app cannot be used. Allow location '
            'to continue, or sign out.',
    };
  }
}

/// A slow beacon rather than a spinner: it says "sharing", not "loading".
class _PulsingPin extends StatefulWidget {
  const _PulsingPin();

  @override
  State<_PulsingPin> createState() => _PulsingPinState();
}

class _PulsingPinState extends State<_PulsingPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 168,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final delay in const [0.0, 0.33, 0.66])
                _ring((_controller.value + delay) % 1.0),
              child!,
            ],
          );
        },
        child: Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.my_location_rounded,
            size: 40,
            color: OgeraColors.blueDeep,
          ),
        ),
      ),
    );
  }

  Widget _ring(double progress) {
    return Opacity(
      opacity: (1 - progress) * 0.35,
      child: Container(
        width: 88 + (80 * progress),
        height: 88 + (80 * progress),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.6),
        ),
      ),
    );
  }
}

class _Assurances extends StatelessWidget {
  const _Assurances();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.schedule_rounded, 'Only while you are signed in'),
      (Icons.visibility_outlined, 'Visible to your Admin and Sales Head'),
      (Icons.battery_saver_rounded, 'Reports less often when you stop moving'),
    ];
    return Column(
      children: [
        for (final (icon, label) in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: Colors.white70),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.isBlocked,
    required this.isRequesting,
    required this.onRequest,
    required this.onSettings,
  });

  final bool isBlocked;
  final bool isRequesting;
  final Future<void> Function() onRequest;
  final Future<void> Function() onSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: OgeraColors.blueDeep,
          ),
          onPressed: isRequesting ? null : onRequest,
          child: isRequesting
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: OgeraColors.blueDeep,
                  ),
                )
              : Text(isBlocked ? 'Try again' : 'Enable location'),
        ),
        if (isBlocked) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Open settings'),
          ),
        ],
      ],
    );
  }
}
