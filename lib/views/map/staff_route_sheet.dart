import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/staff_location.dart';
import '../../services/location_api_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/map_view_model.dart';

/// One staff member, one day: where they are now, the path they took, and the
/// places they actually stopped — each with a resolved address.
Future<void> showStaffRouteSheet(
  BuildContext context, {
  required StaffLocation staff,
  required ValueChanged<LatLng> onFocus,
}) {
  final locations = context.read<LocationApiService>();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => StaffRouteViewModel(
        locations: locations,
        staff: staff,
      )..load(),
      child: _StaffRouteSheet(onFocus: onFocus),
    ),
  );
}

class _StaffRouteSheet extends StatelessWidget {
  const _StaffRouteSheet({required this.onFocus});

  final ValueChanged<LatLng> onFocus;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<StaffRouteViewModel>();
    final staff = viewModel.current;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          _Header(staff: staff),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              children: [
                _CurrentLocation(viewModel: viewModel),
                const SizedBox(height: 14),
                _DaySelector(viewModel: viewModel),
                const SizedBox(height: 14),
                if (viewModel.isLoading)
                  const Column(
                    children: [
                      ShimmerBox(height: 200),
                      SizedBox(height: 12),
                      ShimmerBox(height: 64),
                    ],
                  )
                else if (viewModel.error != null)
                  ErrorStateView(
                    message: viewModel.error!,
                    onRetry: viewModel.load,
                  )
                else ...[
                  _RouteMap(
                    route: viewModel.route,
                    color: staff.color,
                    current: viewModel.isToday ? staff.position : null,
                  ),
                  const SizedBox(height: 14),
                  _RouteSummary(route: viewModel.route, color: staff.color),
                  const SizedBox(height: 18),
                  _StopTimeline(
                    route: viewModel.route,
                    color: staff.color,
                    onFocus: onFocus,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.staff});

  final StaffLocation staff;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: OgeraColors.line)),
      ),
      child: Column(
        children: [
          // The staff member's identity colour reads as a bar across the top,
          // so the sheet is unmistakably theirs.
          Container(
            width: 46,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: staff.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              OgeraAvatar(name: staff.name, size: 44, color: staff.color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StatusChip(
                          label: staff.state.label,
                          color: staff.state.color,
                          icon: staff.state.icon,
                          dense: true,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          staff.lastSeenLabel,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: OgeraColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if ((staff.phone ?? '').isNotEmpty) ...[
                QuickActionButton(
                  icon: Icons.call_rounded,
                  tooltip: 'Call ${staff.name}',
                  onPressed: () => Launchers.call(context, staff.phone!),
                ),
                QuickActionButton(
                  icon: Icons.chat_rounded,
                  tooltip: 'WhatsApp ${staff.name}',
                  color: const Color(0xFF25D366),
                  onPressed: () => Launchers.whatsapp(context, staff.phone!),
                ),
              ],
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Refreshed every 30 seconds while the sheet stays open, so "where are they
/// right now" is answered without closing and reopening.
class _CurrentLocation extends StatelessWidget {
  const _CurrentLocation({required this.viewModel});

  final StaffRouteViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final staff = viewModel.current;
    final recordedAt = staff.recordedAt;

    return OgeraCard(
      accent: staff.state.color,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(staff.state.icon, size: 16, color: staff.state.color),
              const SizedBox(width: 7),
              Text(
                'CURRENT LOCATION',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: staff.state.color,
                ),
              ),
              const Spacer(),
              if (recordedAt != null)
                Text(
                  formatMoment(recordedAt),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: OgeraColors.muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            viewModel.currentAddress,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (staff.accuracy != null)
                StatusChip(
                  label: '±${staff.accuracy!.round()} m',
                  icon: Icons.adjust_rounded,
                  dense: true,
                  // A poor fix is called out rather than quietly trusted.
                  tone: staff.accuracy! > 100
                      ? StatusTone.warning
                      : StatusTone.neutral,
                ),
              if (staff.speed != null && staff.speed! > 0.5)
                StatusChip(
                  label: '${(staff.speed! * 3.6).round()} km/h',
                  icon: Icons.speed_rounded,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Launchers.directions(
              context,
              latitude: staff.position.latitude,
              longitude: staff.position.longitude,
            ),
            icon: const Icon(Icons.directions_rounded, size: 17),
            label: const Text('Directions to this point'),
          ),
        ],
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({required this.viewModel});

  final StaffRouteViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final today = todayIso();
    final yesterday = isoDate(DateTime.now().subtract(const Duration(days: 1)));
    final selected = viewModel.date;
    final isCustom = selected != today && selected != yesterday;

    return Row(
      children: [
        _DayChip(
          label: 'Today',
          selected: selected == today,
          onTap: () => viewModel.selectDate(today),
        ),
        const SizedBox(width: 8),
        _DayChip(
          label: 'Yesterday',
          selected: selected == yesterday,
          onTap: () => viewModel.selectDate(yesterday),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _DayChip(
            label: isCustom
                ? formatFullDate(DateTime.parse(selected))
                : 'Pick a date',
            icon: Icons.event_rounded,
            selected: isCustom,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(selected),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now(),
              );
              if (picked != null) await viewModel.selectDate(isoDate(picked));
            },
          ),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? OgeraColors.blue : OgeraColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? OgeraColors.blue : OgeraColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : OgeraColors.muted,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : OgeraColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The day's path, drawn in the staff member's own colour: a start pin, an end
/// pin, and a numbered marker wherever they stayed more than ten minutes.
class _RouteMap extends StatefulWidget {
  const _RouteMap({
    required this.route,
    required this.color,
    required this.current,
  });

  final StaffRoute? route;
  final Color color;
  final LatLng? current;

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  final _controller = MapController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route) _fit();
  }

  /// Runs after the first frame, because the controller has no camera until the
  /// map is laid out.
  void _fit() {
    final bounds = widget.route?.bounds;
    if (bounds == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(bounds.southWest, bounds.northEast),
          padding: const EdgeInsets.all(28),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;

    if (route == null || route.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: OgeraColors.canvas,
          borderRadius: BorderRadius.circular(OgeraSpacing.cardRadius),
          border: Border.all(color: OgeraColors.line),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, size: 30, color: OgeraColors.muted),
            SizedBox(height: 10),
            Text(
              'No route recorded for this day',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: OgeraColors.muted,
              ),
            ),
          ],
        ),
      );
    }

    final points = route.polyline;
    return ClipRRect(
      borderRadius: BorderRadius.circular(OgeraSpacing.cardRadius),
      child: SizedBox(
        height: 240,
        child: FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: points.first,
            initialZoom: 13,
            onMapReady: _fit,
          ),
          children: [
            TileLayer(
              urlTemplate: AppConfig.osmTileUrl,
              userAgentPackageName: AppConfig.osmTilePackage,
              maxNativeZoom: 19,
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: widget.color,
                  strokeWidth: 4.5,
                  borderColor: Colors.white,
                  borderStrokeWidth: 1.5,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                _endpoint(points.first, Icons.trip_origin_rounded, 'Start'),
                if (points.length > 1)
                  _endpoint(points.last, Icons.flag_rounded, 'End'),
                for (var index = 0; index < route.stops.length; index++)
                  Marker(
                    point: route.stops[index].position,
                    width: 28,
                    height: 28,
                    child: _StopPin(index: index + 1, color: widget.color),
                  ),
                if (widget.current != null)
                  Marker(
                    point: widget.current!,
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Marker _endpoint(LatLng point, IconData icon, String label) {
    return Marker(
      point: point,
      width: 26,
      height: 26,
      child: Semantics(
        label: label,
        child: Container(
          decoration: BoxDecoration(
            color: OgeraColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: widget.color, width: 2),
          ),
          child: Icon(icon, size: 13, color: widget.color),
        ),
      ),
    );
  }
}

class _StopPin extends StatelessWidget {
  const _StopPin({required this.index, required this.color});

  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        '$index',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.route, required this.color});

  final StaffRoute? route;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (route == null || route!.isEmpty) return const SizedBox.shrink();
    final data = route!;

    return OgeraCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        children: [
          _Metric(
            label: 'Distance',
            value: formatDistance(data.distanceMeters),
            icon: Icons.timeline_rounded,
            color: color,
          ),
          _Divider(),
          _Metric(
            label: 'Stops',
            value: '${data.stops.length}',
            icon: Icons.pin_drop_outlined,
            color: color,
          ),
          _Divider(),
          _Metric(
            label: 'First seen',
            value: data.firstSeen == null ? '—' : formatTime(data.firstSeen!),
            icon: Icons.login_rounded,
            color: color,
          ),
          _Divider(),
          _Metric(
            label: 'Last seen',
            value: data.lastSeen == null ? '—' : formatTime(data.lastSeen!),
            icon: Icons.logout_rounded,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: OgeraColors.line);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: OgeraColors.muted),
          ),
        ],
      ),
    );
  }
}

/// Where the time actually went: each stop with its address and how long they
/// were there. Addresses resolve one per second behind the geocoder's limit and
/// the rows repaint as they arrive.
class _StopTimeline extends StatelessWidget {
  const _StopTimeline({
    required this.route,
    required this.color,
    required this.onFocus,
  });

  final StaffRoute? route;
  final Color color;
  final ValueChanged<LatLng> onFocus;

  @override
  Widget build(BuildContext context) {
    final stops = route?.stops ?? const <RouteStop>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Stops',
          icon: Icons.pin_drop_outlined,
          action: stops.isEmpty
              ? null
              : StatusChip(label: '${stops.length}', color: color, dense: true),
        ),
        if (stops.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No stop lasted longer than ten minutes on this day, so the route '
              'is continuous travel.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: OgeraColors.muted,
              ),
            ),
          )
        else
          for (var index = 0; index < stops.length; index++)
            _StopEntry(
              stop: stops[index],
              index: index + 1,
              color: color,
              isLast: index == stops.length - 1,
              onTap: () {
                Navigator.of(context).pop();
                onFocus(stops[index].position);
              },
            ),
      ],
    );
  }
}

class _StopEntry extends StatelessWidget {
  const _StopEntry({
    required this.stop,
    required this.index,
    required this.color,
    required this.isLast,
    required this.onTap,
  });

  final RouteStop stop;
  final int index;
  final Color color;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(top: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1.5, color: OgeraColors.line),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 2, bottom: isLast ? 4 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.address ?? 'Address unavailable',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        StatusChip(
                          label: formatDuration(stop.dwell),
                          icon: Icons.timer_outlined,
                          color: color,
                          dense: true,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${formatTime(stop.arrivedAt)} – ${formatTime(stop.leftAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: OgeraColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
