# Ogera CRM Mobile — Build Status

**App:** `ogera_crm_mobile` (Flutter 3.41.9 · Dart 3.11.5)
**Date:** 2026-09-10
**Specification:** [`OGERA_CRM_MOBILE_PRD.md`](./OGERA_CRM_MOBILE_PRD.md)

**Code:** 63 Dart files, 19,066 lines in `lib/` · 3 test files, 372 lines in `test/`

> **Build status:** ✅ **The app builds.** `flutter build apk --debug` succeeds, `flutter analyze` reports **No issues found**, and all **11 tests pass**. Every screen in the PRD is implemented. What remains is OneSignal push (§9).

---

## 1. What is finished

| Layer | State |
| --- | --- |
| Foundation — theme, network, shared widgets, form kit | ✅ Complete |
| Domain models — contact, professional, lead, sale, staff location, session | ✅ Complete |
| Services — auth, CRM records, geocoding, location queue, tracking, location API | ✅ Complete |
| View models — session, login, contacts, professionals, follow-ups, sales, map, staff route | ✅ Complete |
| Authentication + tabbed login + location gate + shell | ✅ Complete |
| Contacts module | ✅ Complete |
| Professionals module | ✅ Complete |
| Follow-ups module | ✅ Complete |
| Maps — three layers, markers, staff sheet, route trace | ✅ Complete |
| Sales Ledger | ✅ Complete |
| Home dashboards | ✅ Complete |
| More / Profile / Staff directory / My Route | ✅ Complete |
| Android/iOS permission manifests | ✅ Complete |
| Notifications (OneSignal) | ❌ Not started |

---

## 2. Foundation layer

### `lib/core/config/app_config.dart` (24 lines)
Build-time configuration. `API_BASE_URL` comes from `--dart-define`. Without it, release builds use the public `https://ogera-crm.vercel.app` deployment and debug builds use the local dev server (`_debugUrl` in `app_config.dart`). Local emulator/device builds can override it with `--dart-define=API_BASE_URL=...`. Also holds the OSM tile URL, the Nominatim base URL and User-Agent, and the 20-second live-refresh interval.

### `lib/theme/ogera_colors.dart` (56 lines)
The identity palette carried over from web — `ink #0B2942`, `blue #126BB0`, `canvas #F1F5F7`, `line #D6E0E6`, `muted #667A8C` — plus semantic colours (`success`, `warning`, `danger`, `info`), soft variants, two shadow presets, and `OgeraSpacing` (screen padding 16, gap 12, card radius 16, chip radius 8, field radius 12, **touch target 44**).

### `lib/theme/app_theme.dart` (199 lines)
One Material 3 theme for the whole app. Every radius, border, input state, nav-bar state, sheet, dialog, chip, snackbar, and text style is defined once here, so no screen re-styles a primitive.

### `lib/core/network/api_client.dart` (189 lines)
The single HTTP layer.
- Owns the bearer token; injects `Authorization` and `x-client-type: mobile` on every call.
- Unwraps the `{ success, data }` / `{ success:false, error:{code,message} }` envelope into a value or an `ApiException` carrying the server's own message.
- **Reports a 401 once through `onUnauthorized`**, which is how a revoked session drops the user back to login from anywhere in the app.
- 20-second timeout; network failures become a readable message, not a stack trace.

### `lib/core/utils/`
- **`formatters.dart` (116 lines)** — ISO date handling (`YYYY-MM-DD`, never a `DateTime` across the wire, so nothing drifts a day in IST), relative time ("6m ago"), `₹` currency with compact form, distance, duration, avatar monograms, slug humanising, phone normalisation for dial/WhatsApp, and JSON coercion helpers.
- **`launchers.dart` (76 lines)** — call, WhatsApp, and directions, with one shared failure path ("No dialler is available on this device").
- **`staff_palette.dart` (37 lines)** — the fixed 12-colour staff palette and `palette[userId % 12]`, so a staff member's colour is identical on every device and survives reinstalls.

### `lib/core/widgets/`
- **`ogera_widgets.dart` (546 lines)** — `OgeraCard` (with optional identity accent stripe), `StatusChip` (6 tones + custom colour, always label-bearing so colour is never the only signal), `OgeraAvatar`, `QuickActionButton` (44 px), `SectionHeader`, `DetailRow` (hides itself when empty), `OgeraSearchField`, `FilterChipBar` with counts, `confirmAction()` destructive sheet, `showToast()`.
- **`state_views.dart` (209 lines)** — the three mandatory list states: `LoadingListView` (pulsing skeletons, not spinners), `EmptyStateView` (icon + message + one action), `ErrorStateView` (message + Retry), and `RefreshableMessage` so empty/error states still pull-to-refresh.
- **`form_fields.dart` (420 lines)** — `OgeraTextField`, `OgeraPickerField`, `OgeraSegmentedField`, `OgeraDateField`, and `showOptionPicker()` — a searchable bottom sheet used for long lists like the 94 panchayaths, which are unusable as a dropdown on a phone.

### `lib/core/reference/crm_options.dart` (98 lines)
Option lists mirrored from the web app so a phone-entered record filters identically to a web-entered one: contact sources, house stages + construction phases (including the `"Under Construction - Structure"` composition rule), the three awareness levels, water/tank suggestions, 14 districts, and all 94 Malappuram panchayaths.

---

## 3. Domain models

| File | Lines | Contents |
| --- | --- | --- |
| `models/auth_session.dart` | 102 | `UserRole` (admin / sales_head / sales_staff with `isHead`), `LoginScope` (head / staff with `accepts()` and its mismatch message), `AuthUser`, `AuthSession` + JSON |
| `models/contact.dart` | 374 | `ContactType`, full `Contact` (every column the web app writes), `ContactDraft` (omits nulls so an edit never blanks an untouched column), `ContactPage`, `ContactPin` for the map, and **`isEditableBy()`** — the ownership rule |
| `models/professional.dart` | 153 | `ProfessionalType` — all **five** professions with per-type icon and colour — `Professional`, `ProfessionalDraft`, ownership rule |
| `models/followup.dart` | 214 | `Lead` with the **five-field qualification rule** and `missingQualification`, `DueBucket` (overdue/today/upcoming/none), `Stage` with deterministic colour, `Remark`, `StaffMember` |
| `models/sale.dart` | 287 | `SaleOptions` (the three ENUM lists exactly as the `sales` table holds them), `Sale`, `SaleDraft` with derived total, `SalePage`, `ProductOption` |
| `models/staff_location.dart` | 364 | `StaffState` with the 5-minute / 60-minute thresholds, `StaffLocation`, `RoutePoint`, `RouteStop`, `StaffRoute` (**derives distance, stop clustering and bounds on-device** when the server sends only points), `PendingPoint` with its SQLite row mapping |

---

## 4. Services

| File | Lines | What it does |
| --- | --- | --- |
| `services/auth_service.dart` | 125 | `SessionStore` interface + `SecureSessionStore` (keystore only, never SharedPreferences), `AuthService.signIn()` sending `x-client-scope`, **verifying the returned role matches the chosen tab** even against a backend that has not shipped the guard, plus `restore()` and `signOut()` |
| `services/crm_services.dart` | 252 | `ContactsService`, `ProfessionalsService` (fans out across five types for the "All" filter and merges), `FollowupsService` (partial-update semantics so an unrelated field is never blanked), `SalesService`, `StaffDirectoryService` |
| `services/geocoding_service.dart` | 110 | Nominatim reverse geocoding with a **serial one-request-per-second queue**, a coordinate-keyed cache at 5 decimals, in-flight de-duplication, and address shortening so a route timeline reads as "Road, Town, District" rather than a four-line `display_name` |
| `services/location_queue.dart` | 94 | SQLite buffer for unsent points; capped at 2,000 with oldest-first eviction; rows are deleted **only after the server accepts them** |
| `services/location_api_service.dart` | 51 | The five staff-location endpoints: batch upload, live, history, my-route, state |
| `services/location_tracking_service.dart` | 332 | **The uploader.** Permission check/request (foreground then background upgrade), Android foreground-service notification, iOS background settings, the movement rules below, connectivity-triggered flush, and a hard stop on logout |

### Tracking cadence, as implemented
- **Moving:** a point every **100 m** of displacement or every **60 s**.
- **Stationary:** once the device stays inside a **50 m** circle for **5 minutes**, reporting drops to every **5 minutes**.
- The position stream uses a 50 m `distanceFilter` — half the recording threshold — so a 100 m move is never missed between two stream events; a 30-second timer covers the stationary case.
- Points with `accuracy > 100 m` are uploaded but flagged `lowAccuracy`, so the head map can discount them instead of drawing a false detour.
- Offline points queue and flush in batches of 100 on reconnect; the server de-duplicates on `(userId, recordedAt)`, so a half-failed flush cannot create phantom detours.

---

## 5. View models

| File | Lines | Responsibility |
| --- | --- | --- |
| `view_models/session_view_model.dart` | 153 | The app's single source of truth: `SessionStatus` (restoring / signedOut / needsLocation / ready), session adoption, **the staff location gate**, permission re-check on app resume, 401 handling, and sign-out that stops tracking and reports `signed_out` |
| `view_models/login_view_model.dart` | 117 | Tab selection, field validation, submit, and the scope-mismatch message |
| `view_models/contacts_view_model.dart` | 321 | Paged list with **debounced search and sequence-numbered fetches** (a slow response for an abandoned query is discarded), type tabs, filters, optimistic upsert/remove; plus `ContactFormViewModel` with the mutually-exclusive referral logic and the campaign rule |
| `view_models/professionals_view_model.dart` | 180 | Type filter (including "All"), search, sort, upsert/remove; plus `ProfessionalFormViewModel` with the duplicate-phone message |
| `view_models/followups_view_model.dart` | 250 | One model, two shapes. **Scopes leads to the signed-in staff member** even if the API has not shipped scoping; groups by due bucket; enforces the qualification rule *before* the network call so the user sees which fields are missing |
| `view_models/sales_view_model.dart` | 256 | Paged ledger with filters and summary totals; plus `SaleFormViewModel` with the read-only product selector and derived total |
| `view_models/map_view_model.dart` | 365 | Layer switching, per-layer filters, **20-second live polling that pauses when the map is not foregrounded**, lazy per-row address resolution; plus `StaffRouteViewModel` — day selection, 30-second current-position refresh, and stop-address resolution behind the geocoder's rate limit |

---

## 6. Screens delivered

### 6.1 Splash — `views/splash_screen.dart` (74 lines)
Navy ground, Ogera mark, quiet spinner. On screen only while the stored session is restored.

### 6.2 Login — `views/login_screen.dart` (476 lines) ✅
**The tabbed sign-in the brief asked for.**
- Segmented **Head | Staff** control. Head = Admin · Sales Head; Staff = Sales Staff.
- The hero changes with the tab — **navy `#0B2942` for Head, Ogera blue `#126BB0` for Staff** — with animated gradient and copy ("Team oversight" vs "Field workspace"), so the two experiences are never confused at a glance.
- The tab travels as `x-client-scope`; the app also verifies the returned role and shows a specific message ("This is a Sales Staff account. Use the Staff tab to sign in.").
- Email + password with reveal toggle, autofill hints, inline validation, "Forgot password?" help text, and a message region that carries both errors and the session-expiry notice.
- The sign-in button names the experience: **"Sign in as Head" / "Sign in as Staff"**.

### 6.3 Location gate — `views/location_gate_screen.dart` (301 lines) ✅
**The mobile-only requirement: without permission, the staff app does not operate.**
- Full-screen, `PopScope(canPop: false)` — no tab, no back gesture, no "not now".
- Animated triple-ring beacon (says "sharing", not "loading").
- Plain-language reason, plus three assurances: only while signed in · visible to Admin and Sales Head · reports less often when you stop moving.
- **Enable Location** requests foreground then background.
- Distinct copy for each failure: services switched off, permanently denied, or simply denied.
- Recovery actions: **Try again**, **Open settings** (routes to location settings vs app settings correctly), and **Sign out**.
- Re-checked on every app resume — revoking permission mid-session puts the gate straight back up and reports `location_disabled` to the server.
- Admin and Sales Head never see this screen.

### 6.4 Shell — `views/shell_screen.dart` (332 lines) ✅
- Bottom navigation in the requested order: **Home · Contacts · Pros · Follow-ups · Map · More**, as an `IndexedStack` so each tab keeps its scroll position and filters.
- Module view models are provided at shell level, so moving between tabs never refetches.
- **Expandable quick-action FAB** — Add Contact and Add Professional for everyone, **plus Add Sale for Head only**, with staggered reveal animation and labelled pills.
- The Sales view model is **not even constructed** for a staff session.

### 6.5 Root router — `views/root_router.dart` (40 lines) ✅
The single place that decides which experience is on screen, as one switch over `SessionStatus`, with a cross-fade between them.

---

### 6.6 Contacts module ✅ (1,956 lines across 5 files)

| Screen | File | Lines |
| --- | --- | --- |
| List | `views/contacts/contacts_tab.dart` | 395 |
| Detail | `views/contacts/contact_detail_screen.dart` | 514 |
| Create / Edit | `views/contacts/contact_form_screen.dart` | 592 |
| Filters sheet | `views/contacts/contact_filters_sheet.dart` | 162 |
| Referral picker | `views/contacts/referral_picker_sheet.dart` | 293 |

**List** — search across name and phone (digit-normalised), **Leads | Awareness** chips with live counts, filter button with an unread-style badge, infinite scroll at 20/page loading a screen early, pull-to-refresh, and a footer that states the total. Each card carries avatar, name, phone, type chip, location line, relative age, campaign chip, referral summary, and **call / WhatsApp / directions** without opening the record. Directions is disabled — visibly — when the record has no location.

**Detail** — header with 56 px avatar, type and stage chips, and three large actions. A **live OSM map preview** with a Directions button when coordinates exist. Four sections: Location, Site details, Origin, Remarks — each hides itself when all its rows are empty. **Edit and delete are absent, not greyed, when a staff member is looking at someone else's record**, replaced by a "View only" chip.

**Form** — every field the web form writes, grouped as a field user fills them: type segment → Who (name, phone, source) → Where (**GPS capture + map picker**, address, district, panchayath, ward) → Site details (house stage with construction phase, current tank, water source, tank size, awareness level for awareness contacts) → Referral → Campaign (Head only) → Remarks. Sticky save bar. A resolved address only fills an *empty* address field; it never overwrites typing.

**Referral picker** — all three paths in one sheet with source chips: **existing sale, existing contact, existing professional**, each debounced and searchable. Picking a professional saves the reference **and** the name/type/phone snapshot. Sales search is hidden for staff. The three paths are mutually exclusive — choosing one clears the other two.

---

### 6.7 Professionals module ✅ (1,001 lines across 3 files)

| Screen | File | Lines |
| --- | --- | --- |
| List | `views/professionals/professionals_tab.dart` | 276 |
| Detail | `views/professionals/professional_detail_screen.dart` | 451 |
| Create / Edit | `views/professionals/professional_form_screen.dart` | 274 |

**List** — "All" plus the five profession chips with counts, search across name/phone/place, sort menu (newest / A–Z), and cards with a per-trade colour stripe, trade icon, type chip, location line, and the three quick actions.

**Detail** — trade-coloured header, details section, map preview pinned with the trade icon, and a **"Contacts referred"** section that joins on the referral phone snapshot and links straight into each contact.

**Form** — the five professions as a tappable coloured grid (faster than a dropdown and the whole set is visible), name, phone, **GPS capture + map picker**, place, address, district, panchayath. Duplicate phone + trade produces a specific message.

---

### 6.8 Follow-ups module ✅ (1,555 lines across 3 files)

| Screen | File | Lines |
| --- | --- | --- |
| Board / task list | `views/followups/followups_tab.dart` | 533 |
| Lead detail | `views/followups/lead_detail_screen.dart` | 812 |
| Manage stages | `views/followups/manage_stages_sheet.dart` | 210 |

**Head board** — a horizontal **stage rail** with per-stage counts that doubles as the page indicator, driving a swipeable `PageView` of stage columns. Search across name/phone/panchayath, and a **filter-by-staff** sheet. Stages come from `pipeline_stages`; nothing is hardcoded.

**Staff task list** — the same data as a single list grouped **Overdue · Due today · Upcoming · No due date**, each group headed with its own colour and count. This is the only follow-up view a staff session gets.

**Lead card** — name, phone, due-date chip that turns red when overdue, stage chip, panchayath, a "N details missing" warning chip when unqualified, assignee line, and call / WhatsApp.

**Lead detail** —
- Header with the three actions.
- **Three pipeline controls** — Stage, Assigned to, Due date — each one tap from the top. Assignment shows a **lock icon and "Your Sales Head manages assignment"** for a staff session rather than failing on tap.
- **The qualification rule** is enforced before the request: attempting to leave the first stage opens a sheet naming exactly which of the five fields are missing, with a button through to the contact record.
- Lead details section.
- **Immutable history timeline** — notes and system events on one rail, newest first, system rows italic with a distinct icon, every row stamped with author and time.
- **Append-only note composer** docked at the bottom like a chat input, because that is the semantics.

**Manage stages** — add, rename, and **drag-to-reorder**, writing a new `orderIndex` for each shifted stage.

---

### 6.9 Maps ✅ — 4 files, 1,988 lines

**Written and complete:**
- Full-bleed `flutter_map` on OSM tiles — the same basemap as the web app's Leaflet, so no map API key is needed anywhere.
- **Floating layer switcher** that shows **Contacts / Professionals / Staff** for Head and **Contacts / Professionals** only for staff — the staff layer is absent from the switcher, not disabled.
- Per-layer filter rows: contact type; profession type; and for staff, a **Live only** toggle plus a live count that doubles as refresh.
- Fit-to-bounds button, per-marker focus, loading bar, error card with retry, and a legend that counts the pins on screen.
- Lifecycle-aware: **live polling pauses when the map is backgrounded**.
- Contact and professional marker taps focus the map and open a card with call / WhatsApp / directions / open-record.

**Staff layer** — the draggable staff sheet (§9), four visually distinct states, and tap-to-trace opening the route sheet with the day's polyline, numbered stop pins, and an address timeline.

---

### 6.10 Shared location capture ✅

| File | Lines | What it is |
| --- | --- | --- |
| `views/shared/location_capture_field.dart` | 198 | The GPS field used by both forms: **Use my location** and **Pick on map**, showing captured state, coordinates, and a clear button. The coordinate is saved immediately and the address catches up when Nominatim answers, so a poor connection never blocks the capture. |
| `views/shared/location_picker_screen.dart` | 279 | Drop-a-pin map picker. The pin stays fixed at the viewport centre and the map moves under it — steadier one-handed than dragging a marker. Geocodes **on map settle, not during the drag**, and shows the resolved address with coordinates in a bottom sheet. |

---

## 7. Tests (372 lines, 3 files · all passing)

| File | Covers |
| --- | --- |
| `test/auth_service_test.dart` | Login posts `x-client-type: mobile` + `x-client-scope`, stores the session and arms the token; **a Sales Head signing in on the Staff tab is refused with `SCOPE_MISMATCH` and no session is stored**; API credential errors surface verbatim; restore rehydrates and sign-out clears both store and token |
| `test/login_view_model_test.dart` | Incomplete credentials never reach the service; failures produce a recoverable message; the selected tab is sent as the scope; switching tabs clears a stale error |
| `test/widget_test.dart` | The login screen renders both tabs; choosing Staff re-labels the action and swaps the hero copy; an empty form never reaches the service |

---

## 8. Dependencies added

`flutter_map ^8.3.2` · `latlong2 ^0.10.1` · `geolocator ^14.0.2` · `permission_handler ^13.0.2` · `sqflite ^2.4.2+1` · `path ^1.9.1` · `connectivity_plus ^7.3.1` · `url_launcher ^6.3.2` · `intl ^0.20.3`
(joining the existing `flutter_secure_storage`, `http`, `provider`)

---

## 9. Final build — the last six files

All six were written, and the app now compiles.

| File | Lines | What it delivers |
| --- | --- | --- |
| `views/map/map_markers.dart` | 380 | `ContactMarker` (filled teardrop for a lead, hollow for awareness — **shape, not just colour**), `ProfessionalMarker` in the trade colour, **`StaffMarker`** with all four states, and `showMapCard()` |
| `views/map/staff_sheet.dart` | 312 | The draggable staff list: identity colour stripe, monogram, state chip, last-seen, resolved address, battery, **Trace** action, in-sheet search, and two distinct empty states |
| `views/map/staff_route_sheet.dart` | 700 | Current location refreshed every 30 s with address, accuracy and speed; Today / Yesterday / date selector; the day's polyline in the staff colour with start, end and numbered stop pins; a distance / stops / first-seen / last-seen summary; and the address timeline with dwell times |
| `views/home/home_tab.dart` | 790 | Two dashboards — Head gets metrics, a live staff strip, a proportional pipeline breakdown and recent activity; Staff get a tracking banner, their overdue / due-today / upcoming counts, and their actual task list |
| `views/sales/` (4 files) | 1,270 | `sales_screen.dart` (list, search, summary bar, paging), `sale_detail_screen.dart`, `sale_form_screen.dart` (every column, derived total, read-only catalogue picker), `sale_filters_sheet.dart` |
| `views/more/` (4 files) | 990 | `more_tab.dart`, `profile_screen.dart` (with the live tracking/queue state), `staff_directory_screen.dart`, `my_route_screen.dart` |

### 9.1 One architectural fix made along the way

`views/shell_scope.dart` — **pushed routes were not inheriting the shell's view models.**

The shell provides Contacts, Professionals, Follow-ups, Map and Sales *below* the app's `Navigator`, but a pushed route is built *by* that Navigator, so it is a sibling of the shell rather than a descendant. Every detail and form screen is reached by a push and reads those models to write back into the list it came from — so each of them would have thrown `ProviderNotFoundException` at runtime. `pushShellRoute()` carries the models across explicitly, and all 15 module pushes now go through it.

### 9.2 Platform configuration — done

- **Android:** `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`, `WAKE_LOCK`, `ACCESS_NETWORK_STATE`, plus `<queries>` for `tel:` and `https:` so call/WhatsApp/directions resolve on Android 11+.
- **iOS:** all three `NSLocation*UsageDescription` strings (worded to say who sees the data and when), `UIBackgroundModes: location`, and `LSApplicationQueriesSchemes` for `tel` / `https` / `whatsapp`.

### 9.3 Verification

```
flutter analyze      No issues found!
flutter test         All tests passed!  (11 tests)
flutter build apk    Built build/app/outputs/flutter-apk/app-debug.apk
```

### 9.4 Still not started

OneSignal push and the in-app notification centre. Nothing else in the PRD is outstanding on the mobile side.

### 9.5 Backend prerequisites — **these still block the staff app**

Unchanged, and still true in the web code today:

1. **`guardWebAccess` returns 403 for `sales_staff`** on contacts, professionals, sales and staff; `guardFollowupRequest` blocks staff from follow-ups. A staff member can sign in on mobile today and then get 403 on every screen.
2. **No usable creator column** — `contacts.added_by` is a string and `professionals` has no creator at all, so the ownership rules the app already enforces client-side cannot be enforced server-side until `created_by_user_id` exists on both tables.
3. **`POST /api/professionals` drops location** — the Zod schema accepts address/district/panchayath/latitude/longitude but the INSERT writes only name, phone, type, place, so the professionals map layer would stay empty for anything created from mobile.
4. **The five staff-location endpoints do not exist yet**, nor do `staff_live_locations` / `staff_location_history`. The whole staff-tracking half of the app is dark until they do.
5. `professionals.type` holds only 3 of the 5 professions the app offers.
6. `POST /api/auth/login` does not yet honour `x-client-scope` (the app verifies the role itself in the meantime, so login is correct today either way).

> Also worth noting: there is **no `GET /api/sales/[id]`**. The sale row always comes from the list, and `/api/sales/[id]/details` returns only the referrals, reviews and complaints hanging off it — the mobile service was corrected to match.

---

## 10. Design decisions worth recording

- **Colour is never the only signal.** Every status chip carries its label; every staff marker carries initials as well as its colour.
- **Absent, not disabled.** A staff member never sees an edit or delete control for a record they do not own — the API would refuse it, so the interface does not offer it.
- **Every list has three states.** Loading is a skeleton, not a spinner, so the layout does not jump when data lands.
- **Dates never become `DateTime` on the wire.** Plain `YYYY-MM-DD` throughout, matching the web app, so nothing drifts a day in IST.
- **Partial updates stay partial.** Drafts omit null fields, so editing one field never blanks a column the form did not touch.
- **The geocoder is rate-limited by construction.** One serial queue at one request per second with a coordinate-keyed cache — a route with hundreds of points geocodes each distinct place once.
- **Tracking backs off when stationary.** Five-minute reporting during a site visit is what keeps the battery cost bounded; there is no continuous streaming anywhere.
- **Pushed routes carry their scope explicitly.** A route pushed by the app's Navigator is a sibling of the shell, not a child, so `pushShellRoute()` hands the module view models across rather than leaving detail screens to fail at runtime.
