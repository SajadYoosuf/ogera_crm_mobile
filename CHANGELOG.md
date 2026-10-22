# Changelog

## 2026-10-22 — `5f9f810` (branch `version1`)

**feat(mobile): staff-only login, simplified home, remove staff directory**

Author: sajad yoosuf
Previous commit on this side: `e2f5919` fix(mobile/icons): shrink adaptive icon foreground to center (2026-10-22)

### Summary
The mobile app is now for sales staff only (sales executive, tele-caller,
field executive, team lead, support). Admin and manager accounts are blocked
at sign-in with a clear message to use the web portal instead. The old
"Head tab / Staff tab" split on the login screen is removed — one form
for everyone, role check happens after the API responds. The home screen is
simplified so every role sees "My day" (overdue + today's follow-ups). The
staff directory screen (only visible to head roles) is deleted.
See [docs/changes/2026-10-22-staff-only-login.md](docs/changes/2026-10-22-staff-only-login.md).

### Files
| Status | File | Change |
| --- | --- | --- |
| Modified | `assets/images/ogera-symbol-foreground.png` | Updated app symbol image used in the adaptive icon |
| Added | `docs/changes/2026-10-22-staff-only-login.md` | Change notes for this feature |
| Modified | `ios/Runner.xcodeproj/project.pbxproj` | iOS project file — updated for new icon assets |
| Modified | `ios/Runner/Info.plist` | iOS app metadata — minor settings update |
| Modified | `lib/core/config/app_config.dart` | `_debugUrl` changed to `http://10.0.2.2:8000` — this is the correct address to reach your PC's local server from inside the Android Emulator |
| Modified | `lib/models/auth_session.dart` | Removed `LoginScope` enum — this was the Head/Staff tab concept; no longer needed since the app is staff-only |
| Modified | `lib/services/auth_service.dart` | `signIn` no longer takes a `scope` parameter; the staff-only role check is now inside the service itself; added `signInForTest` for e2e tests; added a `kDebugMode` print that logs email and password during local development |
| Modified | `lib/theme/ogera_colors.dart` | Added colour tokens (`ink`, `line`, `muted`) used by the new login screen |
| Modified | `lib/view_models/login_view_model.dart` | Removed `scope` parameter; the identifier field now accepts a phone number or email address |
| Modified | `lib/views/home/home_tab.dart` | Removed the `_HeadHome` pipeline overview widget — every role now sees `_StaffHome` ("My day") |
| Modified | `lib/views/login_screen.dart` | Redesigned to a single form with no tabs; "Login" button; removed unused `_LangToggle` widget |
| Modified | `lib/views/more/more_tab.dart` | Removed the "Staff directory" menu item that appeared only for head users |
| Deleted | `lib/views/more/staff_directory_screen.dart` | This screen listed all employees who can be assigned work; deleted because it was only for admin/manager who now use the web portal |
| Modified | `test/auth_service_test.dart` | Updated tests to match new `signIn` signature |
| Modified | `test/e2e/mobile_backend_e2e_test.dart` | Updated to use `signInForTest` where admin credentials are needed |
| Modified | `test/login_view_model_test.dart` | Added `signInForTest` to the fake auth service; tests now check the identifier field label |
| Modified | `test/test_helpers.dart` | `FakeAuthService` updated — removed `LoginScope scope` from `signIn`, added `signInForTest` stub |
| Modified | `test/widget_test.dart` | Updated widget tests to match the new single-form login screen; checks for "Mobile number or email" field and "Login" button |

### Notes
- `flutter analyze`: 0 errors, 2 pre-existing warnings (unrelated to this change).
- Only the mobile side changed in this commit.

## 2026-10-22 — `fce4d1f` (branch `phase1-redesign`)

**feat: house stage and tank type lists move to Settings**

Author: sajad yoosuf
Previous commit on this side: `2d48eca` docs: update changelog for the commits from 946afa4 to 9cfef38 (2026-10-18)

### Summary
The contact form loads house stages from Settings (`GET /settings/enums/house_stage`) and sends the stored value; detail screens show the label. Before this, the app sent labels the backend rejected (422). Notes: [docs/changes/2026-10-22-house-stage-tank-type-settings.md](docs/changes/2026-10-22-house-stage-tank-type-settings.md).

### Files
| Status | File | Change |
| --- | --- | --- |
| Modified | `lib/services/crm_services.dart` | `SettingsOptionsCatalog` reads a Settings list once per API client, with an offline fallback; `ContactsService.houseStages()` |
| Modified | `lib/view_models/contacts_view_model.dart` | `ContactFormViewModel.loadHouseStages()` |
| Modified | `lib/views/contacts/contact_form_screen.dart` | Picker offers the Settings list, stores the value, shows the label |
| Modified | `lib/core/reference/crm_options.dart` | `defaultHouseStages` and `houseStageLabel` replace the base/phase helpers |
| Modified | `lib/views/contacts/contact_detail_screen.dart` | Shows the house stage label |
| Modified | `lib/views/followups/lead_detail_screen.dart` | Shows the house stage label |
| Modified | `test/contact_form_screen_test.dart` | Expects the stored value `ready` |
| Modified | `test/contact_form_view_model_test.dart` | Expects the stored value `ready` |
| Added | `docs/changes/2026-10-22-house-stage-tank-type-settings.md` | Change notes |

### Notes
- `flutter test`: 113 passed. `flutter analyze`: no new issues. No tank type field in the app yet.
- The same commit touched backend and web.

## 2026-10-18 — `9cfef38` (branch `phase1-redesign`)

**feat: mobile app follows the rule 9 scope and the current contacts flow**

Author: sajad yoosuf
Previous commit on this side: `946afa4` refactor: remove retired modules and superseded files (rule 9)

### Summary
Brings the mobile app in line with rule 9: no location gate, no map, performance or sales screens; contact form and lead screens updated.

### Files
| Status | File | Lines |
| --- | --- | --- |
| Modified | `android/app/src/main/AndroidManifest.xml` | +1 / -16 |
| Modified | `ios/Runner/Info.plist` | +2 / -12 |
| Modified | `lib/main.dart` | +0 / -23 |
| Modified | `lib/models/auth_session.dart` | +7 / -2 |
| Modified | `lib/models/contact.dart` | +0 / -10 |
| Modified | `lib/services/crm_services.dart` | +1 / -81 |
| Modified | `lib/view_models/contacts_view_model.dart` | +1 / -11 |
| Modified | `lib/view_models/followups_view_model.dart` | +1 / -0 |
| Modified | `lib/view_models/session_view_model.dart` | +4 / -67 |
| Modified | `lib/views/contacts/contact_form_screen.dart` | +1 / -11 |
| Modified | `lib/views/contacts/referral_picker_sheet.dart` | +9 / -51 |
| Modified | `lib/views/home/home_tab.dart` | +1 / -243 |
| Modified | `lib/views/more/profile_screen.dart` | +1 / -252 |
| Modified | `lib/views/root_router.dart` | +2 / -7 |
| Modified | `lib/views/shell_scope.dart` | +2 / -9 |
| Modified | `macos/Flutter/GeneratedPluginRegistrant.swift` | +0 / -4 |
| Modified | `pubspec.lock` | +1 / -105 |
| Modified | `pubspec.yaml` | +0 / -4 |
| Modified | `test/auth_service_test.dart` | +11 / -1 |
| Modified | `test/contact_form_screen_test.dart` | +0 / -14 |
| Modified | `test/crm_services_test.dart` | +1 / -126 |
| Modified | `test/e2e/mobile_backend_e2e_test.dart` | +0 / -198 |
| Modified | `test/home_tab_test.dart` | +2 / -39 |
| Modified | `test/more_tab_test.dart` | +6 / -54 |
| Modified | `test/shell_screen_test.dart` | +20 / -59 |
| Modified | `test/test_helpers.dart` | +0 / -73 |
| Modified | `test/widget_test.dart` | +1 / -9 |
| Modified | `windows/flutter/generated_plugin_registrant.cc` | +0 / -3 |
| Modified | `windows/flutter/generated_plugins.cmake` | +0 / -1 |

### Notes
flutter analyze: 0 errors, 2 issues (one info: use_build_context_synchronously in lib/views/followups/followups_tab.dart:213; one warning: unused parameter in test/professionals_view_model_test.dart:207). Mobile had no CHANGELOG before this commit; this file was created with this entry.

## 2026-10-18 — `946afa4` (branch `phase1-redesign`)

**refactor: remove retired modules and superseded files (rule 9)**

Author: sajad yoosuf
Previous commit on this side: `4f9501f` Connect the mobile app to the FastAPI backend

### Summary
Removes location tracking, the map, the performance screens and the mobile sales screens.

### Files
| Status | File | Lines |
| --- | --- | --- |
| Deleted | `integration_test/performance_flow_test.dart` | +0 / -10 |
| Deleted | `integration_test/staff_location_flow_test.dart` | +0 / -60 |
| Deleted | `lib/models/performance.dart` | +0 / -68 |
| Deleted | `lib/models/sale.dart` | +0 / -263 |
| Deleted | `lib/models/staff_location.dart` | +0 / -363 |
| Deleted | `lib/services/location_api_service.dart` | +0 / -63 |
| Deleted | `lib/services/location_queue.dart` | +0 / -103 |
| Deleted | `lib/services/location_tracking_service.dart` | +0 / -495 |
| Deleted | `lib/view_models/map_view_model.dart` | +0 / -318 |
| Deleted | `lib/view_models/sales_view_model.dart` | +0 / -215 |
| Deleted | `lib/views/location_gate_screen.dart` | +0 / -310 |
| Deleted | `lib/views/map/map_markers.dart` | +0 / -420 |
| Deleted | `lib/views/map/map_tab.dart` | +0 / -598 |
| Deleted | `lib/views/map/staff_route_sheet.dart` | +0 / -823 |
| Deleted | `lib/views/map/staff_sheet.dart` | +0 / -363 |
| Modified | `lib/views/more/more_tab.dart` | +5 / -61 |
| Deleted | `lib/views/more/my_route_screen.dart` | +0 / -471 |
| Deleted | `lib/views/performance/performance_screen.dart` | +0 / -445 |
| Deleted | `lib/views/performance/staff_contacts_screen.dart` | +0 / -227 |
| Deleted | `lib/views/sales/sale_detail_screen.dart` | +0 / -508 |
| Deleted | `lib/views/sales/sale_filters_sheet.dart` | +0 / -135 |
| Deleted | `lib/views/sales/sale_form_screen.dart` | +0 / -526 |
| Deleted | `lib/views/sales/sales_screen.dart` | +0 / -384 |
| Modified | `lib/views/shell_screen.dart` | +4 / -51 |
| Deleted | `test/fakes/fake_geolocator_platform.dart` | +0 / -100 |
| Deleted | `test/fakes/fake_location_api_service.dart` | +0 / -42 |
| Deleted | `test/fakes/fake_location_queue.dart` | +0 / -55 |
| Deleted | `test/fakes/no_op_start_tracking_service.dart` | +0 / -23 |
| Deleted | `test/location_gate_screen_test.dart` | +0 / -226 |
| Deleted | `test/location_queue_test.dart` | +0 / -152 |
| Deleted | `test/location_tracking_service_test.dart` | +0 / -238 |
| Deleted | `test/map_tab_test.dart` | +0 / -103 |
| Deleted | `test/performance_flow_scenarios.dart` | +0 / -261 |
| Deleted | `test/performance_flow_test.dart` | +0 / -6 |
| Deleted | `test/performance_screen_test.dart` | +0 / -328 |
| Deleted | `test/performance_test_support.dart` | +0 / -133 |
| Deleted | `test/performance_unit_test.dart` | +0 / -310 |
| Deleted | `test/profile_screen_test.dart` | +0 / -220 |
| Deleted | `test/staff_contacts_screen_test.dart` | +0 / -325 |
| Deleted | `test/staff_location_contract_test.dart` | +0 / -139 |
| Deleted | `test/staff_location_session_flow_test.dart` | +0 / -149 |
| Deleted | `test/staff_location_widget_test.dart` | +0 / -179 |

### Notes
Mobile sales screens were removed in this commit because they were in the working tree deletions; they are not in rule 9's list. Decide whether to restore them (see `rule.md` section 9).

