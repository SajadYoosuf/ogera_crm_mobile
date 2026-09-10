# Staff Location Map Flow

This document explains the live staff location system in simple terms.

## Quick Summary

Staff phones collect GPS points and upload them to the server.

The server stores the data in two tables:

- `staff_live_locations` keeps only the latest location for each staff member.
- `staff_location_history` keeps the full route history.

Head/admin users read these locations on the map.

Staff users only upload their own location and can view their own route.

## Full Flow

```text
Staff phone
  -> gets GPS location
  -> saves it in local SQLite queue
  -> uploads queued points to server
  -> server writes MySQL tables
  -> head/admin map reads latest locations
```

## 1. Staff Phone

The mobile app starts tracking only after location permission is allowed.

Important file:

```text
lib/services/location_tracking_service.dart
```

The phone records a point:

- immediately after the first GPS fix
- when staff moves 100 meters
- every 60 seconds while moving
- every 5 minutes while staying in one place

The app does not send GPS directly to the server first. It saves every point locally first.

## 2. Local Queue

Important file:

```text
lib/services/location_queue.dart
```

The queue is a small SQLite database on the phone.

Why it exists:

- if internet is off, points are not lost
- failed uploads can retry later
- rows are deleted only after the server accepts them

The queue keeps up to 2000 points. If it becomes full, old points are removed first.

## 3. Upload To Server

Important file:

```text
lib/services/location_api_service.dart
```

The phone uploads points to:

```text
POST /api/staff/locations
```

Each point contains:

```json
{
  "latitude": 11.258812,
  "longitude": 75.780412,
  "recordedAt": "2026-09-10T08:52:31.000Z",
  "accuracy": 8.4,
  "speed": 1.2,
  "heading": 145,
  "batteryLevel": 82,
  "isMoving": true
}
```

The user id is not trusted from the phone body. The server uses the logged-in user's token.

So a staff member can only upload their own location.

## 4. Server Database

Migration file:

```text
migrations/005_staff_location_tracking.sql
```

### `staff_live_locations`

One row per staff member.

Used for the live map because it is fast.

Main fields:

- `user_id`
- `latitude`
- `longitude`
- `accuracy`
- `speed`
- `heading`
- `battery_level`
- `is_moving`
- `recorded_at`
- `state`

The primary key is `user_id`, so each staff member has only one latest row.

### `staff_location_history`

Many rows per staff member.

Used for route history and "My Route Today".

Main fields:

- `user_id`
- `latitude`
- `longitude`
- `accuracy`
- `speed`
- `heading`
- `battery_level`
- `recorded_at`

There is a unique key on:

```text
user_id + recorded_at
```

That makes upload retry safe. The same point will not be inserted twice.

## 5. Server APIs

Server files:

```text
src/app/api/staff/locations/route.ts
src/app/api/staff/locations/state/route.ts
src/app/api/staff/locations/live/route.ts
src/app/api/staff/locations/history/route.ts
src/app/api/staff/locations/me/route.ts
```

APIs:

| API | Who uses it | Purpose |
| --- | --- | --- |
| `POST /api/staff/locations` | Staff phone | Upload queued GPS points |
| `POST /api/staff/locations/state` | Staff phone | Report tracking on/off/signed out |
| `GET /api/staff/locations/live` | Head/admin | Get latest location of staff |
| `GET /api/staff/locations/history` | Head/admin | Get one staff member's route |
| `GET /api/staff/locations/me` | Staff phone | Get own route |

## 6. Live Location Write Logic

When the server receives a batch:

1. It inserts points into `staff_location_history`.
2. Duplicate points are ignored.
3. It finds the newest point in the batch.
4. It updates `staff_live_locations` only if that point is newer than the current live row.

This is important because old offline data may upload later.

Old data should go into history, but it should not replace a newer live location.

## 7. Tracking State

The app can report these states:

```text
tracking_enabled
location_disabled
signed_out
```

These are stored in `staff_live_locations.state`.

This helps the map show the right meaning:

- location is live
- location permission is off
- staff signed out
- staff has not reported recently

## 8. Head/Admin Live Map

The live map reads:

```text
GET /api/staff/locations/live
```

It returns the latest row for each active staff member.

The map decides status from `recordedAt`:

- last point within 5 minutes: `Live`
- last point within 60 minutes: `Last seen`
- older than 60 minutes: `Offline`
- server says `location_disabled`: `Location off`

The mobile map refreshes live staff locations every 20 seconds while the staff layer is open.

Important files:

```text
lib/view_models/map_view_model.dart
lib/models/staff_location.dart
lib/views/map/map_tab.dart
lib/views/map/staff_sheet.dart
```

## 9. Route History

Head/admin can open one staff member's route for one day.

API:

```text
GET /api/staff/locations/history?userId=123&date=2026-09-10
```

Staff can view their own route:

```text
GET /api/staff/locations/me?date=2026-09-10
```

The route uses `staff_location_history`.

The system calculates:

- total distance
- first seen time
- last seen time
- stops

A stop means the staff member stayed inside about 60 meters for at least 10 minutes.

## 10. Permissions

Staff:

- can upload own location
- can report own tracking state
- can view own route

Head/admin:

- can view live staff locations
- can view any staff route history

The server checks access using bearer tokens.

Important file:

```text
src/lib/auth/guard.ts
```

## 11. Important Notes

- MySQL stores location times in UTC.
- The server sends timestamps back with `Z` to avoid timezone confusion.
- Route day filtering uses India local day, not UTC day.
- Failed uploads stay in the phone queue.
- The live map does not use WebSocket right now. It uses polling.
- Web `StaffLiveMap.tsx` currently contains a simulated/demo live map. The real mobile staff map reads the `/api/staff/locations/live` endpoint.

## File Map

| File | Meaning |
| --- | --- |
| `lib/services/location_tracking_service.dart` | Captures GPS and decides when to record |
| `lib/services/location_queue.dart` | Local offline queue |
| `lib/services/location_api_service.dart` | Calls location APIs |
| `lib/models/staff_location.dart` | Staff location, state, route models |
| `lib/view_models/map_view_model.dart` | Loads map layers and polls live data |
| `src/app/api/staff/locations/route.ts` | Stores uploaded points |
| `src/app/api/staff/locations/live/route.ts` | Returns latest staff locations |
| `src/app/api/staff/locations/history/route.ts` | Returns staff route history |
| `src/app/api/staff/locations/me/route.ts` | Returns own route |
| `src/app/api/staff/locations/state/route.ts` | Stores tracking state |
| `src/lib/staffLocations.ts` | Shared server helpers for time, routes, stops |
| `migrations/005_staff_location_tracking.sql` | Creates the two tracking tables |
