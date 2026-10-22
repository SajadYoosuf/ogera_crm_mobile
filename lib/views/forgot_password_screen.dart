// Forgot-password screen — three-step flow to reset an account password.
//
// WHAT THIS SCREEN DOES:
// 1. Email step   — user types their email and taps "Send code".
// 2. OTP step     — user enters the 6-digit code that was emailed to them.
// 3. Reset step   — user sets a new password (typed twice for confirmation).
// 4. Done step    — success confirmation with a "Back to login" button.
// (Plus a "sending" loading state and a "sendFailed" error state.)
//
// HOW STATE IS MANAGED:
// All API state (which step we're on, error messages, busy flag) lives in
// ForgotPasswordViewModel. This screen only holds local widget state:
// text controllers, focus nodes, and password-visibility toggles.
//
// WHY StatefulWidget INSTEAD OF StatelessWidget?
// We need to dispose TextEditingControllers and FocusNodes when the screen
// is removed from the tree, which requires an initState/dispose cycle.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/ogera_colors.dart';
import '../view_models/forgot_password_view_model.dart';

// Password rules: 6–15 characters, must match confirmation.
// These mirror the backend's PASSWORD_MIN_LENGTH / PASSWORD_MAX_LENGTH config.
const _kMinPass = 6;
const _kMaxPass = 15;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Email step
  final _emailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();

  // OTP step — 6 individual boxes, each with its own controller and focus node
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpNodes = List.generate(6, (_) => FocusNode());

  // Reset step
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _resetFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailController.dispose();
    for (final c in _otpControllers) { c.dispose(); }
    for (final n in _otpNodes) { n.dispose(); }
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  List<String> get _digits =>
      _otpControllers.map((c) => c.text.trim()).toList();

  void _clearOtp() {
    for (final c in _otpControllers) { c.clear(); }
    if (_otpNodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpNodes.first.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ForgotPasswordViewModel>();
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hero(topPad: topPad, step: vm.step),
                  _Body(
                    vm: vm,
                    emailController: _emailController,
                    emailFormKey: _emailFormKey,
                    otpControllers: _otpControllers,
                    otpNodes: _otpNodes,
                    digits: _digits,
                    onClearOtp: _clearOtp,
                    passwordController: _passwordController,
                    confirmController: _confirmController,
                    resetFormKey: _resetFormKey,
                    obscurePassword: _obscurePassword,
                    obscureConfirm: _obscureConfirm,
                    onTogglePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onToggleConfirm: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    bottomPad: bottomPad,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

/// Forest-green banner at the top — mirrors the LoginScreen hero.
class _Hero extends StatelessWidget {
  const _Hero({required this.topPad, required this.step});

  final double topPad;
  final FpStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 32),
      color: OgeraColors.forest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back arrow
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Logo chip
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Image.asset(
              'assets/images/ogera-symbol.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.water_drop_rounded,
                color: OgeraColors.forest,
                size: 22,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Let's get you back in.",
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'പാസ്‌വേഡ് മാറ്റാം, സുരക്ഷിതമായി.',
            style: TextStyle(
              color: OgeraColors.forestAccent,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Verify your email and set a new password.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Body ──────────────────────────────────────────────────────────────────────

/// White form panel — switches content based on the current step.
class _Body extends StatelessWidget {
  const _Body({
    required this.vm,
    required this.emailController,
    required this.emailFormKey,
    required this.otpControllers,
    required this.otpNodes,
    required this.digits,
    required this.onClearOtp,
    required this.passwordController,
    required this.confirmController,
    required this.resetFormKey,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.bottomPad,
  });

  final ForgotPasswordViewModel vm;
  final TextEditingController emailController;
  final GlobalKey<FormState> emailFormKey;
  final List<TextEditingController> otpControllers;
  final List<FocusNode> otpNodes;
  final List<String> digits;
  final VoidCallback onClearOtp;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final GlobalKey<FormState> resetFormKey;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(24, 28, 24, 28 + bottomPad),
      child: switch (vm.step) {
        FpStep.email => _EmailStep(
          vm: vm,
          controller: emailController,
          formKey: emailFormKey,
        ),
        FpStep.sending => const _SendingStep(),
        FpStep.sendFailed => _SendFailedStep(vm: vm, controller: emailController),
        FpStep.otp => _OtpStep(
          vm: vm,
          controllers: otpControllers,
          nodes: otpNodes,
          digits: digits,
          onClearOtp: onClearOtp,
        ),
        FpStep.reset => _ResetStep(
          vm: vm,
          passwordController: passwordController,
          confirmController: confirmController,
          formKey: resetFormKey,
          obscurePassword: obscurePassword,
          obscureConfirm: obscureConfirm,
          onTogglePassword: onTogglePassword,
          onToggleConfirm: onToggleConfirm,
        ),
        FpStep.done => _DoneStep(),
      },
    );
  }
}

// ─── Step widgets ─────────────────────────────────────────────────────────────

/// Step 1: user types their email address.
class _EmailStep extends StatelessWidget {
  const _EmailStep({
    required this.vm,
    required this.controller,
    required this.formKey,
  });

  final ForgotPasswordViewModel vm;
  final TextEditingController controller;
  final GlobalKey<FormState> formKey;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Reset password',
            style: TextStyle(
              color: OgeraColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter the email linked to your account and we'll send a 6-digit code.",
            style: TextStyle(
              color: OgeraColors.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          const _FieldLabel('Email address'),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            enabled: !vm.busy,
            style: const TextStyle(fontSize: 15, color: OgeraColors.ink),
            decoration: _borderedDecoration(hint: 'you@yourcompany.com'),
            validator: (v) {
              final val = v?.trim() ?? '';
              if (val.isEmpty) return 'Enter your email address.';
              if (!val.contains('@') || !val.contains('.')) {
                return 'Enter a valid email address.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(context),
          ),
          if (vm.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ErrorBanner(vm.message),
          ],
          const SizedBox(height: 28),
          _GreenButton(
            label: 'Send code',
            busy: vm.busy,
            onPressed: () => _submit(context),
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext context) {
    if (!(formKey.currentState?.validate() ?? false) || vm.busy) return;
    vm.sendCode(controller.text);
  }
}

/// Step 2a: animated loading state while the email is being sent.
class _SendingStep extends StatelessWidget {
  const _SendingStep();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          CircularProgressIndicator(
            color: OgeraColors.forestInteractive,
            strokeWidth: 2.8,
          ),
          SizedBox(height: 24),
          Text(
            'Sending your code…',
            style: TextStyle(
              color: OgeraColors.muted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'This usually takes a few seconds.',
            style: TextStyle(color: OgeraColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Step 2b: shown when the send request failed.
class _SendFailedStep extends StatelessWidget {
  const _SendFailedStep({required this.vm, required this.controller});

  final ForgotPasswordViewModel vm;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Icon(
          Icons.error_outline_rounded,
          color: OgeraColors.danger,
          size: 48,
        ),
        const SizedBox(height: 16),
        const Text(
          'Could not send code',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: OgeraColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        if (vm.message.isNotEmpty)
          Text(
            vm.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: OgeraColors.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        const SizedBox(height: 32),
        _GreenButton(
          label: 'Try again',
          busy: vm.busy,
          onPressed: () => vm.sendCode(controller.text),
        ),
      ],
    );
  }
}

/// Step 3: 6-digit OTP entry.
///
/// Each box is a separate TextField. Entering a digit auto-advances focus to
/// the next box. Pressing Backspace on an empty box moves focus back.
class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.vm,
    required this.controllers,
    required this.nodes,
    required this.digits,
    required this.onClearOtp,
  });

  final ForgotPasswordViewModel vm;
  final List<TextEditingController> controllers;
  final List<FocusNode> nodes;
  final List<String> digits;
  final VoidCallback onClearOtp;

  @override
  Widget build(BuildContext context) {
    final codeComplete = digits.every((d) => d.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter verification code',
          style: TextStyle(
            color: OgeraColors.ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              color: OgeraColors.muted,
              fontSize: 14,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'A 6-digit code was sent to '),
              TextSpan(
                text: vm.maskedEmail,
                style: const TextStyle(
                  color: OgeraColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        // OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 46,
              child: KeyboardListener(
                focusNode: FocusNode(),
                // Detect Backspace on empty box to move focus back.
                onKeyEvent: (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.backspace &&
                      controllers[i].text.isEmpty &&
                      i > 0) {
                    nodes[i - 1].requestFocus();
                  }
                },
                child: TextField(
                  controller: controllers[i],
                  focusNode: nodes[i],
                  enabled: !vm.busy,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: OgeraColors.ink,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF7FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: OgeraColors.line,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: OgeraColors.forestInteractive,
                        width: 2,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: OgeraColors.line,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.length > 1) {
                      // Paste detected — fill all 6 boxes with the first 6 digits.
                      final cleaned =
                          value.replaceAll(RegExp(r'[^0-9]'), '');
                      for (var j = 0; j < 6; j++) {
                        controllers[j].text =
                            j < cleaned.length ? cleaned[j] : '';
                      }
                      final lastFilled =
                          (cleaned.length - 1).clamp(0, 5);
                      nodes[lastFilled].requestFocus();
                    } else if (value.isNotEmpty && i < 5) {
                      nodes[i + 1].requestFocus();
                    }
                  },
                ),
              ),
            );
          }),
        ),
        if (vm.message.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ErrorBanner(vm.message),
          if (vm.needsNewCode) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: vm.busy ? null : () => vm.sendCode(vm.email),
                child: const Text(
                  'Request a new code',
                  style: TextStyle(
                    color: OgeraColors.forestInteractive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 28),
        _GreenButton(
          label: 'Verify',
          busy: vm.busy,
          onPressed: codeComplete ? () => vm.verifyCode(digits) : null,
        ),
        const SizedBox(height: 16),
        // Resend cooldown
        Center(
          child: vm.resendIn > 0
              ? Text(
                  'Resend code in ${vm.resendIn}s',
                  style: const TextStyle(
                    color: OgeraColors.muted,
                    fontSize: 13.5,
                  ),
                )
              : GestureDetector(
                  onTap: vm.busy
                      ? null
                      : () {
                          onClearOtp();
                          vm.sendCode(vm.email);
                        },
                  child: const Text(
                    "Didn't receive it?  Resend code",
                    style: TextStyle(
                      color: OgeraColors.forestInteractive,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Step 4: new password + confirm password.
///
/// Uses StatefulWidget so we can listen to the text controllers and show live
/// password strength chips (A–Z / a–z / 0–9) and a real-time match indicator.
class _ResetStep extends StatefulWidget {
  const _ResetStep({
    required this.vm,
    required this.passwordController,
    required this.confirmController,
    required this.formKey,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onTogglePassword,
    required this.onToggleConfirm,
  });

  final ForgotPasswordViewModel vm;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final GlobalKey<FormState> formKey;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;

  @override
  State<_ResetStep> createState() => _ResetStepState();
}

class _ResetStepState extends State<_ResetStep> {
  void _rebuild() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.passwordController.addListener(_rebuild);
    widget.confirmController.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.passwordController.removeListener(_rebuild);
    widget.confirmController.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final passwordController = widget.passwordController;
    final confirmController = widget.confirmController;
    final formKey = widget.formKey;
    final obscurePassword = widget.obscurePassword;
    final obscureConfirm = widget.obscureConfirm;
    final onTogglePassword = widget.onTogglePassword;
    final onToggleConfirm = widget.onToggleConfirm;

    final password = passwordController.text;
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));

    final confirmText = confirmController.text;
    final showMatchHint = confirmText.isNotEmpty;
    final passwordsMatch = password == confirmText;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Set new password',
            style: TextStyle(
              color: OgeraColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a password between 6 and 15 characters.',
            style: TextStyle(
              color: OgeraColors.muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          const _FieldLabel('New password'),
          const SizedBox(height: 7),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.next,
            enabled: !vm.busy,
            style: const TextStyle(fontSize: 15, color: OgeraColors.ink),
            decoration: _borderedDecoration(
              hint: 'Enter new password',
              suffix: _EyeButton(
                obscure: obscurePassword,
                onToggle: onTogglePassword,
              ),
            ),
            validator: (v) {
              final val = v ?? '';
              if (val.isEmpty) return 'Enter a new password.';
              if (val.length < _kMinPass) return 'At least $_kMinPass characters.';
              if (val.length > _kMaxPass) return 'At most $_kMaxPass characters.';
              return null;
            },
          ),
          const SizedBox(height: 8),
          // Live strength indicators — light up green as each criterion is met.
          Row(
            children: [
              _StrengthChip(label: 'A–Z', met: hasUpper),
              const SizedBox(width: 8),
              _StrengthChip(label: 'a–z', met: hasLower),
              const SizedBox(width: 8),
              _StrengthChip(label: '0–9', met: hasNumber),
            ],
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Confirm password'),
          const SizedBox(height: 7),
          TextFormField(
            controller: confirmController,
            obscureText: obscureConfirm,
            textInputAction: TextInputAction.done,
            enabled: !vm.busy,
            style: const TextStyle(fontSize: 15, color: OgeraColors.ink),
            decoration: _borderedDecoration(
              hint: 'Re-enter new password',
              suffix: _EyeButton(
                obscure: obscureConfirm,
                onToggle: onToggleConfirm,
              ),
            ),
            validator: (v) {
              if ((v ?? '').isEmpty) return 'Re-enter your new password.';
              if (v != passwordController.text) return 'Passwords do not match.';
              return null;
            },
            onFieldSubmitted: (_) => _submit(context),
          ),
          // Live match indicator — appears as soon as the user starts typing.
          if (showMatchHint) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  passwordsMatch
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 14,
                  color: passwordsMatch
                      ? OgeraColors.forestInteractive
                      : OgeraColors.danger,
                ),
                const SizedBox(width: 5),
                Text(
                  passwordsMatch
                      ? 'Passwords match'
                      : 'Passwords do not match',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: passwordsMatch
                        ? OgeraColors.forestInteractive
                        : OgeraColors.danger,
                  ),
                ),
              ],
            ),
          ],
          if (vm.message.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ErrorBanner(vm.message),
            if (vm.needsNewCode) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: vm.busy ? null : () => vm.sendCode(vm.email),
                  child: const Text(
                    'Start over — request a new code',
                    style: TextStyle(
                      color: OgeraColors.forestInteractive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 28),
          _GreenButton(
            label: 'Set password',
            busy: vm.busy,
            onPressed: () => _submit(context),
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext context) {
    if (!(widget.formKey.currentState?.validate() ?? false) ||
        widget.vm.busy) {
      return;
    }
    widget.vm.resetPassword(widget.passwordController.text);
  }
}

/// A small pill showing one password-strength criterion.
/// Green (check icon) when the criterion is met; gray (circle outline) otherwise.
class _StrengthChip extends StatelessWidget {
  const _StrengthChip({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? OgeraColors.forestInteractive : OgeraColors.muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Step 5: success confirmation.
class _DoneStep extends StatelessWidget {
  const _DoneStep();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFFEAF8EF),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: OgeraColors.forestInteractive,
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Password updated!',
          style: TextStyle(
            color: OgeraColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Your password has been changed. You can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: OgeraColors.muted,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: OgeraColors.forestInteractive,
              side: const BorderSide(
                color: OgeraColors.forestInteractive,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to login'),
          ),
        ),
      ],
    );
  }
}

// ─── Shared small widgets ──────────────────────────────────────────────────────

/// Shown when the ViewModel has an error message.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: OgeraColors.dangerSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: OgeraColors.danger,
          fontSize: 13.5,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Green primary button used across all steps.
class _GreenButton extends StatelessWidget {
  const _GreenButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: OgeraColors.forestInteractive,
          disabledBackgroundColor: OgeraColors.forestInteractive.withAlpha(100),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
        onPressed: (busy || onPressed == null) ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Bold label shown above each form field.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: OgeraColors.ink,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Eye icon button for show/hide password toggle.
class _EyeButton extends StatelessWidget {
  const _EyeButton({required this.obscure, required this.onToggle});

  final bool obscure;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: obscure ? 'Show password' : 'Hide password',
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 20,
        color: OgeraColors.muted,
      ),
      onPressed: onToggle,
    );
  }
}

// ─── Input decoration ──────────────────────────────────────────────────────────

/// Bordered, rounded decoration matching the app's crm-input pattern.
InputDecoration _borderedDecoration({required String hint, Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFBBC5CE), fontSize: 14.5),
    filled: true,
    fillColor: const Color(0xFFF7FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
      borderSide: const BorderSide(color: OgeraColors.line, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
      borderSide: const BorderSide(
        color: OgeraColors.forestInteractive,
        width: 2,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
      borderSide: const BorderSide(color: OgeraColors.danger, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
      borderSide: const BorderSide(color: OgeraColors.danger, width: 2),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
      borderSide: const BorderSide(color: OgeraColors.line),
    ),
    suffixIcon: suffix,
    isDense: false,
  );
}
