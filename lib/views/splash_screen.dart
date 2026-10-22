import 'package:flutter/material.dart';

import '../theme/ogera_colors.dart';

/// Shown while the stored session is being restored (typically a few hundred
/// milliseconds). The channel badges communicate what the CRM tracks — leads
/// from Facebook, WhatsApp, Google, YouTube, and offline walk-ins — so even
/// a brief view is meaningful rather than blank.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: OgeraColors.ink,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Logo(),
                SizedBox(height: OgeraSpacing.gap),
                _AppName(),
                SizedBox(height: 24),
                _ChannelBadges(),
                SizedBox(height: OgeraSpacing.gap),
                _Tagline(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              color: OgeraColors.blue,
              minHeight: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Image.asset(
        'assets/images/ogera-symbol.png',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(
          Icons.water_drop_rounded,
          color: OgeraColors.blue,
          size: 32,
        ),
      ),
    );
  }
}

class _AppName extends StatelessWidget {
  const _AppName();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Ogera CRM',
      style: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    );
  }
}

/// Five rounded badges, one per lead source.
/// Inputs: none — purely presentational.
/// Why: gives the splash meaning at a glance; every badge is a channel whose
/// leads the CRM promises to capture.
class _ChannelBadges extends StatelessWidget {
  const _ChannelBadges();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Facebook
        _Badge(
          bg: Color(0xFF1877F2),
          child: Text(
            'f',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
        SizedBox(width: OgeraSpacing.tight),
        // WhatsApp
        _Badge(
          bg: Color(0xFF25D366),
          child: Icon(Icons.phone_in_talk, color: Colors.white, size: 22),
        ),
        SizedBox(width: OgeraSpacing.tight),
        // Google
        _Badge(
          bg: Colors.white,
          child: Icon(Icons.search, color: Color(0xFF4285F4), size: 22),
        ),
        SizedBox(width: OgeraSpacing.tight),
        // YouTube
        _Badge(
          bg: Color(0xFFFF0000),
          child: Icon(Icons.play_arrow, color: Colors.white, size: 24),
        ),
        SizedBox(width: OgeraSpacing.tight),
        // Offline / walk-in
        _Badge(
          bg: OgeraColors.muted,
          child: Icon(Icons.store, color: Colors.white, size: 22),
        ),
      ],
    );
  }
}

/// A single 44×44 rounded badge used for channel icons.
class _Badge extends StatelessWidget {
  const _Badge({required this.bg, required this.child});

  final Color bg;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'No lead goes out.',
      style: TextStyle(
        color: OgeraColors.muted,
        fontSize: 13,
        letterSpacing: 0.1,
      ),
    );
  }
}
