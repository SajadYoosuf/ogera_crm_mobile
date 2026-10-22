import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/launchers.dart';
import '../theme/ogera_colors.dart';
import '../view_models/login_view_model.dart';
import '../view_models/session_view_model.dart';

/// Login screen — redesigned to match the Ogera brand identity.
///
/// Layout:
///   ┌─────────────────────────────────┐
///   │  Forest-green hero              │
///   │  Logo · "Namaskaram!" · tagline │
///   ├─────────────────────────────────┤
///   │  White body                     │
///   │  Language toggle · "Welcome"    │
///   │  Head / Staff role picker       │
///   │  Identifier + password fields   │
///   │  Login button (black)           │
///   │  Forgot password · WhatsApp     │
///   └─────────────────────────────────┘
///
/// Backend errors (wrong password, server error, scope mismatch) are shown as
/// an AlertDialog popup rather than inline text, so they are impossible to miss
/// on any screen size.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  /// Which label pill is highlighted. No actual i18n is wired yet;
  /// full localisation comes in a later sprint.
  bool _showMalayalam = false;

  @override
  void initState() {
    super.initState();
    // A session that expired elsewhere (idle timeout, manual sign-out) sets a
    // notice on SessionViewModel. Show it as a dialog so the user sees it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = context.read<SessionViewModel>();
      final notice = session.expiryNotice;
      if (notice != null) {
        session.consumeExpiryNotice();
        _showErrorDialog(
          icon: Icons.access_time_rounded,
          iconColor: OgeraColors.warning,
          title: 'Session expired',
          body: notice,
          action: 'Sign in again',
        );
      }
    });
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final viewModel = context.read<LoginViewModel>();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final session = await viewModel.signIn();
    if (!mounted) return;

    // signIn() returns null on any failure. The ViewModel holds the message.
    if (session == null) {
      final msg = viewModel.message;
      if (msg != null) {
        _showErrorDialog(
          icon: Icons.error_outline_rounded,
          iconColor: OgeraColors.danger,
          title: 'Sign in failed',
          body: msg,
          action: 'Try again',
        );
      }
      return;
    }

    await context.read<SessionViewModel>().adopt(session);
  }

  void _showForgotPasswordDialog() {
    _showErrorDialog(
      icon: Icons.lock_reset_rounded,
      iconColor: OgeraColors.forest,
      title: 'Forgot your password?',
      body: 'Ask your workspace administrator to reset your password.',
      action: 'Got it',
    );
  }

  /// Generic dialog used for errors, warnings, and informational messages.
  void _showErrorDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required String action,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        iconPadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        icon: Icon(icon, color: iconColor, size: 40),
        titlePadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        content: Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: OgeraColors.muted, height: 1.5, fontSize: 14.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: OgeraColors.ink,
              minimumSize: const Size(130, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      // White scaffold so the body below the hero blends seamlessly.
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Center(
            child: ConstrainedBox(
              // Caps the form width on tablets/large phones.
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Hero(topPad: topPad),
                  _Body(
                    formKey: _formKey,
                    identifierController: _identifierController,
                    passwordController: _passwordController,
                    passwordFocus: _passwordFocus,
                    viewModel: viewModel,
                    showMalayalam: _showMalayalam,
                    onToggleLang: () =>
                        setState(() => _showMalayalam = !_showMalayalam),
                    onSubmit: _submit,
                    onForgotPassword: _showForgotPasswordDialog,
                    onWhatsApp: () => Launchers.whatsapp(
                      context,
                      '9847012345',
                      countryCode: '+91',
                      message: 'Hi, I need help signing in to Ogera CRM.',
                    ),
                    bottomPad: bottomPad + keyboardInset,
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

// ─── Hero ────────────────────────────────────────────────────────────────────

/// Dark-green banner: Ogera symbol, Malayalam welcome, English tagline.
class _Hero extends StatelessWidget {
  const _Hero({required this.topPad});

  final double topPad;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPad + 28, 24, 40),
      color: OgeraColors.forest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo symbol on a white rounded tile
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Image.asset(
              'assets/images/ogera-symbol.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.water_drop_rounded,
                color: OgeraColors.forest,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Main headline
          const Text(
            'Namaskaram!\nWelcome to Ogera.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          // Malayalam tagline in bright accent green
          const Text(
            'ഒരു ലീഡും ഇനി മിസ്സാകില്ല.',
            style: TextStyle(
              color: OgeraColors.forestAccent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          // English tagline
          const Text(
            'Every lead, every follow-up, in one place.',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Body ────────────────────────────────────────────────────────────────────

/// White form section below the hero.
class _Body extends StatelessWidget {
  const _Body({
    required this.formKey,
    required this.identifierController,
    required this.passwordController,
    required this.passwordFocus,
    required this.viewModel,
    required this.showMalayalam,
    required this.onToggleLang,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onWhatsApp,
    required this.bottomPad,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final FocusNode passwordFocus;
  final LoginViewModel viewModel;
  final bool showMalayalam;
  final VoidCallback onToggleLang;
  final Future<void> Function() onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onWhatsApp;
  // Combined safe-area bottom + keyboard inset so content stays visible.
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(24, 28, 24, 28 + bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── "Ogera CRM" + language toggle ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ogera CRM',
                style: TextStyle(
                  color: OgeraColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              
            ],
          ),
          const SizedBox(height: 22),

          // ── "Welcome back!" ─────────────────────────────────────────────
          const Text(
            'Welcome back!',
            style: TextStyle(
              color: OgeraColors.ink,
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 18),

          // ── Form ─────────────────────────────────────────────────────────
          Form(
            key: formKey,
            autovalidateMode: viewModel.hasAttemptedSubmit
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Identifier field (mobile or email)
                const _FieldLabel('Mobile number or email'),
                const SizedBox(height: 7),
                TextFormField(
                  controller: identifierController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  enabled: !viewModel.isSubmitting,
                  style: const TextStyle(fontSize: 15, color: OgeraColors.ink),
                  decoration: _underlineDecoration(
                    hint: '98470 12345 or you@shop.com',
                  ),
                  validator: viewModel.validateEmail,
                  onChanged: viewModel.updateEmail,
                  onFieldSubmitted: (_) => passwordFocus.requestFocus(),
                ),
                const SizedBox(height: 22),

                // Password field
                const _FieldLabel('Password'),
                const SizedBox(height: 7),
                TextFormField(
                  controller: passwordController,
                  focusNode: passwordFocus,
                  obscureText: viewModel.obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  enabled: !viewModel.isSubmitting,
                  style: const TextStyle(fontSize: 15, color: OgeraColors.ink),
                  decoration: _underlineDecoration(
                    hint: 'Enter your password',
                    suffix: IconButton(
                      tooltip: viewModel.obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      icon: Icon(
                        viewModel.obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: OgeraColors.muted,
                      ),
                      onPressed: viewModel.togglePasswordVisibility,
                    ),
                  ),
                  validator: viewModel.validatePassword,
                  onChanged: viewModel.updatePassword,
                  onFieldSubmitted: (_) => onSubmit(),
                ),
                const SizedBox(height: 32),

                // Login button — black to match the design
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: OgeraColors.ink,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  onPressed: viewModel.isSubmitting ? null : onSubmit,
                  child: viewModel.isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Login'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── Footer links ─────────────────────────────────────────────────
          _FooterLink(
            prefix: 'Forgot password? ',
            label: 'Reset here',
            onTap: onForgotPassword,
          ),
          const SizedBox(height: 7),
          _FooterLink(
            prefix: 'Need help? ',
            label: 'Chat with us on WhatsApp',
            onTap: onWhatsApp,
          ),
        ],
      ),
    );
  }

  /// Bottom-border-only field style, matching the minimal design.
  static InputDecoration _underlineDecoration({
    required String hint,
    Widget? suffix,
  }) {
    const border = UnderlineInputBorder(
      borderSide: BorderSide(color: OgeraColors.line, width: 1.2),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFBBC5CE), fontSize: 14.5),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      enabledBorder: border,
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: OgeraColors.forest, width: 2),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: OgeraColors.danger, width: 1.5),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: OgeraColors.danger, width: 2),
      ),
      disabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: OgeraColors.line),
      ),
      filled: false,
      suffixIcon: suffix,
      isDense: true,
    );
  }
}

// ─── Small reusable widgets ───────────────────────────────────────────────────

/// Bold label above each form field.
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


/// A gray footer line with a bold, underlined, tappable portion.
///
/// Example: "Forgot password? **Reset here**"
class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.prefix,
    required this.label,
    required this.onTap,
  });

  final String prefix;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            prefix,
            style: const TextStyle(color: OgeraColors.muted, fontSize: 13.5),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              label,
              style: const TextStyle(
                color: OgeraColors.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: OgeraColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
