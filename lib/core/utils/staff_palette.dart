import 'package:flutter/material.dart';

/// Twelve colours chosen to stay distinct against an OpenStreetMap basemap and
/// to remain separable for the common colour-vision deficiencies.
///
/// A staff member's colour is derived from their user id, so it is identical on
/// every device and survives reinstalls — the head map depends on that
/// stability to make multi-staff monitoring readable.
class StaffPalette {
  const StaffPalette._();

  static const colors = <Color>[
    Color(0xFFE11D48),
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFEA580C),
    Color(0xFF9333EA),
    Color(0xFF0891B2),
    Color(0xFFCA8A04),
    Color(0xFFDB2777),
    Color(0xFF059669),
    Color(0xFF4F46E5),
    Color(0xFFB45309),
    Color(0xFF0D9488),
  ];

  static int indexFor(int userId) => userId.abs() % colors.length;

  static Color colorFor(int userId) => colors[indexFor(userId)];

  /// The server may send its own `colorIndex`; honouring it keeps web and
  /// mobile in step if the assignment rule ever changes server-side.
  static Color fromIndex(int? index, int fallbackUserId) {
    if (index == null) return colorFor(fallbackUserId);
    return colors[index.abs() % colors.length];
  }
}
