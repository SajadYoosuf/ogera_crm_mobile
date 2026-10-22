// Service that wraps the three password-reset API endpoints.
//
// WHY A SEPARATE SERVICE?
// Keeping password-reset calls here (not in AuthService) follows the same
// separation already used for contacts, followups, etc. Each service has one
// responsibility. AuthService stays focused on session management.
//
// HOW ERRORS WORK:
// ApiClient already parses the FastAPI { "detail": ... } error envelope and
// throws ApiException with a ready-to-show message. This service lets that
// exception bubble up — the ViewModel catches it and puts the message in the UI.

import '../core/network/api_client.dart';
import '../models/password_reset.dart';

class PasswordResetService {
  const PasswordResetService(this._api);

  final ApiClient _api;

  /// Step 1 — asks the backend to email a 6-digit code to [email].
  ///
  /// Returns the masked email address and cooldown timings on success.
  /// Throws [ApiException] if the account is not found (404) or the email
  /// service is down (503).
  Future<PasswordResetRequestResult> requestCode(String email) async {
    final body = await _api.post(
      '/auth/password-reset/request',
      body: {'email': email.trim()},
    );
    return PasswordResetRequestResult.fromJson(asMap(body));
  }

  /// Step 2 — verifies the [code] the user received by email.
  ///
  /// Returns a short-lived reset token on success.
  /// Throws [ApiException] if the code is wrong, expired, or the account is
  /// locked out after too many wrong attempts.
  Future<PasswordResetVerifyResult> verifyCode(
    String email,
    String code,
  ) async {
    final body = await _api.post(
      '/auth/password-reset/verify',
      body: {'email': email.trim(), 'code': code},
    );
    return PasswordResetVerifyResult.fromJson(asMap(body));
  }

  /// Step 3 — sets [newPassword] as the account's password.
  ///
  /// [resetToken] comes from [verifyCode]. It is single-use and expires in
  /// 10 minutes. Throws [ApiException] if the token is expired or already used.
  Future<void> resetPassword(String resetToken, String newPassword) async {
    await _api.post(
      '/auth/password-reset/reset',
      body: {'reset_token': resetToken, 'new_password': newPassword},
    );
  }
}
