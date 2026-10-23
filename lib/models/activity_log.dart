/// Data for one activity log entry.
///
/// Sent to `POST /contacts/{id}/activities`. The backend requires an
/// `activity_type` from the Settings list and non-blank `notes`; the time is
/// set by the server, so the app never sends `logged_at`.
library;

/// What came of the activity. Mirrors the backend `Outcome` values.
enum ActivityOutcome {
  done('done', 'Done'),
  notNow('not_now', 'Not now'),
  noAnswer('no_answer', 'No answer');

  const ActivityOutcome(this.value, this.label);

  final String value;
  final String label;
}

class ActivityDraft {
  const ActivityDraft({
    required this.activityType,
    required this.notes,
    this.title,
    this.outcome,
  });

  /// A value from the `activity_type` Settings list, e.g. `phone_call`.
  final String activityType;

  /// Required by the backend. Trimmed before it is sent.
  final String notes;

  /// Optional short label for the entry.
  final String? title;

  /// Optional result of the attempt.
  final ActivityOutcome? outcome;

  /// The JSON body for the POST. Blank optional fields are left out.
  Map<String, dynamic> toJson() {
    final cleanTitle = title?.trim();
    return {
      'activity_type': activityType,
      'notes': notes.trim(),
      if (cleanTitle != null && cleanTitle.isNotEmpty) 'title': cleanTitle,
      if (outcome != null) 'outcome': outcome!.value,
    };
  }
}
