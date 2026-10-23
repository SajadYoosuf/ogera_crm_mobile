# Attendance: location at check-in AND check-out, UTC on server, live-location sync

## Context
Attendance currently saves GPS only at check-in (optional), saves times as IST wall-clock
(`ist_now()`), and never touches the live-location table. The real flow is:
check-in = officially start sharing location → live pings stream → check-out = officially stop.
Location permission is part of the job, so it must be required, not optional.

Decisions (confirmed with user):
- Check-in **and** check-out require coordinates. Without permission the app shows a hint
  ("Turn on location…", Open Settings button); the server also rejects missing coords (422).
- Column naming stays `checkin_lat/lng`; add `checkout_lat/lng` (not `latitude/longitude`).
- Server stores **UTC**. Mobile converts to the phone's local time (India) only for display.
- Check-in and check-out also write the employee's row in `staff_locations` (live location),
  bypassing the 30 s throttle so the start and end points are always recorded.
- `date` column stays the **IST calendar day** (business rule, `today_ist()`); the timestamps become UTC.
- The SQL migration file is **saved but not run**. The user runs it later.

## Backend (`ogera_crm_backend`)
1. `business_time.py` – add `utc_now()` (naive UTC, same form `staff_locations.recorded_at` uses). Reuse `today_ist()` for `date`.
2. `models/attendance.py` – add `checkout_lat`, `checkout_lng` (Float, nullable at DB level so old rows stay valid); fix docstring (UTC).
3. `services/location_service.py` (new) – `save_live_location(db, employee_id, lat, lng, now, respect_throttle)`: the upsert now inline in `routes/staff_locations.py`. Extracting it lets attendance reuse it (CLAUDE.md: logic in services).
4. `routes/staff_locations.py` – call the service with `respect_throttle=True` (behaviour unchanged).
5. `routes/attendance.py`
   - `CheckinBody` / new `CheckoutBody`: `latitude`, `longitude` **required**, range-validated (-90..90, -180..180).
   - `checkin`: `checkin_at=utc_now()`, `date=today_ist()`, save lat/lng, `save_live_location(..., respect_throttle=False)`, one commit.
   - `checkout`: takes a body, sets `checkout_at=utc_now()`, `checkout_lat/lng`, updates live location, one commit.
   - `AttendanceResponse` adds `checkout_lat/lng`; `_to_response` marks datetimes as UTC (`tzinfo=utc`) so JSON carries `+00:00`. Without it Flutter's `DateTime.parse` reads them as local time and shows the wrong hour.
   - Update module docstring (rules: coords required, UTC).
6. `scripts/migrate_attendance_checkout_location.sql` (new; the project uses hand-run SQL because `create_all` doesn't alter tables): `ADD COLUMN checkout_lat/lng` and convert existing rows IST→UTC (`checkin_at/checkout_at − 5:30`). Run once only. Saved only, not run. Tests use a fresh test DB, so they don't need it.
7. `tests/test_attendance.py` (new, same style as `test_mobile_api.py`): check-in saves coords + live row; missing/out-of-range coords → 422; second check-in → 409; check-out saves coords and updates live location even inside the 30 s window; check-out without check-in → 404; double check-out → 409; response times are UTC (`+00:00`); unauthenticated → 401/403; one employee never sees another's record.

## Mobile (`ogera_crm_mobile`)
8. `lib/models/attendance.dart` – add `checkoutLat/checkoutLng`; parse times as UTC; display uses `.toLocal()`.
9. `lib/services/device_location_service.dart` (new) – wraps Geolocator (same permission pattern as `location_capture_field.dart`); returns coordinates or throws a typed error (`denied`, `deniedForever`, `serviceOff`).
10. `lib/services/home_service.dart` – `checkin` / `checkout` take required `lat`, `lng`; update header comment.
11. `lib/view_models/home_view_model.dart` – `checkin()` / `checkout()` get the position first; on a permission error set `locationHint` + `canOpenSettings` and make **no** API call. Add tests for these states.
12. Not in this change: the check-in button card and the foreground streaming service. `SPRINT_CHECKLIST.md` marks them ✅, but `lib/views/home/checkin_button.dart` and `lib/services/location_streaming_service.dart` do not exist (only `home_tab.dart`).

## Docs
13. `ogera_crm_backend/README.md` – Attendance + live-location section (fields, UTC rule, endpoints, throttle bypass).
14. `ogera_crm_mobile/API_CONNECTION.md` – `AttendanceRecord` mapping (`checkinAt`, `checkoutAt`, `checkinLat/Lng`, `checkoutLat/Lng`, `isOpen`; `isOpen` = no checkout time → decides which button shows).
15. `rule.md` – new rule (location required at check-in/out, UTC stored / local shown, live location synced) and correct rule 9, which still says staff location tracking was removed.
16. `SPRINT_CHECKLIST.md` – correct the two false ✅ items.

## Verification
- Backend: `pytest` in `ogera_crm_backend` (new `test_attendance.py` + existing suite).
- Mobile: `flutter test`, `flutter analyze`, formatter.
- Manual (after you run the migration): login → `POST /attendance/checkin` with coords → check the `staff_locations` row and `+00:00` times → checkout → verify; repeat without coords (expect 422).
- Review the final diff for unrelated changes. No commit unless asked (then update `CHANGELOG.md` per the repo rule).
