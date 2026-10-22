// Response models for the three-step password-reset flow.
//
// WHY SEPARATE MODELS?
// The backend sends different JSON shapes at each step. These classes translate
// the raw API response into typed Dart values, so the service and view model
// never access Map keys directly (which crashes silently on typos).

/// What the backend sends when a reset code is successfully dispatched.
///
/// [emailMasked] is a redacted version of the address (e.g. "s***@ogera.com")
/// shown in the UI so the user knows which inbox to check.
/// [resendInSeconds] is the cooldown before another code can be requested.
/// [expiresInSeconds] is how long the code stays valid.
class PasswordResetRequestResult {
  const PasswordResetRequestResult({
    required this.emailMasked,
    required this.expiresInSeconds,
    required this.resendInSeconds,
  });

  final String emailMasked;
  final int expiresInSeconds;
  final int resendInSeconds;

  factory PasswordResetRequestResult.fromJson(Map<String, dynamic> json) {
    return PasswordResetRequestResult(
      emailMasked: json['email_masked'] as String? ?? '',
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 600,
      resendInSeconds: json['resend_in_seconds'] as int? ?? 60,
    );
  }
}

/// What the backend sends after a code is successfully verified.
///
/// [resetToken] is a short-lived JWT that proves the user owns the account.
/// It must be passed to the final reset call within [expiresInSeconds].
class PasswordResetVerifyResult {
  const PasswordResetVerifyResult({
    required this.resetToken,
    required this.expiresInSeconds,
  });

  final String resetToken;
  final int expiresInSeconds;

  factory PasswordResetVerifyResult.fromJson(Map<String, dynamic> json) {
    return PasswordResetVerifyResult(
      resetToken: json['reset_token'] as String? ?? '',
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 600,
    );
  }
}
