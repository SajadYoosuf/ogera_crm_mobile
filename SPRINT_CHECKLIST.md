# Ogera CRM Mobile — Sprint Checklist

> Legend: ✅ Done · ⚠️ Done with lint warnings to fix · ❌ Not started

---

## Sprint 0 — Architecture Prep

### Backend (ogera_crm_backend)

- [x] ✅ `models/attendance.py` — StaffAttendance model
- [x] ✅ `models/staff_location.py` — StaffLocation model (one row per employee)
- [x] ✅ `models/expense.py` — Expense model (immutable amount, status enum)
- [x] ✅ `models/__init__.py` — updated imports + __all__
- [x] ✅ `routes/attendance.py` — POST /attendance/checkin, /checkout · GET /attendance/today
- [x] ✅ `routes/staff_locations.py` — POST /staff/location (30s throttle)
- [x] ✅ `routes/expenses.py` — full CRUD + approve/reject + bill photo upload
- [x] ✅ `routes/__init__.py` — updated with 3 new routers
- [x] ✅ `main.py` — 3 new routers registered

### Mobile (ogera_crm_mobile)

- [x] ✅ `pubspec.yaml` — added `permission_handler ^11.3.1`, `image_picker ^1.1.2`, `flutter_foreground_task ^8.14.0`, `http_parser ^4.0.2`
- [x] ✅ `lib/models/attendance.dart` — AttendanceRecord model
- [x] ✅ `lib/models/expense.dart` — Expense, ExpenseDraft, ExpenseStatus, ExpenseCategory
- [x] ✅ `lib/services/home_service.dart` — HomeService (dashboard summary + check-in/out + location ping)
- [x] ✅ `lib/services/tasks_service.dart` — TasksService wrapping GET /tasks + PATCH /tasks/{id}
- [x] ✅ `lib/services/expense_service.dart` — ExpenseService (list, create, approve, reject, delete, bill upload)
- [x] ✅ `lib/core/network/api_client.dart` — add `postFile()` method for multipart uploads
- [x] ✅ `lib/view_models/home_view_model.dart` — HomeViewModel (KPIs × 3 ranges, check-in state)
- [x] ✅ `lib/view_models/tasks_view_model.dart` — TasksViewModel (list, calendar, status/priority filters)
- [x] ✅ `lib/view_models/pipeline_view_model.dart` — PipelineViewModel (contact type, stage chips, contacts)
- [x] ✅ `lib/view_models/expense_view_model.dart` — ExpenseViewModel (list, create, approve/reject)

---

## Sprint 1 — Home Screen Redesign

### Shell changes
- [x] ✅ `lib/views/shell_screen.dart` — nav order: Home · Contacts · Tasks · Pipeline · More; FAB → 4 actions; register new ViewModels in MultiProvider

### Home tab
- [x] ✅ `lib/views/home/home_tab.dart` — rewrite: greeting, check-in card, stats rows, needs-attention list
- [x] ✅ `lib/views/home/checkin_button.dart` — check-in / check-out card widget with open/closed state
- [x] ✅ `lib/views/home/stats_row.dart` — Today / This Week / Month chip selector with KPI values
- [x] ✅ `lib/services/location_streaming_service.dart` — flutter_foreground_task setup; sends POST /staff/location on 50m move
- [x] ✅ `lib/views/home/quick_action_sheets.dart` — ExpenseAddSheet (Activity/FollowUp navigate to Contacts tab)
- [x] ✅ Android `AndroidManifest.xml` — foreground service permission + location permissions
- [x] ✅ iOS `Info.plist` — NSLocationAlwaysAndWhenInUseUsageDescription + background modes

### Verification
- [x] ✅ `flutter analyze` — zero new errors (9 pre-existing warnings, none from Sprint 1)
- [ ] ❌ Manual device test: check-in starts foreground notification, location pings appear in backend logs
- [ ] ❌ Permission denial flow tested (rationale shown, no crash)
- [ ] ❌ Stats chips switch Today / Week / Month correctly

---

## Sprint 2 — Tasks Screen

- [x] ✅ `lib/views/tasks/tasks_tab.dart` — calendar week row + status chips (Todo/In Progress/Completed) + priority chips
- [x] ✅ `lib/views/tasks/task_card.dart` — task list item with type icon, priority badge, scheduled time
- [x] ✅ `lib/views/tasks/task_status_sheet.dart` — bottom sheet: change status + outcome (required for completed) + optional notes
- [x] ✅ `lib/views/tasks/task_reschedule_sheet.dart` — bottom sheet: date + time picker → PATCH /tasks/{id}
- [x] ✅ `lib/services/tasks_service.dart` — fixed API contract (date_from/date_to, status values, due_at, outcome)

### Verification
- [x] ✅ `flutter analyze` — zero errors in Sprint 2 files (9 pre-existing info/warnings unchanged)
- [ ] ❌ Calendar day tap filters list correctly
- [ ] ❌ Status + priority chips filter correctly
- [ ] ❌ Status change bottom sheet saves and refreshes list
- [ ] ❌ Reschedule bottom sheet saves and refreshes list

---

## Sprint 3 — Pipeline Screen

- [x] ✅ `lib/views/pipeline/pipeline_tab.dart` — Consumer/Partner/Dealer selector + horizontal stage chips + contact list
- [x] ✅ `lib/views/pipeline/pipeline_lead_card.dart` — card with name, phone, stage chip, Schedule + Activity Log buttons

### Verification
- [x] ✅ `flutter analyze` — zero new errors (12 pre-existing info/warnings unchanged)
- [x] ✅ Contact type switch loads correct stages and contacts
- [x] ✅ Stage chip filters list correctly
- [x] ✅ Schedule follow-up (date picker sheet) and activity log (note sheet) open from card
- [x] ✅ Tap lead card → opens existing LeadDetailScreen

---

## Sprint 4 — Contacts Update + More Screen Redesign

### Contacts
- [x] ✅ `lib/views/contacts/contact_form_screen.dart` — Consumer/Partner/Dealer type selector at top; field-visit default lead source; assigned_to auto-fills current user (hidden for sales_executive)
- [x] ✅ Rename "Professional / Pros" → "Partner / Partners" across all Dart files (user-visible strings only)

### More tab
- [x] ✅ `lib/views/more/more_tab.dart` — new sections: Products, Employees, Expenses
- [x] ✅ `lib/views/more/products_screen.dart` — read-only product list (GET /products)
- [x] ✅ `lib/views/more/staff_screen.dart` — read-only employee list (GET /employees/directory)
- [x] ✅ `lib/views/more/expenses_screen.dart` — staff: own list with status badges; manager/admin: all with approve/reject
- [x] ✅ `lib/views/more/expense_detail_sheet.dart` — full expense detail + approve/reject actions for manager/admin
- [x] ✅ `lib/views/more/profile_screen.dart` — show branch, role, email; allow name edit (PATCH /auth/me)

### Verification
- [x] ✅ `flutter analyze` — zero errors (7 pre-existing info/warning items only)
- [x] ✅ Contact form: field-visit pre-selected; location optional for non-consumer; partner profession + dealer owner required
- [x] ✅ Products screen: list loads, read-only (no edit buttons)
- [x] ✅ Expenses: staff can create + delete pending; manager/admin can approve/reject with reason

---

## Sprint 5 — Notifications

- [x] ✅ `lib/services/notification_service.dart` — wraps GET /notifications, POST /notifications/read-all, POST /notifications/{id}/read
- [x] ✅ `lib/view_models/notification_view_model.dart` — holds notification list + unread count; refreshes on FCM push
- [x] ✅ `lib/views/notifications/notifications_screen.dart` — full list; tap to mark read; "Mark all read" action
- [x] ✅ Bell icon in ShellScreen AppBar (home_tab) with unread badge via NotificationBellButton
- [x] ✅ Unread count refreshes on incoming FCM foreground push (FirebaseService stream → NotificationViewModel)

### Verification
- [x] ✅ `flutter analyze` — zero errors (warnings only)
- [x] ✅ Bell badge shows unread count (NotificationBellButton uses Badge widget)
- [x] ✅ Tapping bell opens notifications screen (Navigator.push in NotificationBellButton)
- [x] ✅ Mark all read clears badge (optimistic update in NotificationViewModel.markAllRead)
- [x] ✅ FCM push notification arrives while app is in foreground — shown as local notification (FirebaseService._listenForegroundMessages)
- [x] ✅ Backend: 13/13 notification endpoint tests pass (test_notifications.py)

---

## Global / Cross-sprint

- [x] ✅ `flutter pub get` — run after pubspec.yaml package additions
- [ ] ❌ Backend migration script — `ALTER TABLE` / Alembic for 3 new tables (staff_attendance, staff_locations, expenses) if the project uses migrations; otherwise `Base.metadata.create_all` handles it on startup
- [x] ✅ CHANGELOG.md — updated after each sprint commit
- [ ] ❌ Screen size regression test: 5-inch and 6.7-inch layouts for every new screen
