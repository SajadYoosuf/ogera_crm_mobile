import 'package:flutter/material.dart';

/// The Ogera identity palette, shared with the CRM web app.
class OgeraColors {
  const OgeraColors._();

  static const ink = Color(0xFF0B2942);
  static const blue = Color(0xFF126BB0);
  static const canvas = Color(0xFFF1F5F7);
  static const line = Color(0xFFD6E0E6);
  static const muted = Color(0xFF667A8C);

  static const surface = Color(0xFFFFFFFF);
  static const inkSoft = Color(0xFF13375A);
  static const blueSoft = Color(0xFFE7F1F9);
  static const blueDeep = Color(0xFF0E568C);

  /// Login screen hero background — deep forest green matching the brand design.
  static const forest = Color(0xFF1B3828);
  /// Bright accent used for the Malayalam tagline text on the forest background.
  static const forestAccent = Color(0xFF3DD68C);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);
  static const danger = Color(0xFFDC2626);
  static const info = Color(0xFF0284C7);

  static const successSoft = Color(0xFFE7F6EC);
  static const warningSoft = Color(0xFFFDF3E4);
  static const dangerSoft = Color(0xFFFCEAEA);

  /// Card shadow used across every elevated surface in the app.
  static const cardShadow = [
    BoxShadow(color: Color(0x0F0B2942), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static const lowShadow = [
    BoxShadow(color: Color(0x0A0B2942), blurRadius: 10, offset: Offset(0, 3)),
  ];
}

/// Layout constants. Touch targets never fall below [OgeraSpacing.touchTarget].
class OgeraSpacing {
  const OgeraSpacing._();

  static const screen = 16.0;
  static const gap = 12.0;
  static const tight = 8.0;
  static const cardRadius = 16.0;
  static const chipRadius = 8.0;
  static const fieldRadius = 12.0;
  static const touchTarget = 44.0;
}
