# Connecting the app to the backend

The app talks to the FastAPI backend in `ogera_crm_backend` (see `API.md` at the repo root). It used to target the old Next.js API; the services in `lib/services/crm_services.dart` now translate between the backend's snake_case JSON and the models the screens already use, so the screens and view models are largely unchanged.

## Server address

`lib/core/config/app_config.dart`:

| Build | Address |
| --- | --- |
| `flutter run` (debug) | `http://192.168.29.206:8000` — change it to your PC's address; an Android emulator uses `http://10.0.2.2:8000` |
| release | `https://ogera-crm.onrender.com` |
| any | `--dart-define=API_BASE_URL=https://...` overrides both |

Start a local backend with `uvicorn main:app --host 0.0.0.0 --port 8000` from `ogera_crm_backend`.

## How the app's idea maps onto the API

| In the app | On the server |
| --- | --- |
| Sign in (Head / Staff tab) | `POST /auth/login`. `admin` and `manager` are **Head**; every other role, including custom ones, is **Staff**. The tab is checked on the phone only. |
| Lead / Awareness contacts | `consumer` contacts. Awareness = consumer profile `awareness_mode = 1`. |
| Professionals | `partner` contacts (`profession_type`, `work_area` is the "place"). |
| Source | `lead_source_id`, looked up from `GET /lead-sources` by slug (`meta`, `website`, `showroom`, `gmb`, `whatsapp`, `offline`). |
| Location on a contact | Only for the **Offline** source: required when creating one, rejected for any other source. |
| Follow-up board | consumer contacts + their stage (`GET /contacts`), stage list (`GET /pipeline/stages`), and the earliest open follow-up date (`GET /tasks`). |
| Move a stage | `POST /contacts/{id}/stages`. The server answers `409` with `missing_fields` until the lead has its details (district, address, source, house stage). Marking a lead Lost sends the reason `other`. |
| Assign a lead | `PUT /contacts/{id}` with `assigned_to`. |
| Due date | an open follow-up (`phone_call`) on the lead: rescheduled if one exists, booked for the lead's owner otherwise. |
| Lead history | notes and follow-ups (`/contacts/{id}/activities`) merged with stage changes (`/contacts/{id}/stages`). A new note is an `internal_note` activity. |
| Sales ledger | `/sales` (Head only on the phone; the server lets everyone read, admin / manager write). |
| Performance | `GET /performance`. |
| Staff directory, assignee pickers | `GET /employees/directory`. |
| Live map, routes, "My route" | `/staff/locations/...` |

## What the API cannot do (so the app does not offer it)

- Add, rename or reorder pipeline stages — the stages are fixed.
- Remove a follow-up date, or leave a lead unassigned (the app says so instead).
- Campaign targets, panchayath / ward / water source / tank-size fields, and sale referrals — there is nowhere to store them. The sales register keeps date, buyer, phones, address and product only, so the ledger shows a sales count, not revenue.
- A contact needs a **district** and an **address**; the form asks for both before sending.

## Tests

| Layer | Command | What it covers |
| --- | --- | --- |
| Unit and widget | `flutter test` | `ApiClient` error handling, every service adapter, the models, view models and screens, against fake servers |
| End to end | `python tests/run_mobile_e2e.py` (from `ogera_crm_backend`, needs Flutter on `PATH`) | The real services and view models over HTTP against the real API on a throwaway SQLite database: sign in, contacts, professionals, follow-ups, sales, performance, staff locations |
| Backend integration | `python -m pytest tests` (from `ogera_crm_backend`, venv) | The endpoints the app uses, through the real FastAPI app |
| On a device | `flutter test integration_test` | Staff location flow, against a connected device or emulator |

`flutter test` skips the end-to-end file unless `E2E_API_URL` is set, so it stays offline.
