import 'package:flutter/material.dart';

/// Depth treatment for YES/NO buy buttons: the tinted fill carries the side,
/// a hairline in the side colour defines the edge, and one soft tinted shadow
/// lifts it off the card. No white catch-light — the surfaces underneath are
/// solid brand colours, not glass, so a fake highlight only muddies them.
BoxDecoration sideButtonDecoration({
  required Color bg,
  required Color fg,
  required bool isDark,
  double radius = 14,
}) {
  return BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: fg.withValues(alpha: isDark ? 0.34 : 0.24)),
    boxShadow: [
      BoxShadow(
        color: fg.withValues(alpha: isDark ? 0.16 : 0.12),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ],
  );
}
