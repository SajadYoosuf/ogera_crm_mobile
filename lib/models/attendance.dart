/// Represents a single daily field check-in/check-out session.
///
/// Maps to the backend `StaffAttendance` model at GET/POST /attendance/*.
/// [isOpen] is true while the employee is still checked in (no checkout time yet).
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.checkinAt,
    this.checkoutAt,
    this.checkinLat,
    this.checkinLng,
    required this.isOpen,
  });

  final int id;
  final DateTime date;
  final DateTime checkinAt;
  final DateTime? checkoutAt;
  final double? checkinLat;
  final double? checkinLng;

  /// True while the session has no checkout time.
  final bool isOpen;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      checkinAt: DateTime.parse(json['checkin_at'] as String),
      checkoutAt: json['checkout_at'] != null
          ? DateTime.parse(json['checkout_at'] as String)
          : null,
      checkinLat: (json['checkin_lat'] as num?)?.toDouble(),
      checkinLng: (json['checkin_lng'] as num?)?.toDouble(),
      isOpen: json['is_open'] as bool? ?? true,
    );
  }
}
