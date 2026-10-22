// ForgotPasswordScreen widget tests — 3 high-priority cases.
//
// WHAT IS A WIDGET TEST?
// Builds real Flutter widgets inside a test environment. We can tap buttons,
// enter text, and check what appears on screen — without a real device or
// backend. The PasswordResetService is replaced with a fake.
//
// CASES:
// 1. Email step: submitting an empty email shows a validation error.
// 2. OTP step:   typing a digit auto-advances focus to the next box.
// 3. Reset step: mismatched passwords show an error on the confirm field.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/models/password_reset.dart';
import 'package:ogera_crm_mobile/services/password_reset_service.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/forgot_password_view_model.dart';
import 'package:ogera_crm_mobile/views/forgot_password_screen.dart';
import 'package:provider/provider.dart';

// ── Harness ───────────────────────────────────────────────────────────────────

/// Builds a minimal Flutter app containing ForgotPasswordScreen.
/// [service] lets each test inject a custom fake.
Widget _harness(ForgotPasswordViewModel vm) {
  return ChangeNotifierProvider<ForgotPasswordViewModel>.value(
    value: vm,
    child: MaterialApp(
      theme: AppTheme.build(),
      home: const ForgotPasswordScreen(),
    ),
  );
}

ForgotPasswordViewModel _vm([PasswordResetService? service]) {
  return ForgotPasswordViewModel(service ?? _FakePasswordResetService());
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Empty email → validation error ──────────────────────────────────────
  //
  // The email field must not be empty when the user taps "Send code".
  // The validator should fire and show an inline error below the field.

  testWidgets('email step: empty email shows validation error',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness(_vm()));

    // Find and tap "Send code" without entering an email.
    final sendButton = find.text('Send code');
    expect(sendButton, findsOneWidget);
    await tester.tap(sendButton);
    await tester.pump(); // let the validator run

    // Expect an inline form error.
    expect(find.text('Enter your email address.'), findsOneWidget);
  });

  // ── 2. OTP digit auto-advances focus ───────────────────────────────────────
  //
  // After typing one digit in OTP box 0, the cursor should move to box 1.
  // We detect this by checking that the second box's FocusNode has focus.

  testWidgets('otp step: typing a digit moves focus to the next box',
      (WidgetTester tester) async {
    // Start the VM at the OTP step with maskedEmail set.
    final vm = _vm();
    vm.step = FpStep.otp;
    vm.maskedEmail = 's***@ogera.com';

    await tester.pumpWidget(_harness(vm));
    await tester.pump();

    // Find the first OTP TextField (by index in the Row of 6).
    final otpBoxes = find.byType(TextField);
    expect(otpBoxes, findsNWidgets(6));

    // Tap the first box to give it focus.
    await tester.tap(otpBoxes.at(0));
    await tester.pump();

    // Type a single digit.
    await tester.enterText(otpBoxes.at(0), '5');
    await tester.pump();

    // The second box should now have focus.
    final secondFocus = tester.widget<TextField>(otpBoxes.at(1)).focusNode;
    expect(secondFocus?.hasFocus, isTrue);
  });

  // ── 3. Mismatched passwords → confirm error ─────────────────────────────────
  //
  // If new password and confirm password don't match, the confirm field must
  // show "Passwords do not match." after tapping "Set password".

  testWidgets('reset step: mismatched passwords show a confirm error',
      (WidgetTester tester) async {
    final vm = _vm();
    vm.step = FpStep.reset;

    await tester.pumpWidget(_harness(vm));
    await tester.pump();

    // Fill in new password and a DIFFERENT confirm password.
    final passwordFields = find.byType(TextFormField);
    expect(passwordFields, findsNWidgets(2));

    await tester.enterText(passwordFields.at(0), 'password1');
    await tester.enterText(passwordFields.at(1), 'password2');
    await tester.pump();

    // Scroll the button into view (the default test viewport is 800×600, which
    // can be shorter than the full reset form) then tap.
    final setPasswordButton = find.text('Set password');
    await tester.ensureVisible(setPasswordButton);
    await tester.tap(setPasswordButton);
    await tester.pump();

    // Confirm field error should appear.
    expect(find.text('Passwords do not match.'), findsOneWidget);
  });
}

// ── Fake service ──────────────────────────────────────────────────────────────

class _FakePasswordResetService implements PasswordResetService {
  @override
  Future<PasswordResetRequestResult> requestCode(String email) async {
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
    return const PasswordResetVerifyResult(
      resetToken: 'fake-token',
      expiresInSeconds: 600,
    );
  }

  @override
  Future<void> resetPassword(String resetToken, String newPassword) async {}
}
