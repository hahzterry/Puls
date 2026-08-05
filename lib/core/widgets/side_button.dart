import 'package:flutter/material.dart';

/// Depth treatment for YES/NO buy buttons: a soft tinted glow + a glass
/// catch-light on the top edge instead of a hard outline ring. The colored
/// fill carries the side; the glow separates it from the card beneath.
BoxDecoration sideButtonDecoration({
  required Color bg,
  required Color fg,
  required bool isDark,
  double radius = 14,
}) {
  return BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: fg.withValues(alpha: isDark ? 0.18 : 0.14),
        blurRadius: 12,
        offset: const Offset(0, 5),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: isDark ? 0.07 : 0.55),
        blurRadius: 0,
        spreadRadius: -1,
        offset: const Offset(0, 1),
      ),
    ],
  );
}
