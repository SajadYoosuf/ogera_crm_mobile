# Mobile: Staff-only login, simplified home, removed staff directory

## Why
The mobile app was designed for field staff (sales executive, tele-caller,
field executive, support, team lead). Admin and manager accounts belong on the
web portal. Having a "Head tab" and "Staff tab" on the login screen was
confusing — staff were picking the wrong tab, and admin accounts could sign
in to the phone app by switching to the Head tab.

## What changes
- **`auth_session.dart`** — Removed the `LoginScope` enum (Head / Staff tabs).
  The app now has one rule: if your role is not a staff role, sign-in is
  refused with a clear message to use the web portal.
- **`auth_service.dart`** — `signIn` no longer takes a `scope` parameter.
  The staff-only check is inside the service. A `signInForTest` bypass is
  provided for e2e tests that need to sign in with an admin account.
  Added a `kDebugMode` debug print that logs the email and password being sent
  so developers can see what is happening during local testing.
- **`login_view_model.dart`** — Removed the `scope` parameter from the view
  model; the login form is now a single-field form (mobile or email + password).
- **`login_screen.dart`** — Redesigned. One screen, no tabs.
- **`home_tab.dart`** — Removed the `_HeadHome` dashboard (pipeline + recent
  contacts overview). Everyone now sees `_StaffHome` — "My day" with overdue
  and today's follow-ups.
- **`more_tab.dart`** — Removed the "Staff directory" menu item that was shown
  only to head users.
- **`staff_directory_screen.dart`** — Deleted. This screen listed all employees
  and was only reachable from the More tab head-only section.
- **`app_config.dart`** — `_debugUrl` updated to `http://10.0.2.2:8000` (the
  correct Android Emulator address for the host machine). Also corrected the
  `_productionUrl`.
- **`ogera_colors.dart`** — Added missing colour tokens used by the new login
  screen.
- **iOS / Android** — App icon assets and manifest updated.
- **Tests** — Updated to match new `signIn` signature and `signInForTest`.

## Out of scope
- Web app login (already staff-blocked by the backend).
- Backend changes (the backend already refuses non-staff on mobile; no new
  endpoints added).
- Products or contacts screens.

## Verification
- `flutter analyze` passes with no errors.
- Manual: launch on Android Emulator, sign in as a staff account — lands on
  home. Sign in as admin — sees "use the web portal" error message.
- `flutter test` passes (auth_service_test, login_view_model_test,
  mobile_backend_e2e_test).
