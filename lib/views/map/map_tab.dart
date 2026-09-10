import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../models/contact.dart';
import '../../models/professional.dart';
import '../../models/staff_location.dart';
import '../../services/location_api_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/map_view_model.dart';
import '../contacts/contact_detail_screen.dart';
import 'map_markers.dart';
import 'staff_route_sheet.dart';
import 'staff_sheet.dart';
import '../shell_scope.dart';

/// One map, three layers.
///
/// Sales Staff get Contacts and Professionals. Admin and Sales Head get those
/// plus the Staff layer — live positions, one persistent colour per person, and
/// a tap-through to that person's route for the day.
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> with WidgetsBindingObserver {
  final _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    super.dispose();
  }

  /// Live polling costs battery and data, so it only runs while the map is
  /// actually in front of the user.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final viewModel = context.read<MapViewModel>();
    if (state == AppLifecycleState.resumed) {
      viewModel.resumePolling();
    } else {
      viewModel.pausePolling();
    }
  }

  void _fitToPins() {
    final positions = context.read<MapViewModel>().plottedPositions;
    if (positions.isEmpty) return;
    if (positions.length == 1) {
      _mapController.move(positions.first, 15);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(positions),
        padding: const EdgeInsets.fromLTRB(48, 120, 48, 260),
      ),
    );
  }

  void _focusOn(LatLng position, {double zoom = 16}) {
    _mapController.move(position, zoom);
  }

  Future<void> _openStaffRoute(StaffLocation staff) async {
    context.read<MapViewModel>().selectStaff(staff.userId);
    _focusOn(staff.position, zoom: 15);
    await showStaffRouteSheet(
      context,
      staff: staff,
      onFocus: (position) => _focusOn(position, zoom: 17),
    );
    if (mounted) context.read<MapViewModel>().selectStaff(null);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MapViewModel>();

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: MapViewModel.fallbackCentre,
              initialZoom: 10,
              minZoom: 4,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: AppConfig.osmTileUrl,
                userAgentPackageName: AppConfig.osmTilePackage,
                maxNativeZoom: 19,
              ),
              ..._layers(viewModel),
            ],
          ),

          // Layer switcher and per-layer filters float above the map so the
          // canvas stays uninterrupted.
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 0,
            right: 0,
            child: _MapTopBar(viewModel: viewModel, onFit: _fitToPins),
          ),

          if (viewModel.isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2.5),
            ),

          if (viewModel.error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _MapError(
                message: viewModel.error!,
                onRetry: viewModel.load,
              ),
            )
          else if (viewModel.layer == MapLayer.staff)
            StaffSheet(
              onSelect: _openStaffRoute,
              onFocus: (staff) => _focusOn(staff.position, zoom: 16),
            )
          else
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: _MapLegend(viewModel: viewModel),
            ),
        ],
      ),
    );
  }

  List<Widget> _layers(MapViewModel viewModel) {
    return switch (viewModel.layer) {
      MapLayer.contacts => [
        MarkerLayer(
          markers: [
            for (final pin in viewModel.contactPins)
              Marker(
                point: LatLng(pin.latitude, pin.longitude),
                width: 40,
                height: 40,
                child: ContactMarker(
                  pin: pin,
                  onTap: () => _showContactCard(pin),
                ),
              ),
          ],
        ),
      ],
      MapLayer.professionals => [
        MarkerLayer(
          markers: [
            for (final professional in viewModel.professionalPins)
              if (professional.hasLocation)
                Marker(
                  point: LatLng(professional.lat!, professional.lng!),
                  width: 40,
                  height: 40,
                  child: ProfessionalMarker(
                    professional: professional,
                    onTap: () => _showProfessionalCard(professional),
                  ),
                ),
          ],
        ),
      ],
      MapLayer.staff => [
        MarkerLayer(
          markers: [
            for (final staff in viewModel.staffLocations)
              Marker(
                point: staff.position,
                width: 66,
                height: 66,
                child: StaffMarker(
                  staff: staff,
                  isSelected: staff.userId == viewModel.selectedStaffId,
                  onTap: () => _openStaffRoute(staff),
                ),
              ),
          ],
        ),
      ],
    };
  }

  void _showContactCard(ContactPin pin) {
    _focusOn(LatLng(pin.latitude, pin.longitude));
    showMapCard(
      context,
      title: pin.displayName,
      subtitle: pin.phone,
      description: pin.address,
      badge: pin.contactType == ContactType.lead ? 'Lead' : 'Awareness',
      color: pin.contactType == ContactType.lead
          ? OgeraColors.blue
          : OgeraColors.info,
      phone: pin.phone,
      latitude: pin.latitude,
      longitude: pin.longitude,
      onOpen: () => pushShellRoute<void>(
        context,
        (_) => ContactDetailScreen(contactId: pin.id),
      ),
    );
  }

  void _showProfessionalCard(Professional professional) {
    _focusOn(LatLng(professional.lat!, professional.lng!));
    showMapCard(
      context,
      title: professional.displayName,
      subtitle: professional.phone,
      description: professional.locationSummary,
      badge: professional.type.label,
      color: professional.type.color,
      phone: professional.phone,
      latitude: professional.lat,
      longitude: professional.lng,
    );
  }
}

class _MapTopBar extends StatelessWidget {
  const _MapTopBar({required this.viewModel, required this.onFit});

  final MapViewModel viewModel;
  final VoidCallback onFit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _LayerSwitcher(
                  layers: viewModel.availableLayers,
                  selected: viewModel.layer,
                  onChanged: viewModel.selectLayer,
                ),
              ),
              const SizedBox(width: 10),
              _MapButton(
                icon: Icons.fit_screen_rounded,
                tooltip: 'Fit everything on screen',
                onPressed: onFit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (viewModel.layer == MapLayer.contacts)
          _FilterRow(
            children: [
              for (final type in [null, ...ContactType.values])
                _FilterPill(
                  label: type?.label ?? 'All contacts',
                  selected: viewModel.contactTypeFilter == type,
                  color: type == ContactType.awareness
                      ? OgeraColors.info
                      : OgeraColors.blue,
                  onTap: () => viewModel.setContactTypeFilter(type),
                ),
            ],
          )
        else if (viewModel.layer == MapLayer.professionals)
          _FilterRow(
            children: [
              _FilterPill(
                label: 'All trades',
                selected: viewModel.professionalTypeFilter == null,
                color: OgeraColors.blue,
                onTap: () => viewModel.setProfessionalTypeFilter(null),
              ),
              for (final type in ProfessionalType.values)
                _FilterPill(
                  label: type.label,
                  selected: viewModel.professionalTypeFilter == type,
                  color: type.color,
                  icon: type.icon,
                  onTap: () => viewModel.setProfessionalTypeFilter(type),
                ),
            ],
          )
        else
          _FilterRow(
            children: [
              _FilterPill(
                label: 'Moving only',
                selected: viewModel.liveOnly,
                color: OgeraColors.success,
                icon: Icons.podcasts_rounded,
                onTap: () => viewModel.setLiveOnly(!viewModel.liveOnly),
              ),
              _FilterPill(
                label: '${viewModel.liveCount} moving now',
                selected: false,
                color: OgeraColors.muted,
                onTap: viewModel.refresh,
                icon: Icons.refresh_rounded,
              ),
            ],
          ),
      ],
    );
  }
}

class _LayerSwitcher extends StatelessWidget {
  const _LayerSwitcher({
    required this.layers,
    required this.selected,
    required this.onChanged,
  });

  final List<MapLayer> layers;
  final MapLayer selected;
  final ValueChanged<MapLayer> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: OgeraColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: OgeraColors.cardShadow,
      ),
      child: Row(
        children: [
          for (final layer in layers)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(layer),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: layer == selected
                        ? OgeraColors.blue
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    layer.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: layer == selected ? Colors.white : OgeraColors.ink,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => children[index],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color : OgeraColors.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: OgeraColors.lowShadow,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? Colors.white : color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : OgeraColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: OgeraColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: OgeraColors.cardShadow,
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 21, color: OgeraColors.ink),
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.viewModel});

  final MapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final entries = viewModel.layer == MapLayer.contacts
        ? <(String, Color)>[
            ('Lead', OgeraColors.blue),
            ('Awareness', OgeraColors.info),
          ]
        : [
            for (final type in ProfessionalType.values)
              (type.label, type.color),
          ];
    final count = viewModel.layer == MapLayer.contacts
        ? viewModel.contactPins.length
        : viewModel.professionalPins.where((item) => item.hasLocation).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: OgeraColors.surface,
        borderRadius: BorderRadius.circular(OgeraSpacing.cardRadius),
        boxShadow: OgeraColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count == 1 ? '1 pin on the map' : '$count pins on the map',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 12,
            runSpacing: 7,
            children: [
              for (final (label, color) in entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: OgeraColors.muted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapError extends StatelessWidget {
  const _MapError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OgeraColors.surface,
        borderRadius: BorderRadius.circular(OgeraSpacing.cardRadius),
        border: Border.all(color: OgeraColors.danger.withValues(alpha: 0.3)),
        boxShadow: OgeraColors.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: OgeraColors.danger,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Kept here so the map screen and the sheets share one dependency surface.
LocationApiService locationApiOf(BuildContext context) =>
    context.read<LocationApiService>();

