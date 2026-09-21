import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/models/staff_location.dart';
import 'package:ogera_crm_mobile/services/location_queue.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// [LocationQueue] talks to real `sqflite`, which has no platform
/// implementation inside `flutter_test`. `sqflite_common_ffi` swaps in a
/// native-SQLite-backed factory so the exact same [LocationQueue] code runs
/// against a real (if temporary) database file, rather than a hand-rolled
/// in-memory fake — this is what actually exercises the SQL.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocationQueue queue;
  late String dbName;

  setUp(() {
    // A fresh, uniquely-named DB per test avoids state leaking between tests
    // (sqflite caches open databases by path).
    dbName = 'test_${DateTime.now().microsecondsSinceEpoch}.db';
    queue = LocationQueue(databaseName: dbName);
  });

  tearDown(() async {
    await queue.clear();
    await queue.close();
  });

  PendingPoint point({int? localId, DateTime? recordedAt, bool isMoving = true}) {
    return PendingPoint(
      localId: localId,
      latitude: 11.2588,
      longitude: 75.7804,
      recordedAt: recordedAt ?? DateTime.utc(2026, 9, 10, 9),
      isMoving: isMoving,
    );
  }

  test('a new queue starts empty', () async {
    expect(await queue.count(), 0);
    expect(await queue.take(10), isEmpty);
  });

  test('add() persists a point and count() reflects it', () async {
    await queue.add(point());

    expect(await queue.count(), 1);
  });

  test('take(n) returns oldest-first without removing anything', () async {
    await queue.add(point(recordedAt: DateTime.utc(2026, 9, 10, 9, 2)));
    await queue.add(point(recordedAt: DateTime.utc(2026, 9, 10, 9, 0)));
    await queue.add(point(recordedAt: DateTime.utc(2026, 9, 10, 9, 1)));

    final batch = await queue.take(2);

    expect(batch, hasLength(2));
    expect(batch[0].recordedAt, DateTime.utc(2026, 9, 10, 9, 0));
    expect(batch[1].recordedAt, DateTime.utc(2026, 9, 10, 9, 1));
    expect(await queue.count(), 3, reason: 'take() must not remove rows');
  });

  test('remove() deletes exactly the given rows, leaving the rest queued', () async {
    await queue.add(point(recordedAt: DateTime.utc(2026, 9, 10, 9, 0)));
    await queue.add(point(recordedAt: DateTime.utc(2026, 9, 10, 9, 1)));
    await queue.add(point(recordedAt: DateTime.utc(2026, 9, 10, 9, 2)));

    final toRemove = await queue.take(2);
    await queue.remove(toRemove);

    final remaining = await queue.take(10);
    expect(remaining, hasLength(1));
    expect(remaining.single.recordedAt, DateTime.utc(2026, 9, 10, 9, 2));
  });

  test('remove() ignores points with no localId rather than deleting everything', () async {
    await queue.add(point());
    final phantom = point(localId: null);

    await queue.remove([phantom]);

    expect(await queue.count(), 1, reason: 'a point never written should delete nothing');
  });

  test('clear() empties the queue', () async {
    await queue.add(point());
    await queue.add(point(recordedAt: DateTime.utc(2026, 9, 10, 9, 1)));

    await queue.clear();

    expect(await queue.count(), 0);
  });

  test('a point round-trips every field through storage', () async {
    await queue.add(
      PendingPoint(
        latitude: 11.9999,
        longitude: 76.0001,
        recordedAt: DateTime.utc(2026, 9, 10, 9, 30, 15),
        accuracy: 4.5,
        speed: 1.2,
        heading: 87.5,
        batteryLevel: 42,
        isMoving: false,
      ),
    );

    final stored = (await queue.take(1)).single;

    expect(stored.latitude, 11.9999);
    expect(stored.longitude, 76.0001);
    expect(stored.recordedAt, DateTime.utc(2026, 9, 10, 9, 30, 15));
    expect(stored.accuracy, 4.5);
    expect(stored.speed, 1.2);
    expect(stored.heading, 87.5);
    expect(stored.batteryLevel, 42);
    expect(stored.isMoving, isFalse);
    expect(stored.localId, isNotNull);
  });

  test('points survive re-opening the queue against the same store', () async {
    await queue.add(point());
    await queue.close();

    final reopened = LocationQueue(databaseName: dbName);

    expect(await reopened.count(), 1);
    await reopened.close();
  });

  test('trims the oldest rows once the queue exceeds maxPoints', () async {
    // maxPoints is 2000; adding one past it should drop exactly the single
    // oldest row rather than trimming to some other size.
    for (var i = 0; i < LocationQueue.maxPoints; i++) {
      await queue.add(point(recordedAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: i))));
    }
    expect(await queue.count(), LocationQueue.maxPoints);

    await queue.add(point(recordedAt: DateTime.utc(2027, 1, 1)));

    expect(await queue.count(), LocationQueue.maxPoints);
    final oldestRemaining = (await queue.take(1)).single;
    expect(
      oldestRemaining.recordedAt,
      DateTime.utc(2026, 1, 1).add(const Duration(minutes: 1)),
      reason: 'exactly the single oldest row (minute 0) should have been trimmed',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
