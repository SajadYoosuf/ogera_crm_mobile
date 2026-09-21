import 'package:ogera_crm_mobile/models/staff_location.dart';
import 'package:ogera_crm_mobile/services/location_queue.dart';

/// An in-memory stand-in for [LocationQueue] so tests don't need a real
/// sqflite database or platform channel. Assigns incrementing local ids the
/// same way sqflite's `AUTOINCREMENT` would, since
/// `LocationTrackingService.flush()` keys removal off [PendingPoint.localId].
class FakeLocationQueue implements LocationQueue {
  final List<PendingPoint> _rows = [];
  int _nextId = 1;
  bool throwOnCount = false;

  /// Everything currently queued, oldest first — for assertions.
  List<PendingPoint> get rows => List.unmodifiable(_rows);

  @override
  Future<void> add(PendingPoint point) async {
    _rows.add(
      PendingPoint(
        localId: _nextId++,
        latitude: point.latitude,
        longitude: point.longitude,
        recordedAt: point.recordedAt,
        accuracy: point.accuracy,
        speed: point.speed,
        heading: point.heading,
        batteryLevel: point.batteryLevel,
        isMoving: point.isMoving,
      ),
    );
  }

  @override
  Future<List<PendingPoint>> take(int limit) async {
    return _rows.take(limit).toList(growable: false);
  }

  @override
  Future<void> remove(List<PendingPoint> points) async {
    final ids = points.map((point) => point.localId).whereType<int>().toSet();
    _rows.removeWhere((row) => ids.contains(row.localId));
  }

  @override
  Future<int> count() async {
    if (throwOnCount) throw StateError('queue read failed');
    return _rows.length;
  }

  @override
  Future<void> clear() async => _rows.clear();

  @override
  Future<void> close() async {}
}
