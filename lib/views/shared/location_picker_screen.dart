import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../services/geocoding_service.dart';
import '../../theme/ogera_colors.dart';

/// The coordinate a form captured, with the address it resolved to.
class PickedLocation {
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String? address;

  String get latitudeText => latitude.toStringAsFixed(6);
  String get longitudeText => longitude.toStringAsFixed(6);
}

/// Drop-a-pin map picker. The pin stays fixed at the centre of the viewport and
/// the map moves under it — steadier on a phone than dragging a marker, and it
/// works with one thumb.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final PickedLocation? initial;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapController = MapController();

  static const _fallbackCentre = LatLng(11.2588, 75.7804);

  late LatLng _centre = widget.initial == null
      ? _fallbackCentre
      : LatLng(widget.initial!.latitude, widget.initial!.longitude);

  String? _address;
  bool _isResolving = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _address = widget.initial?.address;
    if (widget.initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _useMyLocation());
    } else {
      _resolveAddress();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          showToast(
            context,
            'Location permission is needed to drop a pin here.',
            isError: true,
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final target = LatLng(position.latitude, position.longitude);
      _mapController.move(target, 17);
      setState(() => _centre = target);
      await _resolveAddress();
    } catch (_) {
      if (mounted) {
        showToast(
          context,
          'Could not read your location. Try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Runs when the map settles, not on every frame of a drag — Nominatim allows
  /// one request a second and the queue would otherwise fill with throwaways.
  Future<void> _resolveAddress() async {
    setState(() => _isResolving = true);
    final geocoding = context.read<GeocodingService>();
    final resolved = await geocoding.resolve(_centre);
    if (!mounted) return;
    setState(() {
      _address = resolved;
      _isResolving = false;
    });
  }

  void _confirm() {
    Navigator.of(context).pop(
      PickedLocation(
        latitude: _centre.latitude,
        longitude: _centre.longitude,
        address: _address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick location'),
        actions: [
          TextButton(onPressed: _confirm, child: const Text('Use this')),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centre,
              initialZoom: widget.initial == null ? 11 : 17,
              onPositionChanged: (position, _) => _centre = position.center,
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) _resolveAddress();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: AppConfig.osmTileUrl,
                userAgentPackageName: AppConfig.osmTilePackage,
                maxNativeZoom: 19,
              ),
            ],
          ),
          // The pin sits above the map centre; its tip marks the coordinate.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -18),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 46,
                  color: OgeraColors.danger,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 8)],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 168,
            child: FloatingActionButton.small(
              heroTag: 'picker-locate',
              backgroundColor: OgeraColors.surface,
              foregroundColor: OgeraColors.blue,
              onPressed: _isLocating ? null : _useMyLocation,
              child: _isLocating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : const Icon(Icons.my_location_rounded),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _PickerSheet(
              centre: _centre,
              address: _address,
              isResolving: _isResolving,
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.centre,
    required this.address,
    required this.isResolving,
    required this.onConfirm,
  });

  final LatLng centre;
  final String? address;
  final bool isResolving;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        18 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: OgeraColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: OgeraColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.place_outlined,
                size: 19,
                color: OgeraColors.blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isResolving)
                      const Text(
                        'Finding address…',
                        style: TextStyle(
                          fontSize: 14,
                          color: OgeraColors.muted,
                        ),
                      )
                    else
                      Text(
                        address ?? 'Address not available for this point',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      GeocodingService.coordinateLabel(centre),
                      style: const TextStyle(
                        fontSize: 12,
                        color: OgeraColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check_rounded, size: 19),
            label: const Text('Use this location'),
          ),
        ],
      ),
    );
  }
}
