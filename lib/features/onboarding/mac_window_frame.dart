import 'package:flutter/material.dart';

/// A macOS-style window chrome — dark translucent title bar with traffic lights,
/// soft rounded corners, and a subtle inner border.
class MacWindowFrame extends StatelessWidget {
  const MacWindowFrame({required this.title, required this.child, super.key});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              blurRadius: 64,
              offset: const Offset(0, 24),
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
            ),
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, 2),
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: Column(children: [
          // ── Title bar ─────────────────────────────────────────────────
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1B1B1F)
                  : const Color(0xFFE8E8ED),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.07),
                ),
              ),
            ),
            child: Row(children: [
              const SizedBox(width: 14),
              // Traffic lights — authentic macOS colors
              _TrafficLight.dot(const Color(0xFFFF5F57)), // close  — red
              const SizedBox(width: 7),
              _TrafficLight.dot(const Color(0xFFFEBC2E)), // min    — amber
              const SizedBox(width: 7),
              _TrafficLight.dot(const Color(0xFF28C840)), // max    — green
              const SizedBox(width: 14),
              // Center: title
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.55)
                      : Colors.black.withValues(alpha: 0.55),
                ),
              ),
              const Spacer(flex: 2),
            ]),
          ),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

/// A single macOS traffic light dot with authentic radius and subtle shadow.
class _TrafficLight extends StatelessWidget {
  const _TrafficLight.dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 3),
        ],
      ),
    );
  }
}

Widget liveAppPreview({required Widget screen, double width = 390, double height = 844}) {
  return FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(
      width: width,
      height: height,
      child: MacWindowFrame(title: 'Puls', child: screen),
    ),
  );
}
