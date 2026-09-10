import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/ogera_widgets.dart';
import '../../services/geocoding_service.dart';
import '../../theme/ogera_colors.dart';
import 'location_picker_screen.dart';

/// Captures the coordinates a contact or professional record is plotted from.
///
/// Two paths, because both matter in the field: "Use my location" for a record
/// created while standing at the site, and "Pick on map" for one entered later
/// from the office.
class LocationCaptureField extends StatefulWidget {
  const LocationCaptureField({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    this.address,
  });

  final String? latitude;
  final String? longitude;
  final String? address;

  /// Address is passed back too — the forms write it into their address field
  /// when it is still empty.
  final void Function(String? latitude, String? longitude, String? address)
  onChanged;

  @override
  State<LocationCaptureField> createState() => _LocationCaptureFieldState();
}

class _LocationCaptureFieldState extends State<LocationCaptureField> {
  bool _isLocating = false;

  bool get _hasLocation =>
      (widget.latitude ?? '').isNotEmpty && (widget.longitude ?? '').isNotEmpty;

  LatLng? get _position {
    final lat = double.tryParse(widget.latitude ?? '');
    final lng = double.tryParse(widget.longitude ?? '');
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Future<void> _useMyLocation() async {
    setState(() => _isLocating = true);
    final geocoding = context.read<GeocodingService>();
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
            'Allow location access to capture GPS.',
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
      final point = LatLng(position.latitude, position.longitude);
      // The coordinate is saved immediately; the address catches up when
      // Nominatim answers, so a poor connection never blocks the capture.
      widget.onChanged(
        position.latitude.toStringAsFixed(6),
        position.longitude.toStringAsFixed(6),
        null,
      );
      final address = await geocoding.resolve(point);
      if (!mounted) return;
      widget.onChanged(
        position.latitude.toStringAsFixed(6),
        position.longitude.toStringAsFixed(6),
        address,
      );
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

  Future<void> _pickOnMap() async {
    final current = _position;
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initial: current == null
              ? null
              : PickedLocation(
                  latitude: current.latitude,
                  longitude: current.longitude,
                  address: widget.address,
                ),
        ),
      ),
    );
    if (picked == null) return;
    widget.onChanged(picked.latitudeText, picked.longitudeText, picked.address);
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _hasLocation ? OgeraColors.blueSoft : const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
          border: Border.all(
            color: _hasLocation
                ? OgeraColors.blue.withValues(alpha: 0.3)
                : OgeraColors.line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _hasLocation
                      ? Icons.location_on_rounded
                      : Icons.location_off_outlined,
                  size: 19,
                  color: _hasLocation ? OgeraColors.blue : OgeraColors.muted,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _hasLocation ? 'Location captured' : 'No location yet',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        position == null
                            ? 'Add GPS so this record appears on the map.'
                            : GeocodingService.coordinateLabel(position),
                        style: const TextStyle(
                          fontSize: 12,
                          color: OgeraColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hasLocation)
                  IconButton(
                    tooltip: 'Remove location',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => widget.onChanged(null, null, null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLocating ? null : _useMyLocation,
                    icon: _isLocating
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded, size: 17),
                    label: Text(_isLocating ? 'Locating…' : 'Use my location'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickOnMap,
                    icon: const Icon(Icons.map_outlined, size: 17),
                    label: const Text('Pick on map'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
