# UX states audit: loading, empty, error, offline, server

## Why
Sales staff use this app in the field, often on weak mobile data. A screen
that shows raw exception text ("ApiException(null/null): ...") or the wrong
icon ("Something went wrong" when the phone is simply offline) makes people
think the app is broken. Every screen should say what happened and what to do
next, in plain words.

## Checklist

Legend: ✅ already good · 🔧 fixed in this change · ❌ still missing

### Loading
- ✅ Shimmer placeholders for lists (`LoadingListView`, `ShimmerBox`), so the
  layout does not jump when data arrives.
- ✅ `LoadingStateView` for single-unit screens (reports, filtered lists).
- ✅ Buttons show a spinner while they save (login, forms, sheets).
- ❌ Pull-to-refresh is missing on some list screens (checked: only 10 files
  use `RefreshIndicator`).

### Empty
- ✅ `EmptyStateView` with an icon, a title and a short message.
- ❌ Some empty lists still need a clear "what to do next" action.

### Error (screen level)
- ✅ `ErrorStateView` picks an icon and title from `FailureKind`
  (offline, session, no access, not found, server). Retry is hidden for no
  access.
- 🔧 Six places stored `error.toString()` and showed it to users: home,
  expenses, pipeline, notifications, staff, products. They now store a
  friendly message through `describeFailure()` (`lib/core/network/api_client.dart`).
- 🔧 Those screens now pass the failure kind, so an offline failure shows
  "No connection" instead of "Something went wrong".
- 🔧 Home widgets (numbers, recent leads, tasks) show "Check your internet
  connection, then try again." when offline.
- ❌ Contacts, follow-ups and tasks screens still do not pass the failure kind,
  so offline failures there show the server-error icon.

### Error (inline and toast)
- ✅ `InlineErrorBanner` keeps data on screen and offers Retry.
- ✅ `showToast(..., isError: true)` for action failures.
- ✅ Unknown errors in action paths (tasks, lead work, forgot password) use a
  plain sentence instead of the raw exception.

### Network and timeout
- ✅ Connection failures become "Network problem. Check your connection and
  try again." (`ApiClient`).
- ✅ Timeouts after 20 seconds become "The server took too long to respond."
- ✅ Offline cached data shows a banner: "You're offline. Showing the last
  loaded data."

### Server errors
- ✅ 5xx responses become "The server had a problem. Please try again."
- ✅ HTML error pages (a wrong URL or a proxy error) are not shown to users.
- 🔧 Unexpected Dart errors (type or parse bugs) show "Something unexpected
  happened. Pull to refresh or try again in a moment." The real error is logged
  in debug builds only.

### Session and permissions
- ✅ A 401 from any endpoint returns to login with "Your session ended. Please
  sign in again."
- ✅ Restoring a session works offline (it reads local storage only), so the
  user is not signed out by a bad connection.
- ✅ 403 shows "No access" with no retry button.

### Security (found while auditing)
- 🔧 `AuthService.signIn` printed the plain-text password in debug builds. The
  log line was removed.

### Premium polish
- ✅ One visual system for states (`state_views.dart`).
- ❌ Professionals tab is still a placeholder ("coming soon"). Not part of this
  change.

## What changed in code
- `lib/core/network/api_client.dart`: `UserFacingError` and `describeFailure()`.
  Any thrown error becomes a message and a `FailureKind`.
- `lib/view_models/home_view_model.dart`, `expense_view_model.dart`,
  `pipeline_view_model.dart`, `notification_view_model.dart`: store a friendly
  message and an `errorKind` instead of `toString()`.
- `lib/views/more/staff_screen.dart`, `products_screen.dart`,
  `expenses_screen.dart`, `notifications_screen.dart`, `pipeline/pipeline_tab.dart`,
  `home/stats_row.dart`, `home/recent_leads_section.dart`,
  `home/recent_tasks_section.dart`: pass `kind` into `ErrorStateView`.
- `lib/services/auth_service.dart`: password log line removed.

## Still to do (next change)
1. Pass `errorKind` from contacts, follow-ups and tasks view models.
2. Add pull-to-refresh and a clear next-step action to the remaining empty states.
3. Build the Professionals screen, or hide its tab until it is ready.
4. Add tests for `describeFailure()` and for the offline and server-error views.
