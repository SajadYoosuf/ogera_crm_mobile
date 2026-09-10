import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/staff_location.dart';
import '../../services/location_api_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/session_view_model.dart';

/// A staff member's own route.
///
/// This is transparency, not monitoring: the same data their Sales Head sees,
/// shown back to them, read-only. Staff never get the team staff layer.
class MyRouteScreen extends StatefulWidget {
  const MyRouteScreen({super.key});

  @override
  State<MyRouteScreen> createState() => _MyRouteScreenState();
}

class _MyRouteScreenState extends State<MyRouteScreen> {
  final _mapController = MapController();

  StaffRoute? _route;
  String _date = todayIso();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final session = context.read<SessionViewModel>();
    try {
      final route = await context.read<LocationApiService>().myRoute(
        userId: session.userId,
        date: _date,
      );
      if (!mounted) return;
      setState(() {
        _route = route;
        _isLoading = false;
      });
      _fit();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  void _fit() {
    final bounds = _route?.bounds;
    if (bounds == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(bounds.southWest, bounds.northEast),
          padding: const EdgeInsets.all(30),
        ),
      );
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_date),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _date = isoDate(picked));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _date == todayIso();
    final route = _route;

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: Text(isToday ? 'My route today' : 'My route'),
        actions: [
          IconButton(
            tooltip: 'Pick a date',
            onPressed: _pickDate,
            icon: const Icon(Icons.event_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            32,
          ),
          children: [
            if (!isToday)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StatusChip(
                  label: formatFullDate(DateTime.parse(_date)),
                  icon: Icons.event_rounded,
                  tone: StatusTone.brand,
                ),
              ),
            if (_isLoading) ...[
              const ShimmerBox(height: 220),
              const SizedBox(height: 12),
              const ShimmerBox(height: 74),
            ] else if (_error != null)
              ErrorStateView(message: _error!, onRetry: _load)
            else if (route == null || route.isEmpty)
              const EmptyStateView(
                icon: Icons.route_outlined,
                title: 'No route recorded',
                message:
                    'Nothing was recorded for this day. Your route appears '
                    'here once you are signed in and moving with location on.',
              )
            else ...[
              _RouteMap(route: route, controller: _mapController),
              const SizedBox(height: 14),
              _Summary(route: route),
              const SizedBox(height: 18),
              _Stops(route: route),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.route, required this.controller});

  final StaffRoute route;
  final MapController controller;

  @override
  Widget build(BuildContext context) {
    final points = route.polyline;
    return ClipRRect(
      borderRadius: BorderRadius.circular(OgeraSpacing.cardRadius),
      child: SizedBox(
        height: 250,
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(initialCenter: points.first, initialZoom: 13),
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
                  color: OgeraColors.blue,
                  strokeWidth: 4.5,
                  borderColor: Colors.white,
                  borderStrokeWidth: 1.5,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: points.first,
                  width: 26,
                  height: 26,
                  child: _Endpoint(
                    icon: Icons.trip_origin_rounded,
                    label: 'Start',
                  ),
                ),
                if (points.length > 1)
                  Marker(
                    point: points.last,
                    width: 26,
                    height: 26,
                    child: _Endpoint(icon: Icons.flag_rounded, label: 'End'),
                  ),
                for (var index = 0; index < route.stops.length; index++)
                  Marker(
                    point: route.stops[index].position,
                    width: 28,
                    height: 28,
                    child: _StopPin(index: index + 1),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        decoration: BoxDecoration(
          color: OgeraColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: OgeraColors.blue, width: 2),
        ),
        child: Icon(icon, size: 13, color: OgeraColors.blue),
      ),
    );
  }
}

class _StopPin extends StatelessWidget {
  const _StopPin({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: OgeraColors.blue,
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

class _Summary extends StatelessWidget {
  const _Summary({required this.route});

  final StaffRoute route;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: Row(
        children: [
          _Metric(
            label: 'Distance',
            value: formatDistance(route.distanceMeters),
            icon: Icons.timeline_rounded,
          ),
          Container(width: 1, height: 34, color: OgeraColors.line),
          _Metric(
            label: 'Stops',
            value: '${route.stops.length}',
            icon: Icons.pin_drop_outlined,
          ),
          Container(width: 1, height: 34, color: OgeraColors.line),
          _Metric(
            label: 'First seen',
            value: route.firstSeen == null ? '—' : formatTime(route.firstSeen!),
            icon: Icons.login_rounded,
          ),
          Container(width: 1, height: 34, color: OgeraColors.line),
          _Metric(
            label: 'Last seen',
            value: route.lastSeen == null ? '—' : formatTime(route.lastSeen!),
            icon: Icons.logout_rounded,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: OgeraColors.blue),
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

class _Stops extends StatelessWidget {
  const _Stops({required this.route});

  final StaffRoute route;

  @override
  Widget build(BuildContext context) {
    final stops = route.stops;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Where you stopped',
          icon: Icons.pin_drop_outlined,
          action: stops.isEmpty
              ? null
              : StatusChip(
                  label: '${stops.length}',
                  tone: StatusTone.brand,
                  dense: true,
                ),
        ),
        if (stops.isEmpty)
          const OgeraCard(
            child: Text(
              'No stop lasted longer than ten minutes, so this day reads as '
              'continuous travel.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: OgeraColors.muted,
              ),
            ),
          )
        else
          OgeraCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (var index = 0; index < stops.length; index++) ...[
                  if (index > 0) const Divider(),
                  _StopRow(stop: stops[index], index: index + 1),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop, required this.index});

  final RouteStop stop;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: OgeraColors.blue,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.address ??
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
                      tone: StatusTone.brand,
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
        ],
      ),
    );
  }
}
