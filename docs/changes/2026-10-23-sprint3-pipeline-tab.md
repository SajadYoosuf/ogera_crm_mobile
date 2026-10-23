# Sprint 3 — Pipeline Tab (Consumer / Partner / Dealer, API-connected)

## Why
The Pipeline tab was a `ComingSoonTab` placeholder. Sales teams need to see
every contact's pipeline stage across Consumer, Partner and Dealer boards
without leaving the app.

## What changed

### New files
- `lib/services/pipeline_service.dart` — `PipelineService` fetches
  `GET /pipeline/stages?contact_type=...` (integer-ID stage list) and
  `GET /contacts?contact_type=...` (full contact list). `PipelineStageModel`
  and `PipelineContact` are the slim domain objects the tab needs.
- `lib/views/pipeline/pipeline_tab.dart` — Complete tab UI:
  contact-type chips (Consumer / Partner / Dealer), horizontally scrollable
  stage strip with per-stage counts from the API, searchable contact list,
  pull-to-refresh.
- `lib/views/pipeline/pipeline_lead_card.dart` — Card widget showing name,
  phone, stage badge, district, verified status, assignee, and Call / WhatsApp
  quick actions. Tap opens `ContactDetailScreen`.

### Modified files
- `lib/view_models/pipeline_view_model.dart` — Rewritten to use
  `PipelineService`. State: `activeType`, `stages` (List<PipelineStageModel>),
  `visibleContacts`, `selectedStage`, `countInStage()`, `selectStage()`.
- `lib/views/shell_screen.dart` — Replaced `ComingSoonTab` for Pipeline with
  `PipelineTab` wrapped in `_LazyTab`; added `PipelineViewModel` provider;
  imported `ApiClient`, `PipelineService`, `PipelineViewModel`, `PipelineTab`.

## Out of scope
- Moving a contact between stages from the pipeline tab (done from
  ContactDetailScreen / follow-up pipeline).
- Adding contacts from the pipeline tab (use Contacts tab or shell FAB).
- Pagination within the pipeline list (loads up to 2000 contacts in pages
  of 100 per type).

## Verification
- `flutter analyze` — zero new errors.
- Consumer / Partner / Dealer chips switch boards and reload stages + contacts.
- Stage strip shows correct counts per stage from the API.
- Tapping a stage filters the list; tapping again returns to "All".
- Search box filters by name or phone locally.
- Tapping a card navigates to ContactDetailScreen.
- Call and WhatsApp buttons launch the correct intent.
