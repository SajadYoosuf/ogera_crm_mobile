/// The employee's last GPS position stored on the server.
///
/// Maps to GET /staff/location/me. The server keeps one row per employee and
/// overwrites it with each background ping, so this is "where the phone last
/// reported", not a live fix. [recordedAt] is the server's UTC time.
class StaffLastLocation {
  const StaffLastLocation({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;

  factory StaffLastLocation.fromJson(Map<String, dynamic> json) {
    return StaffLastLocation(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }
}
