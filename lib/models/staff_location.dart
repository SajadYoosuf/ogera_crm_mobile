import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/utils/formatters.dart';
import '../core/utils/staff_palette.dart';
import '../theme/ogera_colors.dart';

/// The four states the head map renders. The thresholds are the ones fixed in
/// §4.2.3 of the mobile PRD; the server may also assert a state directly when
/// the device reported that tracking was switched off.
enum StaffState {
  moving('Moving', OgeraColors.success, Icons.directions_walk_rounded),
  stuck('Stuck', OgeraColors.warning, Icons.pause_circle_outline_rounded),
  connectionLost('Connection lost', OgeraColors.muted, Icons.cloud_off_rounded),
  locationDisabled(
    'Location off',
    OgeraColors.danger,
    Icons.location_disabled_rounded,
  );

  const StaffState(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  static StaffState fromServer(String? value) => switch (value) {
    'moving' => StaffState.moving,
    'stuck' => StaffState.stuck,
    'location_disabled' => StaffState.locationDisabled,
    'signed_out' || 'connection_lost' => StaffState.connectionLost,
    _ => StaffState.connectionLost,
  };
}

/// One staff member's newest known position, as shown on the head map.
class StaffLocation {
  const StaffLocation({
    required this.userId,
    required this.name,
    required this.position,
    required this.state,
    this.phone,
    this.accuracy,
    this.speed,
    this.heading,
    this.batteryLevel,
    this.recordedAt,
    this.colorIndex,
    this.address,
  });

  final int userId;
  final String name;
  final LatLng position;
  final StaffState state;
  final String? phone;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final int? batteryLevel;
  final DateTime? recordedAt;
  final int? colorIndex;

  /// Resolved and persisted by the backend before managers receive the row.
  final String? address;

  Color get color => StaffPalette.fromIndex(colorIndex, userId);

  String get lastSeenLabel =>
      recordedAt == null ? 'No location yet' : formatRelative(recordedAt!);

  StaffLocation copyWith({String? address}) {
    return StaffLocation(
      userId: userId,
      name: name,
      position: position,
      state: state,
      phone: phone,
      accuracy: accuracy,
      speed: speed,
      heading: heading,
      batteryLevel: batteryLevel,
      recordedAt: recordedAt,
      colorIndex: colorIndex,
      address: address ?? this.address,
    );
  }

  static StaffLocation? fromJson(Map<String, dynamic> json) {
    final lat = asDouble(json['latitude']);
    final lng = asDouble(json['longitude']);
    if (lat == null || lng == null) return null;
    final recordedAt = parseDate(json['recordedAt']);
    return StaffLocation(
      userId: asInt(json['userId']) ?? 0,
      name: asText(json['name']) ?? 'Staff',
      position: LatLng(lat, lng),
      state: StaffState.fromServer(asText(json['state'])),
      phone: asText(json['phone']),
      accuracy: asDouble(json['accuracy']),
      speed: asDouble(json['speed']),
      heading: asDouble(json['heading']),
      batteryLevel: asInt(json['batteryLevel']),
      recordedAt: recordedAt,
      colorIndex: asInt(json['colorIndex']),
      address: asText(json['address']),
    );
  }
}

/// A single recorded position on a route.
class RoutePoint {
  const RoutePoint({
    required this.position,
    required this.recordedAt,
    this.address,
    this.state,
  });

  final LatLng position;
  final DateTime recordedAt;
  final String? address;
  final StaffState? state;

  static RoutePoint? fromJson(Map<String, dynamic> json) {
    final lat = asDouble(json['latitude']);
    final lng = asDouble(json['longitude']);
    final recordedAt = parseDate(json['recordedAt']);
    if (lat == null || lng == null || recordedAt == null) return null;
    return RoutePoint(
      position: LatLng(lat, lng),
      recordedAt: recordedAt,
      address: asText(json['address']),
      state: json['state'] == null
          ? null
          : StaffState.fromServer(asText(json['state'])),
    );
  }
}

/// A place the staff member stayed longer than [StaffRoute.stopThreshold].
class RouteStop {
  RouteStop({
    required this.position,
    required this.arrivedAt,
    required this.leftAt,
    this.address,
  });

  final LatLng position;
  final DateTime arrivedAt;
  DateTime leftAt;
  String? address;

  Duration get dwell => leftAt.difference(arrivedAt);
}

/// One staff member's route for one day, with the summary the sheet shows.
class StaffRoute {
  StaffRoute({
    required this.userId,
    required this.date,
    required this.points,
    required this.stops,
    required this.distanceMeters,
    this.firstSeen,
    this.lastSeen,
  });

  final int userId;
  final String date;
  final List<RoutePoint> points;
  final List<RouteStop> stops;
  final double distanceMeters;
  final DateTime? firstSeen;
  final DateTime? lastSeen;

  static const stopThreshold = Duration(minutes: 10);
  static const stopRadiusMeters = 60.0;

  bool get isEmpty => points.isEmpty;

  List<LatLng> get polyline =>
      points.map((point) => point.position).toList(growable: false);

  factory StaffRoute.empty(int userId, String date) => StaffRoute(
    userId: userId,
    date: date,
    points: const [],
    stops: const [],
    distanceMeters: 0,
  );

  /// Builds the route from raw points. The server sends the summary when it
  /// can, but the app derives whatever is missing so a plain point list still
  /// renders a complete sheet.
  factory StaffRoute.fromJson(
    int userId,
    String date,
    Map<String, dynamic> json,
  ) {
    final raw = (json['points'] as List?) ?? const [];
    final points =
        raw
            .whereType<Map<String, dynamic>>()
            .map(RoutePoint.fromJson)
            .whereType<RoutePoint>()
            .toList()
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    final distance = asDouble(json['distanceMeters']) ?? _distanceOf(points);
    return StaffRoute(
      userId: userId,
      date: date,
      points: points,
      stops: _stopsOf(points),
      distanceMeters: distance,
      firstSeen:
          parseDate(json['firstSeen']) ??
          (points.isEmpty ? null : points.first.recordedAt),
      lastSeen:
          parseDate(json['lastSeen']) ??
          (points.isEmpty ? null : points.last.recordedAt),
    );
  }

  static double _distanceOf(List<RoutePoint> points) {
    const calculator = Distance();
    var total = 0.0;
    for (var index = 1; index < points.length; index++) {
      total += calculator.as(
        LengthUnit.Meter,
        points[index - 1].position,
        points[index].position,
      );
    }
    return total;
  }

  /// Groups consecutive points that stay inside [stopRadiusMeters] and span at
  /// least [stopThreshold] — those are the visits worth marking on the map.
  static List<RouteStop> _stopsOf(List<RoutePoint> points) {
    const calculator = Distance();
    final stops = <RouteStop>[];
    var index = 0;
    while (index < points.length) {
      final anchor = points[index];
      var last = index;
      for (var probe = index + 1; probe < points.length; probe++) {
        final drift = calculator.as(
          LengthUnit.Meter,
          anchor.position,
          points[probe].position,
        );
        if (drift > stopRadiusMeters) break;
        last = probe;
      }
      final span = points[last].recordedAt.difference(anchor.recordedAt);
      if (last > index && span >= stopThreshold) {
        stops.add(
          RouteStop(
            position: _centroid(points.sublist(index, last + 1)),
          arrivedAt: anchor.recordedAt,
          leftAt: points[last].recordedAt,
          address: points[last].address ?? anchor.address,
          ),
        );
        index = last + 1;
      } else {
        index++;
      }
    }
    return stops;
  }

  static LatLng _centroid(List<RoutePoint> group) {
    var lat = 0.0;
    var lng = 0.0;
    for (final point in group) {
      lat += point.position.latitude;
      lng += point.position.longitude;
    }
    return LatLng(lat / group.length, lng / group.length);
  }

  /// Bounds padded slightly so the polyline never touches the map edge.
  ({LatLng southWest, LatLng northEast})? get bounds {
    if (points.isEmpty) return null;
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final point in points) {
      minLat = math.min(minLat, point.position.latitude);
      maxLat = math.max(maxLat, point.position.latitude);
      minLng = math.min(minLng, point.position.longitude);
      maxLng = math.max(maxLng, point.position.longitude);
    }
    return (
      southWest: LatLng(minLat - 0.002, minLng - 0.002),
      northEast: LatLng(maxLat + 0.002, maxLng + 0.002),
    );
  }
}

/// A position captured on the device and waiting to be uploaded.
class PendingPoint {
  const PendingPoint({
    this.localId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracy,
    this.speed,
    this.heading,
    this.batteryLevel,
    this.isMoving = true,
  });

  final int? localId;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final int? batteryLevel;
  final bool isMoving;

  /// The server contract intentionally contains only the location, its capture
  /// time, and Moving/Stuck. Device telemetry stays local to the tracker.
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'isMoving': isMoving,
  };

  Map<String, Object?> toRow() => {
    'latitude': latitude,
    'longitude': longitude,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    'accuracy': accuracy,
    'speed': speed,
    'heading': heading,
    'battery_level': batteryLevel,
    'is_moving': isMoving ? 1 : 0,
  };

  factory PendingPoint.fromRow(Map<String, Object?> row) {
    return PendingPoint(
      localId: asInt(row['id']),
      latitude: asDouble(row['latitude']) ?? 0,
      longitude: asDouble(row['longitude']) ?? 0,
      recordedAt: parseDate(row['recorded_at']) ?? DateTime.now(),
      accuracy: asDouble(row['accuracy']),
      speed: asDouble(row['speed']),
      heading: asDouble(row['heading']),
      batteryLevel: asInt(row['battery_level']),
      isMoving: asInt(row['is_moving']) == 1,
    );
  }
}
