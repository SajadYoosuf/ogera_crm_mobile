import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_session.dart';
import '../theme/ogera_colors.dart';
import '../view_models/login_view_model.dart';
import '../view_models/session_view_model.dart';

/// Two apps behind one door.
///
/// The tab a user picks decides which experience they are entering, and it
/// travels to the API as `x-client-scope` so the server can refuse a mismatched
/// role. The colour of the hero changes with the tab so the two are never
/// confused at a glance: navy for Head, Ogera blue for Staff.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // A session that ended elsewhere in the app explains itself here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = context.read<SessionViewModel>();
      final notice = session.expiryNotice;
      if (notice != null) {
        context.read<LoginViewModel>().showNotice(notice);
        session.consumeExpiryNotice();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final viewModel = context.read<LoginViewModel>();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final session = await viewModel.signIn();
    if (session == null || !mounted) return;
    await context.read<SessionViewModel>().adopt(session);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();
    final scope = viewModel.scope;
    final accent = scope == LoginScope.head
        ? OgeraColors.ink
        : OgeraColors.blue;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: 28 + keyboardInset),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  _Hero(scope: scope, accent: accent),
                  Transform.translate(
                    offset: const Offset(0, -34),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _ScopeTabs(
                            scope: scope,
                            accent: accent,
                            onChanged: viewModel.isSubmitting
                                ? null
                                : viewModel.selectScope,
                          ),
                          const SizedBox(height: 16),
                          _LoginForm(
                            formKey: _formKey,
                            emailController: _emailController,
                            passwordController: _passwordController,
                            passwordFocus: _passwordFocus,
                            accent: accent,
                            onSubmit: _submit,
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Having trouble signing in? Contact your workspace administrator.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: OgeraColors.muted,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.scope, required this.accent});

  final LoginScope scope;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isHead = scope == LoginScope.head;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        28,
        MediaQuery.paddingOf(context).top + 30,
        28,
        58,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isHead
              ? const [OgeraColors.ink, OgeraColors.inkSoft]
              : const [OgeraColors.blueDeep, OgeraColors.blue],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset(
                  'assets/images/ogera-symbol.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.water_drop_rounded, color: accent, size: 24),
                ),
              ),
              const SizedBox(width: 13),
              const Text(
                'Ogera CRM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Column(
              key: ValueKey(scope),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHead ? 'Team oversight' : 'Field workspace',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isHead
                      ? 'Pipeline, sales, and live staff monitoring for admins and sales heads.'
                      : 'Your contacts, assigned follow-ups, and today’s route.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The role selector. It is a routing hint, not a security boundary — the
/// server verifies the role independently and answers `SCOPE_MISMATCH`.
class _ScopeTabs extends StatelessWidget {
  const _ScopeTabs({
    required this.scope,
    required this.accent,
    required this.onChanged,
  });

  final LoginScope scope;
  final Color accent;
  final ValueChanged<LoginScope>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: OgeraColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OgeraColors.line),
        boxShadow: OgeraColors.cardShadow,
      ),
      child: Row(
        children: [
          _tab(
            context,
            value: LoginScope.head,
            icon: Icons.insights_rounded,
            label: 'Head',
            caption: 'Admin · Sales Head',
          ),
          _tab(
            context,
            value: LoginScope.staff,
            icon: Icons.badge_outlined,
            label: 'Staff',
            caption: 'Sales Staff',
          ),
        ],
      ),
    );
  }

  Widget _tab(
    BuildContext context, {
    required LoginScope value,
    required IconData icon,
    required String label,
    required String caption,
  }) {
    final selected = scope == value;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: '$label sign in. $caption',
        child: GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? Colors.white : OgeraColors.muted,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : OgeraColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 11,
                    color: selected ? Colors.white70 : OgeraColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordFocus,
    required this.accent,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode passwordFocus;
  final Color accent;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: OgeraColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OgeraColors.line),
        boxShadow: OgeraColors.cardShadow,
      ),
      child: Form(
        key: formKey,
        autovalidateMode: viewModel.hasAttemptedSubmit
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sign in as ${viewModel.scope.label}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              enabled: !viewModel.isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Work email',
                prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
              ),
              validator: viewModel.validateEmail,
              onChanged: viewModel.updateEmail,
              onFieldSubmitted: (_) => passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: passwordController,
              focusNode: passwordFocus,
              obscureText: viewModel.obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              enabled: !viewModel.isSubmitting,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  tooltip: viewModel.obscurePassword
                      ? 'Show password'
                      : 'Hide password',
                  icon: Icon(
                    viewModel.obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                  onPressed: viewModel.togglePasswordVisibility,
                ),
              ),
              validator: viewModel.validatePassword,
              onChanged: viewModel.updatePassword,
              onFieldSubmitted: (_) => onSubmit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: viewModel.isSubmitting
                    ? null
                    : viewModel.requestPasswordHelp,
                child: const Text('Forgot password?'),
              ),
            ),
            if (viewModel.message != null) ...[
              const SizedBox(height: 4),
              _Message(
                message: viewModel.message!,
                isError: viewModel.hasError,
              ),
              const SizedBox(height: 14),
            ] else
              const SizedBox(height: 6),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent),
              onPressed: viewModel.isSubmitting ? null : onSubmit,
              child: viewModel.isSubmitting
                  ? const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text('Sign in as ${viewModel.scope.label}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? OgeraColors.danger : OgeraColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, height: 1.4, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
