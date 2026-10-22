// ViewModel for the forgot-password flow.
//
// WHY A VIEW MODEL?
// The forgot-password screen has 6 distinct states (steps) and several async
// operations. Keeping all that logic here means the screen stays simple: it
// just reads the step and renders the right widget.
//
// HOW STATE CHANGES WORK (beginner explanation):
// 1. The screen calls a method like vm.sendCode('user@email.com').
// 2. The method changes `step` (and other fields) and calls notifyListeners().
// 3. Every widget that called context.watch<ForgotPasswordViewModel>() rebuilds
//    automatically with the new state.
//
// This is the Provider pattern the app already uses for LoginViewModel.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../services/password_reset_service.dart';

/// The six states the forgot-password screen moves through.
///
///  email → sending → otp → reset → done
///                 ↘ sendFailed ↗  (retry loops back to sending)
enum FpStep { email, sending, sendFailed, otp, reset, done }

/// Holds every piece of state the forgot-password screen needs.
///
/// The screen reads these values via `context.watch<ForgotPasswordViewModel>()`
/// and calls [sendCode], [verifyCode], [resetPassword] when the user taps a
/// button.
class ForgotPasswordViewModel extends ChangeNotifier {
  ForgotPasswordViewModel(this._service);

  final PasswordResetService _service;

  FpStep step = FpStep.email;

  /// The last API-level error message. Shown inline on the current step.
  String message = '';

  /// The email address the user typed (kept for the verify and reset calls).
  String _email = '';
  String get email => _email;

  /// Masked email shown on the OTP step, e.g. "s***@ogera.com".
  String maskedEmail = '';

  /// The single-use reset token returned after OTP verification.
  String _resetToken = '';

  /// Seconds remaining before the user can request another code.
  int resendIn = 0;

  /// True while an async call is in flight — disables the submit button.
  bool busy = false;

  /// True when the error means the OTP is expired or locked out. The screen
  /// shows a "Request a new code" prompt instead of "try again".
  bool needsNewCode = false;

  Timer? _resendTimer;

  // ── Actions ──────────────────────────────────────────────────────────────────

  /// Requests a 6-digit code for [email] and advances to the OTP step.
  ///
  /// If called from the OTP step (resend), it stays on the OTP step on failure
  /// instead of switching to sendFailed, so the user does not lose their place.
  Future<void> sendCode(String email) async {
    _email = email.trim();
    busy = true;
    message = '';
    final isResend = step == FpStep.otp;
    if (!isResend) step = FpStep.sending;
    notifyListeners();

    try {
      final result = await _service.requestCode(_email);
      maskedEmail = result.emailMasked;
      needsNewCode = false;
      step = FpStep.otp;
      _startCountdown(result.resendInSeconds);
    } on ApiException catch (e) {
      message = e.message;
      if (!isResend) step = FpStep.sendFailed;
    } catch (_) {
      message = 'Something went wrong. Please try again.';
      if (!isResend) step = FpStep.sendFailed;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Verifies the 6-digit code and advances to the password-reset step.
  Future<void> verifyCode(List<String> digits) async {
    final code = digits.join();
    if (code.length != 6 || busy) return;

    busy = true;
    message = '';
    notifyListeners();

    try {
      final result = await _service.verifyCode(_email, code);
      _resetToken = result.resetToken;
      step = FpStep.reset;
    } on ApiException catch (e) {
      message = e.message;
      needsNewCode = _isExpiredOrLocked(e.message);
    } catch (_) {
      message = 'Something went wrong. Please try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Sets [newPassword] as the new account password using the stored reset token.
  Future<void> resetPassword(String newPassword) async {
    busy = true;
    message = '';
    notifyListeners();

    try {
      await _service.resetPassword(_resetToken, newPassword);
      step = FpStep.done;
    } on ApiException catch (e) {
      message = e.message;
      needsNewCode = _isExpiredOrLocked(e.message);
    } catch (_) {
      message = 'Something went wrong. Please try again.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Resets all state to the initial email step.
  ///
  /// Called by LoginScreen before pushing this screen so the user always
  /// starts fresh (not mid-flow from a previous visit).
  void reset() {
    _resendTimer?.cancel();
    step = FpStep.email;
    message = '';
    _email = '';
    maskedEmail = '';
    _resetToken = '';
    resendIn = 0;
    busy = false;
    needsNewCode = false;
    notifyListeners();
  }

  // ── Internals ─────────────────────────────────────────────────────────────────

  void _startCountdown(int seconds) {
    _resendTimer?.cancel();
    resendIn = seconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendIn <= 0) {
        timer.cancel();
        return;
      }
      resendIn--;
      notifyListeners();
    });
  }

  bool _isExpiredOrLocked(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('expired') ||
        lower.contains('too many') ||
        lower.contains('no active code');
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }
}
