# Ogera CRM Mobile — Product Requirements Document

**Scope:** Flutter mobile application only (`ogera_crm_mobile`).
**Version:** 1.0 (feature-by-feature build)
**Date:** 2026-09-10
**Parent document:** `../../OGERA_CRM_PRD.md` — this document narrows that PRD to mobile and adds the Staff Live Location module.

---

## 1. Purpose

Deliver Ogera CRM as a production Flutter application for three roles — **Admin**, **Sales Head**, and **Sales Staff** — reproducing every module that already exists in the Ogera CRM web app, plus one module that exists only on mobile: **Sales Staff Live Location tracking**.

The app is built feature by feature. Each feature ships against the real shared MySQL database through the CRM Next.js API. **No mock data at any stage.**

### What is new versus web

| Addition | Why |
| --- | --- |
| Tab-based login (**Head** / **Staff**) | Two distinct post-login experiences; the tab tells the user which app they are entering before they type a password |
| Mandatory live-location permission for Sales Staff | Field staff are tracked while on duty; without the permission the staff app is inoperable |
| Staff live map + route history for Admin / Sales Head | Real-time field visibility, one colour per staff, tap-to-trace route with reverse-geocoded addresses |
| Role-split Map tab | Staff see Contacts + Professionals layers; Head additionally sees the Staff layer |

---

## 2. Roles and access

Roles come from the existing auth token (`admin`, `sales_head`, `sales_staff`). All three may sign in on mobile — the login route already allows this when the request carries `x-client-type: mobile`.

### 2.1 Login tabs

| Tab | Accepts roles | Rejects |
| --- | --- | --- |
| **Head** | `admin`, `sales_head` | `sales_staff` → "Use the Staff tab to sign in." |
| **Staff** | `sales_staff` | `admin`, `sales_head` → "Use the Head tab to sign in." |

The tab is a **client-side routing hint plus a server-verified guard**. The app sends the selected tab as `x-client-scope: head | staff`; the API verifies the authenticated role matches the requested scope and returns `403 SCOPE_MISMATCH` when it does not. The app never decides access from the tab alone.

### 2.2 Permission matrix (mobile)

| Module | Admin | Sales Head | Sales Staff |
| --- | --- | --- | --- |
| Home | Team dashboard | Team dashboard | Personal task dashboard |
| Contacts | Full CRUD | Full CRUD | Read all; create/edit/delete **own** records only |
| Professionals | Full CRUD | Full CRUD | Read all; create/edit/delete **own** records only |
| Follow-ups | Create, assign, update all | Create, assign, update all | View and update **assigned** leads only |
| Map — Contacts layer | View | View | View |
| Map — Professionals layer | View | View | View |
| Map — Staff layer | View all staff, live + route history | View all staff, live + route history | **No access** (uploads own location only) |
| Sales Ledger | Full CRUD | Full CRUD | **No access** |
| Notifications | Team events | Team events | Own assignments and records only |
| Profile / Settings | Own | Own | Own (location toggle is locked ON while signed in) |

Ownership rule: every record a Sales Staff creates is stamped with their stable user ID. A Sales Staff can never edit or delete a record created by anyone else, including legacy rows with no creator ID.

---

## 3. Navigation and information architecture

### 3.1 Bottom navigation — fixed order

`Home · Contacts · Professionals · Follow-ups · Map · More`

Six destinations, rendered as a Material 3 `NavigationBar`: 44 px minimum touch targets, selected item in Ogera blue with a filled icon, unselected in muted grey with an outline icon.

Role differences inside the same tabs:

| Tab | Head (Admin / Sales Head) | Staff |
| --- | --- | --- |
| Home | Team pipeline, sales summary, staff-on-duty strip, recent activity | Due-today, overdue, assigned leads, my numbers today |
| Contacts | All contacts, all actions | All contacts, actions gated by ownership |
| Professionals | All professionals, all actions | All professionals, actions gated by ownership |
| Follow-ups | Full board, assign / reassign, manage stages | Assigned leads only, stage + note updates |
| Map | Layer switcher: **Contacts / Professionals / Staff** | Layer switcher: **Contacts / Professionals** |
| More | Sales Ledger, Notifications, Staff Directory, Profile, Settings, Logout | Notifications, Profile, Settings, My Route Today, Logout |

### 3.2 Quick action (FAB)

Centre-docked expandable FAB on Home, Contacts, and Professionals:

- **All roles:** Add Contact, Add Professional
- **Head only:** Add Sale

---

## 4. Modules

### 4.1 Authentication and session

**Screens:** Splash → Login (tabbed) → Permission gate (staff only) → Shell.

Requirements:

1. Splash restores the stored session from `flutter_secure_storage` and routes straight to the shell when the token is still valid.
2. Login screen carries the Ogera logo, a segmented **Head | Staff** tab control, email, password with a reveal toggle, "Remember me", and an inline error region.
3. The two tabs are visually distinct — Head uses the deep navy (`#0B2942`) hero, Staff uses the Ogera blue (`#126BB0`) hero — so a user can tell the two experiences apart at a glance.
4. `POST /api/auth/login` with headers `x-client-type: mobile` and `x-client-scope: head|staff`.
5. The access token is stored in secure storage (never `SharedPreferences`). A refresh token, once the API exposes one, is stored the same way and refreshed before expiry.
6. Inactive users, revoked sessions, and expired tokens are rejected with a clear message and force a return to Login.
7. Logout clears secure storage, stops location tracking, cancels the upload queue, and returns to Login.
8. Any 401 from any endpoint routes the user back to Login with "Your session ended. Please sign in again."

**Profile screen:** name, role badge, email, phone, avatar placeholder, notification preferences, location-sharing state (read-only "Required" for staff), app version, logout.

---

### 4.2 Staff live location (mobile-only module)

This is the module that does not exist on web. It has two halves: the **staff uploader** and the **head monitor**.

#### 4.2.1 Permission gate — Sales Staff

Immediately after a successful Staff login, and again on every cold start of the staff app, the app presents a **full-screen location gate** before the shell is reachable.

- It explains in plain language why tracking is required: "Ogera CRM shares your location with your Sales Head while you are signed in, so field visits and routes can be verified."
- Primary button **Enable Location** requests `whileInUse`, then requests `always` (background) on Android 10+ and iOS.
- The staff app is **not operable without permission**. If permission is denied or the device location service is off, the gate stays up with **Retry** and **Open Settings** actions plus a **Sign out** escape. No CRM tab is reachable.
- If permission is revoked while the app is running, the app returns to the gate and the server-side state becomes `location_disabled`.
- Admin and Sales Head never see this gate.

#### 4.2.2 Upload behaviour (Sales Staff device)

| Condition | Reporting interval |
| --- | --- |
| Moving | Every **100 m** of displacement or every **60 s**, whichever comes first |
| Stationary (< 50 m drift for 5 min) | Every **5 minutes** |
| App backgrounded, permission `always` | Same rules, via foreground service (Android) / background location (iOS) |
| No connectivity | Points queue locally and flush in one batch when connectivity returns |
| Logged out / session revoked / account inactive | Tracking stops immediately and the queue is cleared |

- Desired accuracy: `LocationAccuracy.high`. Points with `accuracy > 100 m` are stored but flagged `low_accuracy: true`.
- The local queue is a SQLite table capped at 2000 points; oldest points drop first.
- Android shows a persistent foreground-service notification: "Ogera CRM — sharing your location with your Sales Head."
- Battery cost is bounded by the stationary back-off; the app never uses continuous 1 s streaming.

#### 4.2.3 Head monitor — Staff map

Available only to `admin` and `sales_head`.

**Layout:** full-bleed map with a draggable bottom sheet listing staff.

- **Staff list sheet** — each row: colour dot, avatar initials, name, state chip, last-seen relative time, current address (reverse-geocoded, cached), and a "Trace" action.
- **Colour identity** — every staff member gets a **persistent, distinct colour** derived deterministically from their user ID against a fixed 12-colour palette (§7.3). The same colour is used for the marker, the route polyline, the list dot, and the detail header. It never changes between sessions or devices.
- **States and visuals:**

| State | Rule | Marker |
| --- | --- | --- |
| **Live** | Last point < 5 min old | Solid colour marker with a breathing pulse ring |
| **Last seen** | 5 min – 60 min old | Solid marker at 70 % opacity, no pulse |
| **Offline** | > 60 min old, or signed out | Hollow ring marker at 45 % opacity, grey outline |
| **Location disabled** | Permission revoked or device service off | Grey marker with a slashed-location badge |

- **Tapping a staff marker or row** opens the **Staff Route sheet**:
  - Header: colour bar, name, phone (call / WhatsApp), state chip, live pulse.
  - **Current location** with its reverse-geocoded address, coordinates, accuracy, and timestamp — refreshed each time the sheet opens and every 30 s while it stays open.
  - **Route for the selected day** drawn as a coloured polyline, with a start pin, an end pin, and stop markers wherever the staff stayed longer than 10 minutes.
  - **Timeline list** below the map: each route point group shows time, address, and dwell duration. Addresses resolve on demand and are cached so the same coordinate is never geocoded twice.
  - Day selector: Today / Yesterday / date picker. Summary bar: distance travelled, points recorded, first seen, last seen, stops.
- **Map controls:** layer switcher (Contacts · Professionals · Staff), "Live only" filter toggle, staff search, follow-mode that keeps the selected staff centred, and a "Fit all staff" button.
- The staff layer polls `/api/staff/locations/live` every **20 seconds** while the map is foregrounded, and pauses when it is not.

#### 4.2.4 Staff's own view

Sales Staff never see the staff layer. Under **More → My Route Today** they can see their own route and today's distance — transparency, not monitoring, and read-only.

---

### 4.3 Contacts

Reproduces the web Contacts module exactly.

**List:** search (name / phone with digit-normalised matching), type tabs **Leads | Awareness** with counts, source filter, date-range filter, infinite scroll paging (10 per page), pull-to-refresh, and per-row quick actions — call, WhatsApp, directions.

**Detail:** all stored fields, referral chain, campaign flags, created-by and timestamps, remarks history, map preview, and the same call / WhatsApp / directions / edit / delete actions.

**Create / Edit form** — all existing fields preserved:

- Name, phone (with country code), source
- Address, district, panchayath (from `lib/panchayaths`), ward
- House stage, current tank, water source, tank size interest
- Contact type: `lead` | `awareness`
- Awareness level, remarks
- Latitude / longitude via **Use my location** (GPS + Nominatim reverse geocoding, same as web) or a map picker
- Referral path — exactly one of: **existing sale**, **existing contact**, or **existing professional**. Choosing a professional saves the reference *and* a snapshot of name / type / phone.
- Campaign target flag and campaign staff selection

**Ownership:** Sales Staff see every contact, but edit and delete are hidden (not merely disabled) on records they did not create. The server enforces the same rule.

---

### 4.4 Professionals

**Types:** Contractor, Engineer, Plumber, Interior Designer, Electrician.

> The current web API accepts only Engineer / Plumber / Contractor. Extending the enum is a prerequisite migration — see §6.

**List:** type filter chips, search across name / phone / place, alphabetical or newest sort, per-row call / WhatsApp / directions.

**Detail:** name, phone, type, place, address, district, panchayath, coordinates, creator, timestamps, map preview, and a "Contacts referred by this professional" section.

**Create / Edit:** name, phone, type, place, address, district, panchayath, and location capture (GPS or map picker). A duplicate phone + type returns a clear "already exists" message.

**Ownership:** same rule as Contacts.

---

### 4.5 Follow-ups

**Pipeline:** stages come from the `pipeline_stages` table — the app never hardcodes them. Default order: `New Lead → Initial Contact → Contacted → Not Interested → Follow-up → Closed/Won → Lost`.

**Head view:** horizontally swipeable stage columns (one stage per page on mobile, with a stage strip at the top showing counts); lead cards with name, phone, panchayath, assignee avatar, and a due-date chip that turns red when overdue. Actions: move stage, assign / reassign staff, set due date, add note, open contact, manage stages.

**Staff view:** a single list of leads assigned to them, grouped **Overdue · Due today · Upcoming · No date**. They can change stage, add notes, and set a due date on their own leads. They cannot reassign.

**Qualification rule:** a lead cannot leave the first stage until panchayath, ward, water source, house stage, and tank size interest are filled. The app names exactly which fields are missing and offers an inline "Complete details" sheet.

**Lead detail:** contact summary, current stage, assignee, due date, and an **immutable history timeline** merging notes and system events (creation, assignment, reassignment, stage change with before/after, due-date change), newest first, each with author and timestamp. Notes are append-only — a note is never edited or replaced.

---

### 4.6 Maps

Built on `flutter_map` with OpenStreetMap tiles, matching the web app's Leaflet + OSM stack so both surfaces render the same basemap and neither needs a map API key.

| Layer | Head | Staff |
| --- | --- | --- |
| Contacts | ✅ | ✅ |
| Professionals | ✅ | ✅ |
| Staff live + routes | ✅ | ❌ |

**Contacts layer:** markers coloured by contact type (lead vs awareness) and stage; filters for type, stage, and date range; marker clustering above ~50 markers; tap a marker for a compact card with name, phone, address, stage, and call / WhatsApp / directions / open-detail actions.

**Professionals layer:** markers coloured by profession type with a legend; type filter chips; the same compact card actions.

**Staff layer:** as specified in §4.2.3.

Shared behaviour: current-location button, fit-to-bounds, search, a floating segmented layer switcher, and a legend sheet.

---

### 4.7 Sales Ledger (Head only)

Hidden entirely from the Staff experience — not greyed out, absent.

**List:** search across buyer name / phone / panchayath; filters for panchayath, ward, water source, source of sale, and date range; a summary bar with total revenue, total tanks, and active panchayaths; paging at 10 per page.

**Detail:** all sale fields, linked contact navigation, referral details, remarks, edit and delete.

**Create / Edit:** sale date, buyer name and phone, address, panchayath, ward, tank size, quantity, unit price (total auto-computed), house stage, current tank, water source, source of sale, engineer and plumber referral names and phones, linked contact, and remarks. The product selector is **read-only** and backed by the existing Venting Next catalogue.

---

### 4.8 Notifications

- In-app notification centre under **More**, with an unread badge on the tab.
- Native push through OneSignal, using the same app the web push already uses.
- Events: contact created, professional created, follow-up assigned or reassigned, follow-up stage changed, follow-up note added, sale created or updated.
- Sales Staff receive only events for their assigned follow-ups and their own records; Head receives team-level events.
- Every notification deep-links to the related contact, professional, follow-up, or sale.

---

## 5. API contract

### 5.1 Already available (reuse as-is)

| Endpoint | Use |
| --- | --- |
| `POST /api/auth/login` | Login — send `x-client-type: mobile` |
| `GET/POST /api/contacts`, `GET/PUT/DELETE /api/contacts/[id]` | Contacts |
| `GET /api/contacts?fields=map` | Contacts map layer |
| `GET/POST /api/professionals`, `/api/professionals/[id]` | Professionals |
| `GET/PUT /api/followups`, `/api/followups/stages`, `/api/followups/[id]/remarks` | Follow-ups |
| `GET/POST /api/sales`, `/api/sales/[id]`, `/api/sales/search`, `/api/sales/products` | Sales ledger |
| `GET /api/staff` | Staff picker |

All responses use the `{ success, data }` / `{ success, error: { code, message } }` envelope. All authenticated calls send `Authorization: Bearer <token>`.

### 5.2 Backend work this PRD depends on

These are **blocking prerequisites** — the staff experience cannot ship without them.

1. **Sales-staff access to the existing APIs.** `guardWebAccess` currently returns `403` for `sales_staff` on contacts, professionals, sales, and staff; `guardFollowupRequest` blocks staff from follow-ups. A new `guardMobileAccess(request, module)` is needed that admits `sales_staff` to Contacts, Professionals, and Follow-ups while keeping the Sales Ledger closed to them.
2. **Ownership enforcement.** `PUT` / `DELETE` on `/api/contacts/[id]` and `/api/professionals/[id]` must reject a `sales_staff` caller whose ID does not match the record's creator, with `403 NOT_OWNER`.
3. **Follow-up scoping.** `GET /api/followups` must return only leads assigned to the caller when the caller is `sales_staff`, and `PUT` must reject updates to leads not assigned to them.
4. **Professional create must persist location.** The current `POST /api/professionals` inserts only name, phone, type, and place, silently dropping the address, district, panchayath, latitude, and longitude its own schema accepts. Mobile needs those persisted for the professionals map.
5. **Scope guard.** `POST /api/auth/login` should honour `x-client-scope` and return `403 SCOPE_MISMATCH` when the role does not match the selected tab.

### 5.3 New endpoints for live location

| Method | Path | Roles | Purpose |
| --- | --- | --- | --- |
| `POST` | `/api/staff/locations` | `sales_staff` | Batch-upload queued points: `{ points: [{ latitude, longitude, accuracy, speed, heading, batteryLevel, isMoving, recordedAt }] }`. Idempotent on `(userId, recordedAt)`. |
| `GET` | `/api/staff/locations/live` | `admin`, `sales_head` | Latest point per active staff member: `{ userId, name, phone, latitude, longitude, accuracy, recordedAt, state, colorIndex }`. |
| `GET` | `/api/staff/locations/history?userId=&date=` | `admin`, `sales_head` | Ordered route points for one staff member on one day, plus `{ distanceMeters, firstSeen, lastSeen, stops[] }`. |
| `GET` | `/api/staff/locations/me?date=` | `sales_staff` | The caller's own route, for **My Route Today**. |
| `POST` | `/api/staff/locations/state` | `sales_staff` | Report `tracking_enabled`, `location_disabled`, or `signed_out`. |

Reverse geocoding uses OpenStreetMap Nominatim, exactly as `src/lib/location.ts` does on web, called from the app with an address cache keyed to 5-decimal coordinates. Nominatim requires a real User-Agent and a one-request-per-second limit — the app queues geocoding requests accordingly.

---

## 6. Database changes (additive only)

| Change | Purpose |
| --- | --- |
| `staff_live_locations` — `user_id` PK, latitude, longitude, accuracy, speed, heading, battery_level, is_moving, recorded_at, state, updated_at | One row per staff member; the fast path for the live map |
| `staff_location_history` — id, user_id, latitude, longitude, accuracy, speed, heading, battery_level, recorded_at, created_at, unique `(user_id, recorded_at)` | Route history, retained indefinitely |
| `staff_location_state` columns (or a small table) for `tracking_enabled` / `location_disabled` / `signed_out` | Drives the four map states |
| `contacts.created_by_user_id` (INT, nullable, indexed) | Ownership checks — the existing `added_by` is a string and unsuitable as an authorization key |
| `professionals.created_by_user_id` (INT, nullable, indexed) | Ownership checks |
| `contacts.followup_assigned_user_id` (INT, nullable, indexed) | Stable follow-up assignment; `followup_assigned_to` stays for display compatibility |
| `professionals.type` enum extended with `Interior Designer`, `Electrician` | The five required professions |
| `crm_notifications` | In-app notification centre |
| Indexes: `staff_location_history(user_id, recorded_at)`, `contacts(created_by_user_id)`, `contacts(followup_assigned_user_id)`, `professionals(created_by_user_id)` | Query performance for map, ownership, and assignment |

No destructive migration. Existing users, sessions, contacts, professionals, sales, and history stay intact.

> **Caution:** this database is shared and live with venting-next. Every migration is reviewed and applied deliberately, never as a side effect of a build step.

---

## 7. Design system

### 7.1 Identity

Carries the existing `OgeraColors` forward:

| Token | Value | Use |
| --- | --- | --- |
| `ink` | `#0B2942` | Head hero, headers, primary text |
| `blue` | `#126BB0` | Primary action, Staff hero, selected nav |
| `canvas` | `#F1F5F7` | Screen background |
| `line` | `#D6E0E6` | Dividers, card borders |
| `muted` | `#667A8C` | Secondary text, unselected nav |

Semantic additions: `success #16A34A`, `warning #D97706`, `danger #DC2626`, `info #0284C7`.

### 7.2 Components

Material 3, `useMaterial3: true`. Cards at 16 px radius with a soft shadow; status chips at 8 px radius; 44 px minimum touch target everywhere; 16 px screen padding, 12 px between cards. Every list has explicit **loading** (skeletons, not spinners), **empty** (illustration + one clear action), and **error** (message + Retry) states. Destructive actions confirm in a sheet. Success and failure both produce visible feedback.

### 7.3 Staff colour palette

Twelve colours chosen for distinctness on an OSM basemap and for colour-blind separability. A staff member's colour is `palette[userId % 12]` — stable forever, identical on every device.

```
#E11D48  #2563EB  #16A34A  #EA580C  #9333EA  #0891B2
#CA8A04  #DB2777  #059669  #4F46E5  #B45309  #0D9488
```

Colour is never the only signal: every marker and row also carries initials, and every state also carries a text chip.

### 7.4 Accessibility

Semantic labels on all interactive elements, 4.5:1 minimum text contrast, support for system text scaling to 200 % without clipping, and no information conveyed by colour alone.

---

## 8. Technical decisions

| Concern | Choice |
| --- | --- |
| State management | `provider` (already in the project), one ViewModel per feature |
| Networking | `http` with a shared `ApiClient` that injects the bearer token, unwraps the `{ success, data }` envelope, and routes 401 to logout |
| Secure storage | `flutter_secure_storage` for tokens only |
| Maps | `flutter_map` + OSM tiles + `flutter_map_marker_cluster` |
| Location | `geolocator` for positions and permissions; `flutter_background_geolocation` or a `foreground_service` + `geolocator` stream for background uploads |
| Local queue / cache | `sqflite` — location queue, address cache, last-known lists for offline read |
| Connectivity | `connectivity_plus` to trigger queue flush |
| Push | `onesignal_flutter` |
| Permissions | `permission_handler` for the settings deep-link |
| Config | `--dart-define` for `API_BASE_URL`; the current `http://10.0.2.2:3000` default is emulator-only and must not ship in a release build |

---

## 9. Build order

Each step ends with a working, testable app against the real database.

1. **Foundation** — `ApiClient`, envelope handling, error model, session restore, role router, app shell with the six-tab navigation.
2. **Login tabs** — Head / Staff segmented login, scope guard, secure token storage, logout.
3. **Location gate** — permission flow, denial handling, settings deep-link, staff-app lockout.
4. **Contacts** — list, search, filters, detail, create, edit, delete, ownership gating, call / WhatsApp / directions.
5. **Professionals** — the same surface, plus the extended type enum and location capture.
6. **Follow-ups** — stage board for Head, assigned list for Staff, notes, history timeline, qualification rule.
7. **Maps: Contacts + Professionals layers** — clustering, filters, marker cards.
8. **Location uploader** — background service, movement rules, SQLite queue, connectivity flush, stop-on-logout.
9. **Staff live map** — live layer, colours, states, staff sheet, route trace, address timeline, day selector.
10. **Sales Ledger** — Head-only list, filters, totals, detail, create, edit, delete.
11. **Notifications** — OneSignal registration, in-app centre, deep links.
12. **Home dashboards** — role-specific Home, Profile, Settings, My Route Today.
13. **Hardening** — offline behaviour, error states, accessibility pass, battery profiling, release configuration.

---

## 10. Acceptance criteria

**Authentication**
- A Sales Staff account signing in on the Head tab is refused, and vice versa, with a message naming the correct tab.
- A restored session opens the correct role shell without a second login.
- A revoked or expired token returns the user to Login from any screen.

**Location gate**
- A Sales Staff who denies location permission cannot reach any CRM tab; only Retry, Open Settings, and Sign out are available.
- Revoking permission while the app runs returns the user to the gate within one app lifecycle event.
- Admin and Sales Head never see the gate.

**Tracking**
- Moving staff produce a point at least every 100 m or 60 s; stationary staff produce one every 5 minutes.
- Points recorded with no connectivity appear on the head map after connectivity returns, in the correct chronological order, with no duplicates.
- Logging out stops tracking immediately and the head map moves that staff to Offline.

**Monitoring**
- The head map shows every active staff member with a distinct, persistent colour that is identical across app restarts and devices.
- The four states — Live, Last seen, Offline, Location disabled — render distinctly and match the point ages defined in §4.2.3.
- Tapping a staff member shows their current location with a resolved address, and a route polyline for the selected day with per-stop addresses and dwell times.
- A Sales Staff account has no route to the staff layer or to any staff location endpoint; the API refuses the request even when issued directly.

**Modules**
- Contacts, Professionals, Follow-ups, and Sales read and write real database records with no mock data anywhere.
- A Sales Staff cannot edit or delete a record created by another user — the action is absent in the UI and refused by the API.
- A Sales Staff sees only follow-ups assigned to them.
- The Sales Ledger is unreachable for Sales Staff in both the UI and the API.
- Follow-up notes are append-only, and every stage change, assignment, and due-date change appears in the history timeline with author and timestamp.
- Contact referrals work from a sale, a contact, and a professional, and a professional referral stores the name / type / phone snapshot.

**Experience**
- Every list has distinct loading, empty, and error states.
- No touch target is smaller than 44 px, and the app remains usable at 200 % text scale.
- The venting-next site, product catalogue, and unrelated modules continue working unchanged.

---

## 11. Out of scope

- HRMS authentication adapter and final HRMS role mapping.
- Migrating CRM records to a dedicated CRM database.
- Any location-history retention or deletion policy.
- Product CRUD, storefront, orders, blog, and every other venting-next module.
- Web app changes beyond the API prerequisites listed in §5.2.
