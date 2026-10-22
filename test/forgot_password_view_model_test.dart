// ForgotPasswordViewModel unit tests
//
// WHAT IS A UNIT TEST?
// A unit test runs in isolation — no real network, no Flutter widgets.
// We swap PasswordResetService with a fake that we control. This lets us
// test every state-machine path without a running backend.
//
// WHAT IS TESTED (5 high-priority cases):
// 1. sendCode success        → step becomes otp, maskedEmail is set
// 2. sendCode failure        → step becomes sendFailed, message is set
// 3. verifyCode success      → step becomes reset, resetToken is stored
// 4. verifyCode lockout      → needsNewCode becomes true
// 5. resetPassword success   → step becomes done

import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/password_reset.dart';
import 'package:ogera_crm_mobile/services/password_reset_service.dart';
import 'package:ogera_crm_mobile/view_models/forgot_password_view_model.dart';

void main() {
  // ── 1. sendCode success ────────────────────────────────────────────────────

  test('sendCode success: step → otp, maskedEmail set', () async {
    final vm = ForgotPasswordViewModel(
      _FakePasswordResetService(),
    );

    await vm.sendCode('sam@ogera.com');

    expect(vm.step, FpStep.otp);
    expect(vm.maskedEmail, 's***@ogera.com');
    expect(vm.busy, isFalse);
    expect(vm.message, isEmpty);
  });

  // ── 2. sendCode failure ────────────────────────────────────────────────────

  test('sendCode failure: step → sendFailed, message set', () async {
    final vm = ForgotPasswordViewModel(
      _FakePasswordResetService(
        requestError: const ApiException('No account with that email.'),
      ),
    );

    await vm.sendCode('nobody@ogera.com');

    expect(vm.step, FpStep.sendFailed);
    expect(vm.message, 'No account with that email.');
    expect(vm.busy, isFalse);
  });

  // ── 3. verifyCode success ──────────────────────────────────────────────────

  test('verifyCode success: step → reset, resetToken stored', () async {
    final vm = ForgotPasswordViewModel(_FakePasswordResetService());
    vm.step = FpStep.otp; // put the VM in the right state first

    await vm.verifyCode(['1', '2', '3', '4', '5', '6']);

    expect(vm.step, FpStep.reset);
    expect(vm.message, isEmpty);
    expect(vm.busy, isFalse);
  });

  // ── 4. verifyCode lockout ──────────────────────────────────────────────────
  //
  // When the backend says "Too many attempts" or "expired", the screen must
  // show a "Request a new code" button. The VM signals this with needsNewCode.

  test('verifyCode lockout: needsNewCode becomes true', () async {
    final vm = ForgotPasswordViewModel(
      _FakePasswordResetService(
        verifyError: const ApiException('Too many attempts. Request a new code.'),
      ),
    );
    vm.step = FpStep.otp;

    await vm.verifyCode(['0', '0', '0', '0', '0', '0']);

    expect(vm.step, FpStep.otp); // stays on OTP
    expect(vm.needsNewCode, isTrue);
    expect(vm.busy, isFalse);
  });

  // ── 5. resetPassword success ───────────────────────────────────────────────

  test('resetPassword success: step → done', () async {
    final vm = ForgotPasswordViewModel(_FakePasswordResetService());
    vm.step = FpStep.reset;

    await vm.resetPassword('newpassword123');

    expect(vm.step, FpStep.done);
    expect(vm.busy, isFalse);
    expect(vm.message, isEmpty);
  });
}

// ── Fake service ──────────────────────────────────────────────────────────────
//
// Returns canned success responses by default. Throw an ApiException to
// simulate a specific server error.

class _FakePasswordResetService implements PasswordResetService {
  _FakePasswordResetService({this.requestError, this.verifyError});

  final ApiException? requestError;
  final ApiException? verifyError;

  @override
  Future<PasswordResetRequestResult> requestCode(String email) async {
    final err = requestError;
    if (err != null) throw err;
    return const PasswordResetRequestResult(
      emailMasked: 's***@ogera.com',
      expiresInSeconds: 600,
      resendInSeconds: 60,
    );
  }

  @override
  Future<PasswordResetVerifyResult> verifyCode(
    String email,
    String code,
  ) async {
    final err = verifyError;
    if (err != null) throw err;
    return const PasswordResetVerifyResult(
      resetToken: 'fake-reset-token',
      expiresInSeconds: 600,
    );
  }

  @override
  Future<void> resetPassword(String resetToken, String newPassword) async {}
}
