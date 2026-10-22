# House stage options from Settings (mobile)

## Why
The backend now keeps house stages in Settings. The app sent labels such as "Ready", which the backend rejected (422), so house stage could not be saved from the phone.

## What changed
- `lib/services/crm_services.dart`: `SettingsOptionsCatalog` reads `GET /settings/enums/{category}` once per API client and falls back to a default list when offline. `ContactsService.houseStages()` uses it.
- `lib/view_models/contacts_view_model.dart`: `ContactFormViewModel.loadHouseStages()` loads the list when the form opens.
- `lib/views/contacts/contact_form_screen.dart`: the picker offers the Settings list, stores the value and shows the label.
- `lib/core/reference/crm_options.dart`: `defaultHouseStages` and `houseStageLabel` replace the old base/phase helpers.
- Contact and lead detail screens show the label.
- Tests now expect the stored value (`ready`).

## Out of scope
- No tank type field in the app yet.

## Verification
- `flutter test`: 113 passed. `flutter analyze`: no new issues.

Same commit: backend and web (`docs/changes/2026-10-22-house-stage-tank-type-settings.md` in each).
