import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../models/contact.dart';
import '../../models/professional.dart';
import '../../models/staff_location.dart';
import '../../theme/ogera_colors.dart';

/// Markers for the three map layers, plus the compact card a marker tap opens.
///
/// Every marker carries a shape or a letter as well as a colour, so the map
/// stays readable for anyone who cannot separate two hues.

class ContactMarker extends StatelessWidget {
  const ContactMarker({super.key, required this.pin, required this.onTap});

  final ContactPin pin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLead = pin.contactType == ContactType.lead;
    final color = isLead ? OgeraColors.blue : OgeraColors.info;
    return Semantics(
      button: true,
      label: '${pin.displayName}, ${isLead ? 'lead' : 'awareness'}',
      child: GestureDetector(
        onTap: onTap,
        child: _Teardrop(
          color: color,
          // A lead is a filled drop, awareness a hollow one — the shape says
          // which it is before the colour does.
          filled: isLead,
          icon: isLead ? Icons.person_rounded : Icons.campaign_rounded,
        ),
      ),
    );
  }
}

class ProfessionalMarker extends StatelessWidget {
  const ProfessionalMarker({
    super.key,
    required this.professional,
    required this.onTap,
  });

  final Professional professional;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${professional.displayName}, ${professional.type.label}',
      child: GestureDetector(
        onTap: onTap,
        child: _Teardrop(
          color: professional.type.color,
          filled: true,
          icon: professional.type.icon,
        ),
      ),
    );
  }
}

/// The standard pin: a rounded badge with a pointer beneath it.
class _Teardrop extends StatelessWidget {
  const _Teardrop({
    required this.color,
    required this.filled,
    required this.icon,
  });

  final Color color;
  final bool filled;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? color : OgeraColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: filled ? Colors.white : color,
              width: filled ? 2 : 2.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 15, color: filled ? Colors.white : color),
        ),
        Transform.translate(
          offset: const Offset(0, -3),
          child: CustomPaint(
            size: const Size(10, 7),
            painter: _PointerPainter(filled ? color : OgeraColors.surface),
          ),
        ),
      ],
    );
  }
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) => oldDelegate.color != color;
}

/// A staff member on the head map.
///
/// The four states are told apart by more than colour: **Live** breathes,
/// **Last seen** is solid but still, **Offline** is a hollow ring, and
/// **Location off** carries a slashed badge.
class StaffMarker extends StatefulWidget {
  const StaffMarker({
    super.key,
    required this.staff,
    required this.isSelected,
    required this.onTap,
  });

  final StaffLocation staff;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<StaffMarker> createState() => _StaffMarkerState();
}

class _StaffMarkerState extends State<StaffMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(StaffMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.staff.state != widget.staff.state) _syncPulse();
  }

  /// Only a live marker animates; a still map is a cheaper map.
  void _syncPulse() {
    if (widget.staff.state == StaffState.moving) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staff = widget.staff;
    final color = staff.color;
    final state = staff.state;
    final isOffline = state == StaffState.connectionLost;
    final isDisabled = state == StaffState.locationDisabled;

    return Semantics(
      button: true,
      label: '${staff.name}, ${state.label}, ${staff.lastSeenLabel}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (state == StaffState.moving)
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => Container(
                  width: 34 + (30 * _pulse.value),
                  height: 34 + (30 * _pulse.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: (1 - _pulse.value) * 0.22),
                  ),
                ),
              ),
            if (widget.isSelected)
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2.5),
                ),
              ),
            Opacity(
              opacity: switch (state) {
                StaffState.moving => 1,
                StaffState.stuck => 0.7,
                StaffState.connectionLost => 0.45,
                StaffState.locationDisabled => 0.65,
              },
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isOffline
                      ? OgeraColors.surface
                      : (isDisabled ? const Color(0xFF9CA3AF) : color),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isOffline ? const Color(0xFF9CA3AF) : Colors.white,
                    width: isOffline ? 2.4 : 2.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x38000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  initialsOf(staff.name),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isOffline ? const Color(0xFF6B7280) : Colors.white,
                  ),
                ),
              ),
            ),
            if (isDisabled)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  width: 17,
                  height: 17,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: OgeraColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_disabled_rounded,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The compact card a contact or professional marker opens: enough to act on
/// without leaving the map, and one route into the full record.
void showMapCard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String badge,
  required Color color,
  required String phone,
  String? description,
  double? latitude,
  double? longitude,
  VoidCallback? onOpen,
}) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OgeraAvatar(name: title, phone: phone, size: 48, color: color),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: OgeraColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(label: badge, color: color, dense: true),
              ],
            ),
            if ((description ?? '').isNotEmpty) ...[
              const SizedBox(height: 13),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: OgeraColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      description!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: OgeraColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                QuickActionButton(
                  icon: Icons.call_rounded,
                  tooltip: 'Call $title',
                  onPressed: () => Launchers.call(sheetContext, phone),
                ),
                QuickActionButton(
                  icon: Icons.chat_rounded,
                  tooltip: 'WhatsApp $title',
                  color: const Color(0xFF25D366),
                  onPressed: () => Launchers.whatsapp(sheetContext, phone),
                ),
                QuickActionButton(
                  icon: Icons.directions_rounded,
                  tooltip: 'Directions to $title',
                  color: OgeraColors.warning,
                  onPressed: latitude == null || longitude == null
                      ? null
                      : () => Launchers.directions(
                          sheetContext,
                          latitude: latitude,
                          longitude: longitude,
                        ),
                ),
              ],
            ),
            if (onOpen != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  onOpen();
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open full record'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
