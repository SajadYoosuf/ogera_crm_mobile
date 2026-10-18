import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/session_view_model.dart';
import 'login_screen.dart';
import 'shell_screen.dart';
import 'splash_screen.dart';

/// The only place that decides which experience is on screen.
///
/// A revoked session drops straight back to login from wherever the user was;
/// both states are expressed here as a single switch on [SessionStatus].
class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<SessionViewModel, SessionStatus>(
      (session) => session.status,
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: switch (status) {
        SessionStatus.restoring => const SplashScreen(key: ValueKey('splash')),
        SessionStatus.signedOut => const LoginScreen(key: ValueKey('login')),
        SessionStatus.ready => const ShellScreen(key: ValueKey('shell')),
      },
    );
  }
}
