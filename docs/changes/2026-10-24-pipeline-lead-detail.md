# Pipeline lead detail: activity log, follow-ups and history

## Why
Tapping a lead on the Pipeline tab opened the full contact record. Sales staff
need a short screen for one lead: who it is, what happened, what is scheduled,
and the history, with the same three tabs the web lead panel uses. Only the
employee who owns a lead can add to it. Everyone else gets a read-only view.

## What changed

### New files
- `lib/views/pipeline/pipeline_lead_detail_screen.dart` — the screen. A compact
  header (name, phone, stage, district, owner, Call and WhatsApp), three tabs
  (Activity log, Follow-ups, History), and one bottom button on the first two
  tabs. The button sits in the Scaffold's bottom bar, so it never covers rows.
- `lib/views/pipeline/lead_work_sheets.dart` — `ScheduleFollowupSheet` and
  `CompleteFollowupSheet` (mark a follow-up done with an outcome and notes).
- `lib/view_models/lead_work_view_model.dart` — `LeadWorkViewModel`. Holds the
  three lists with their own loading and error state, the activity type labels,
  and `canWrite` (true only for the owner).
- `lib/services/lead_work_service.dart` — `LeadWorkService`. The HTTP calls for
  the three lists, scheduling, and completing a follow-up.
- `lib/models/lead_work.dart` — `ActivityEntry`, `FollowupEntry`,
  `LeadHistoryEntry` (with a one-line `summary`), and `FollowupDraft`.
- `test/lead_work_test.dart` — models, the owner rule in the view model, and
  which buttons each tab shows to the owner and to others.

### Modified files
- `lib/views/pipeline/pipeline_lead_card.dart` — tap opens the new screen
  instead of `ContactDetailScreen`. The full record is still one tap away.
- `lib/services/pipeline_service.dart` — `PipelineContact.assignedToId` (the
  owner's id from the contacts list), used for the owner check.
- `lib/views/home/quick_action_sheets.dart` — `ActivityLogSheet` takes
  `contactId` and `contactName` instead of a `Contact`, so the lead screen can
  reuse it.

## Behaviour
- **Owner** (`assigned_to` equals the signed-in employee): sees "Log activity"
  on the Activity log tab and "Schedule follow-up" on the Follow-ups tab. On each
  open follow-up assigned to them: "Mark done" and "Reschedule".
- **Admin / manager**: the same add buttons on any lead, chip "<owner> · head access".
  Mark done and Reschedule on any open follow-up.
- **Other employees**, or an unassigned lead: the same lists, the chip
  "<owner> · view only", and no add buttons. Mark done and Reschedule appear
  only on a follow-up assigned to them.
- **History**: read-only for everyone.
- **Loading**: the three lists load in parallel when the screen opens. After a
  write, only the lists that changed are fetched again.

## Endpoints used
- `GET /contacts/{id}/activities`, `GET /contacts/{id}/followups`, `GET /contacts/{id}/history`
- `POST /contacts/{id}/activities` (via the existing `ActivityService`)
- `POST /contacts/{id}/followups` — `channel`, `due_at`, `assigned_to`, optional `title` and `notes`
- `PATCH /contacts/{id}/followups/{fid}` — `status: completed`, `outcome`, `notes`
- `GET /settings/enums/activity_type` (through the cached catalog)

## Server-side access rule (added in the same change)
The backend enforces the rule in `services/lead_access.py`:
- admin and manager: log, schedule and change anything, on any lead.
- other employees: log and schedule only on a lead assigned to them, schedule only for themselves, and complete or reschedule only follow-ups assigned to them.
- reads are unchanged: everyone can see a lead's activity, follow-ups and history.

This also applies to `/tasks` create and update. The mobile app mirrors the rule, so the buttons match the server.

## Also fixed
- **Reschedule** is on the lead screen (Follow-ups tab, "Reschedule"). It moves the follow-up to a chosen day at 23:59, the web's default for "whole day".
- **Legacy Follow-ups board**: `FollowupsService._scheduleFollowup` (the due-date change) and `addFollowup` (used by the contact detail screen's schedule action) now use the follow-up endpoints. They previously posted a shape the backend rejects. Covered by a test in `test/lead_work_test.dart`.

- **Old timeline** (`FollowupsService.remarks`, used by the contact detail screen): now reads `GET /contacts/{id}/history`, so notes, follow-ups (with their due day) and stage moves all show their labels. The old code read activity fields the server no longer sends.

## Verification
- `flutter analyze` on the changed files: no issues.
- `flutter test test/lead_work_test.dart`: 10 passed.
- Full suite: the same unrelated failures as before this change (stale
  `Contact` model references in `contact_form_*`, `crm_services_test`,
  `mobile_backend_e2e_test`, `professionals_widget_test`, and four stale tests
  in `followups_tab_test`). `tasks_flow_test` and `login_screen_test` are flaky
  across runs.
