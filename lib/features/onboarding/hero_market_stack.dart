import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../feed/feed_screen.dart';
import '../home/web_iframe.dart';
import '../market/screens/market_terminal_screen.dart';
import 'mac_window_frame.dart';

/// A floating, tilted stack of REAL live markets — the hero visual.
/// Pulls from the backend; falls back to a static sample so the layout
/// never renders empty.
class HeroMarketStack extends StatefulWidget {
  const HeroMarketStack({super.key, this.compact = false, this.onTapCard});
  final bool compact;
  final VoidCallback? onTapCard;

  @override
  State<HeroMarketStack> createState() => _HeroMarketStackState();
}

class _HeroMarketStackState extends State<HeroMarketStack>
    with SingleTickerProviderStateMixin {
  Offset _tilt = Offset.zero;
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honor reduce-motion: hold the floating cards still.
    if (context.reduceMotion) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    final w = compact ? 400.0 : 640.0;
    final h = compact ? 300.0 : 440.0;
    final totalW = w + 70;
    final reduce = context.reduceMotion;

    final Widget stack = SizedBox(
      width: totalW,
      height: h,
      child: AnimatedBuilder(
        animation: _float,
        builder: (context, _) {
          final t = _float.value * 2 * math.pi;
          return Transform.rotate(
            angle: -0.018,
            child: Transform.translate(
              offset: Offset(0, 8 * math.sin(t)),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  liveAppPreview(
                    // On web show the LIVE external terminal (terminal.pulsmarket.tech)
                    // in a real iframe; on native fall back to the in-app preview.
                    screen: buildWebIframe('https://terminal.pulsmarket.tech') ??
                        const MarketTerminalScreen(),
                    width: 1024,
                    height: 700,
                  ),
                  // Floating "LIVE" badge — signals this is the real terminal.
                  Positioned(
                    top: -14,
                    right: 4,
                    child: _LiveBadge(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (reduce) return stack;

    // Subtle 3D tilt toward the cursor for a tactile, premium feel.
    return MouseRegion(
      onHover: (e) => setState(() => _tilt = Offset(
            (e.localPosition.dx / totalW - 0.5) * 2,
            (e.localPosition.dy / h - 0.5) * 2,
          )),
      onExit: (_) => setState(() => _tilt = Offset.zero),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(-_tilt.dy * 0.10)
          ..rotateY(_tilt.dx * 0.10),
        child: stack,
      ),
    );
  }
}

/// A small frosted "LIVE" chip that floats over the hero terminal window.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF121829) : Colors.white)
            .withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE TERMINAL',
            style: TextStyle(
              color: t.text,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
