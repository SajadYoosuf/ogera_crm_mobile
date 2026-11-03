/// A location point that was accepted by the server and written to history.
class StaffLocationHistoryPoint {
  const StaffLocationHistoryPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;

  factory StaffLocationHistoryPoint.fromJson(Map<String, dynamic> json) {
    return StaffLocationHistoryPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      recordedAt: DateTime.parse(
        (json['recorded_at'] ?? json['recordedAt']) as String,
      ),
    );
  }
}
