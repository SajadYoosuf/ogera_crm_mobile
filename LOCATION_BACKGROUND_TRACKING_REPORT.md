# Live Location Tracking — Android Background Workflow & Minimize Bug

Scope: Android only, staff app. Covers the full path from GPS fix to server upload,
with a focus on what changes the instant the app is minimized (Home button /
switched away, task still alive in Recents) — which is the reported failure point.

Companion doc: `STAFF_LOCATION_MAP_FLOW.md` covers the end-to-end product flow
including the backend and manager map. This report goes one level deeper on the
Android native/OS layer, which that doc treats as a black box.

---

## 1. The three layers involved

```text
┌─────────────────────────────────────────────────────────────┐
│ Layer 3 — Backend (Next.js API routes, MySQL)                │
│   POST /api/staff/locations  ·  staff_live_locations table   │
└───────────────────────────▲───────────────────────────────────┘
                             │ HTTPS, batched, retried
┌───────────────────────────┴───────────────────────────────────┐
│ Layer 2 — Flutter app (Dart, single isolate)                  │
│   LocationTrackingService → LocationQueue (SQLite) → API      │
└───────────────────────────▲───────────────────────────────────┘
                             │ Position stream / one-shot fixes
┌───────────────────────────┴───────────────────────────────────┐
│ Layer 1 — Android OS + geolocator_android plugin               │
│   FusedLocationProviderClient · GeolocatorLocationService       │
│   (foreground service) · Doze / App Standby / OEM killers       │
└─────────────────────────────────────────────────────────────┘
```

The bug lives at the boundary between Layer 1 and Layer 2: Android decides
whether the app is even *allowed* to receive a location fix while backgrounded,
and that decision is made per-permission-grant, not per-line-of-Dart-code.

---

## 2. How it works today, step by step

### 2.1 Permission model in the code

File: `lib/services/location_tracking_service.dart`

```dart
Future<LocationPermissionState> requestPermission() async {
  ...
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();   // (A) foreground prompt
  }
  final state = _mapPermission(permission);
  if (state == LocationPermissionState.grantedForeground) {
    final upgraded = await Geolocator.requestPermission(); // (B) "background upgrade"
    return _mapPermission(upgraded);
  }
  return state;
}
```

`LocationPermissionState.canTrack` is true for **both** `granted` (Android
"Allow all the time") and `grantedForeground` (Android "While using the app").
The location gate (`lib/views/location_gate_screen.dart`) only checks
`canTrack`, so a staff member who grants "While using the app" — and nothing
else — passes the gate and the app behaves as if tracking is fully working.

### 2.2 Starting the tracker

File: `lib/services/location_tracking_service.dart`, `start()`

```dart
_positions = Geolocator.getPositionStream(
  locationSettings: _settings(background: state == LocationPermissionState.granted),
).listen(_onPosition, ...);

_cadenceTimer = Timer.periodic(heartbeatInterval, (_) => _tick()); // every 60s
```

`_settings(background: true)` is the only branch that attaches
`AndroidSettings.foregroundNotificationConfig`, which is what tells
`geolocator_android` to start a real Android **foreground service**
(`com.baseflow.geolocator.GeolocatorLocationService`, declared with
`android:foregroundServiceType="location"` in the plugin's own manifest) and
show the persistent "Sharing your location…" notification.

If the user only granted "While using the app", `background` is `false`,
`foregroundNotificationConfig` is `null`, and **no foreground service is ever
started**. The position stream is a plain foreground-only location request.

### 2.3 Recording and uploading

- `_tick()` runs every 60 s, asks for a fresh fix, and calls `_maybeRecord`.
- `_maybeRecord` writes a point to `LocationQueue` (local SQLite,
  `lib/services/location_queue.dart`) when the device has moved ≥20 m, is
  moving ≥0.8 m/s, or 60 s have elapsed since the last recorded point.
- `flush()` drains the queue in batches of 10 to
  `POST /api/staff/locations` (`lib/services/location_api_service.dart`).
  A failed flush leaves rows in the queue and backs off for 2 minutes; it
  never drops data on its own.

This queue-first design is correct and is **not** the source of the minimize
bug — it means once a fix reaches the Dart side, it will eventually reach the
server. The bug is upstream: fixes stop arriving at all.

---

## 3. What Android actually does when the app is minimized

"Minimized" here means: user presses Home, or switches to another app. The
process and its Activity are stopped/paused, but the task still exists in
Recents (this is distinct from swiping the app away, covered in §4).

### 3.1 Case A — permission is "Allow all the time" *and* the foreground
service notification is showing

This is the only configuration Android's location APIs are designed to
support for continuous background tracking:

- The foreground service keeps the process at `IMPORTANCE_FOREGROUND`,
  exempting it from Doze/App Standby background execution limits.
- `FusedLocationProviderClient` keeps delivering fixes to the stream at the
  configured interval (`AndroidSettings.intervalDuration = 30s` here).
- The Dart `Timer.periodic` in `_tick()` keeps firing because the Flutter
  engine's isolate is still alive and scheduled (foreground service =
  process not frozen).

In this case, minimizing the app should **not** stop tracking. If it still
does on a device configured this way, the cause is almost always an OEM
battery manager (see §4.2), not this app's code.

### 3.2 Case B — permission is "While using the app" only (no background
grant)

This is what happens for essentially every staff member today, and it is the
primary cause of the reported bug. Reasoning:

1. `_settings(background: false)` is used → no foreground service is started
   → the app never gets the "sharing your location" notification, and no
   evidence is presented to the OS that this app deserves background
   execution.
2. Once the Activity is stopped, Android reclassifies the process as a
   *cached/background* process (`IMPORTANCE_CACHED` or similar) within
   seconds to a couple of minutes.
3. **Android does not deliver location updates to a background process that
   lacks `ACCESS_BACKGROUND_LOCATION`.** This is an OS-level rule (since
   Android 10 / API 29), not something `geolocator` or this app can code
   around: a foreground-only grant is defined by Android to mean "location
   only while the app is visible/in-use." `Geolocator.getCurrentPosition()`
   called from `_tick()` will time out or throw once the app is backgrounded
   long enough for the OS to apply this — which is exactly what shows up as
   "not getting the location data and not sending."
4. Because the OS silently withholds the fix rather than throwing a permission
   error, the app has no explicit "background denied" signal to act on — it
   just stops getting fresh positions, which is why this looks like a bug
   rather than an expected permission state.

### 3.3 Why almost every device ends up in Case B

Since **Android 11 (API 30)**, the OS deliberately removed the ability to ask
for foreground and background location in the same permission flow. There is
no system dialog that upgrades "While using the app" to "Allow all the time"
in-app anymore — the only path is Settings → Apps → Ogera CRM → Permissions →
Location → "Allow all the time", done manually by the user outside the app.

Look again at step (B) in §2.1:

```dart
if (state == LocationPermissionState.grantedForeground) {
  final upgraded = await Geolocator.requestPermission(); // no dialog on API 30+
  return _mapPermission(upgraded);
}
```

On Android 11+ this second `requestPermission()` call has no system dialog to
show for the upgrade; it simply returns `whileInUse` again. The code has no
fallback for this — `LocationPermissionState.needsSettings` is `true` only for
`deniedForever` and `serviceDisabled` (`lib/services/location_tracking_service.dart:29-31`),
**not** for `grantedForeground`. So the location gate screen
(`lib/views/location_gate_screen.dart`) never tells the user "open Settings and
choose Allow all the time" — it treats foreground-only as success and lets
the user into the app.

Net effect: on real Android 11+ devices (i.e. nearly the entire current
Android install base), staff almost never end up with "Allow all the time"
unless they happen to go find that setting themselves. Tracking then works
correctly while the app is open and on-screen, and silently stops the moment
it's minimized — matching the exact symptom reported.

---

## 4. Secondary causes worth ruling out separately

These can each independently break background tracking even when permission
*is* "Allow all the time," so they matter if some devices still fail after
fixing §3.

### 4.1 Swiping the app away from Recents (task removal), not just minimizing

`geolocator_android`'s own manifest (`geolocator_android-5.0.3/android/src/main/AndroidManifest.xml`)
declares its foreground service like this:

```xml
<service
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="location"
    android:name=".GeolocatorLocationService"/>
```

There is no `android:stopWithTask="false"` override, so the default
(`stopWithTask="true"`) applies: removing the app's task from Recents stops
this service, and with it, tracking. If "minimize" in the field report
actually means "swipe away," this is expected behavior for the current
plugin configuration, and no in-app fix exists for it — the tracker would
need to be re-architected onto a self-restarting foreground service the app
owns directly (outside `geolocator`'s default behavior) to survive that.

### 4.2 OEM background-kill behavior

`android/app/src/main/AndroidManifest.xml` and the Dart code request the
right permissions (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`,
`ACCESS_BACKGROUND_LOCATION`, `WAKE_LOCK`) but the app never requests
exemption from battery optimization
(`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` / `isIgnoringBatteryOptimizations`
is not referenced anywhere in the codebase). On aggressive-battery-management
OEM skins (Xiaomi/MIUI, Oppo/ColorOS, Vivo/FuntouchOS, OnePlus/OxygenOS,
Samsung's "Put unused apps to sleep"), a plain foreground service is often
killed within minutes of the app leaving the screen regardless of the
`FOREGROUND_SERVICE_LOCATION` type, unless the user has separately
whitelisted the app (auto-start permission, "no restrictions" battery mode).
This is outside what any manifest or Dart code can force — it requires either
user education (a one-time in-app prompt linking to the OEM's specific
settings screen) or accepting the data gap.

### 4.3 Doze mode / App Standby (network-only impact)

Even with a healthy foreground service, deep Doze (screen off, stationary,
unplugged) restricts network access to periodic maintenance windows. Location
fixes and local queuing are unaffected — location Timer.periodic still runs
because the process stays foreground-important — but `flush()` uploads can be
delayed until the next maintenance window. This matches the intent already
documented in `docs/staff-live-location-redesign-checklist.md`'s "Operational
limits" section and is expected, queued-and-retried behavior, not data loss.

---

## 5. Summary of root causes, ranked

| # | Cause | Where | Fixable in-app? |
|---|-------|-------|------------------|
| 1 | Staff device only has "While using the app" permission → no foreground service → OS withholds fixes once backgrounded | `location_tracking_service.dart` `_settings()`, `start()` | Partially — the app can detect this and *tell* the user to go grant "Allow all the time" in Settings; it cannot obtain the grant itself on Android 11+ |
| 2 | Gate never routes foreground-only users to Settings to upgrade | `location_gate_screen.dart`, `LocationPermissionState.needsSettings` | Yes — code change |
| 3 | Task swipe-away stops the foreground service (`stopWithTask` defaults true) | `geolocator_android` plugin manifest (not app-owned) | Only by replacing the tracking mechanism (custom sticky foreground service / periodic re-launch), not a config tweak |
| 4 | OEM battery managers kill the foreground service anyway | Device/OEM settings, not app code | Only via user-facing guidance + optional deep link to OEM whitelist screen |
| 5 | Doze defers uploads, not fixes | Android platform | No action needed — already handled by the local queue |

Cause #1/#2 together explain the reported symptom for the overwhelming
majority of devices, since they require no OEM-specific behavior and apply to
stock Android 11+ as documented by Google. #3 and #4 should be checked next if
the fix for #1/#2 doesn't fully resolve field reports.

---

## 6. What to verify before changing code

1. On an affected staff device: Settings → Apps → Ogera CRM → Permissions →
   Location — confirm whether it currently shows "Allowed only while in use"
   or "Allowed all the time."
2. While the app is minimized (not swiped away) with "Allow all the time"
   granted, confirm whether the "Sharing your location…" notification is
   present. Its absence means the foreground service never started for a
   reason other than permission (e.g. `requestPermission()` returned before
   `start()` was reached, or `start()` was never called for that session).
3. Check the device's battery settings for this app (unrestricted / optimized
   / restricted) to separate cause #1 from cause #4.
4. Use the app's own debug tick log (`[Ogera Tracking] ...`, emitted every 10s
   by `LocationTrackingService.debugTicks`) via `flutter logs` or `adb logcat`
   while backgrounding the app, to see the exact moment `isTracking` flips or
   fixes stop updating.
