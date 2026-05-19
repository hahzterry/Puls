import 'package:flutter/material.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';

class WebTickerStrip extends StatefulWidget {
  const WebTickerStrip({super.key});

  @override
  State<WebTickerStrip> createState() => _WebTickerStripState();
}

class _WebTickerStripState extends State<WebTickerStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final markets = appState.feedMarkets.take(12).toList();
    if (markets.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 44,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return CustomPaint(
            painter: _TickerPainter(
              markets: markets,
              progress: _anim.value,
              textColor: t.text,
              mutedColor: t.textSubtle,
            ),
          );
        },
      ),
    );
  }
}

class _TickerPainter extends CustomPainter {
  _TickerPainter({
    required this.markets,
    required this.progress,
    required this.textColor,
    required this.mutedColor,
  });

  final List markets;
  final double progress;
  final Color textColor;
  final Color mutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    const itemWidth = 220.0;
    final totalWidth = itemWidth * markets.length;
    final offset = -(progress * totalWidth);

    for (int pass = 0; pass < 2; pass++) {
      final passOffset = offset + pass * totalWidth;
      for (int i = 0; i < markets.length; i++) {
        final x = passOffset + i * itemWidth;
        if (x > size.width || x + itemWidth < 0) continue;
        _drawItem(canvas, size, markets[i], x);
      }
    }
  }

  void _drawItem(Canvas canvas, Size size, dynamic market, double x) {
    final isUp = market.trendIsPositive as bool;
    final trendColor = isUp ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final yesPrice = (market.yesPrice as double);
    final trend = (market.trend as double);

    // Question (truncated)
    final question = (market.question as String);
    final shortQ = question.length > 28 ? '${question.substring(0, 28)}…' : question;

    final namePainter = TextPainter(
      text: TextSpan(
        text: shortQ,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 140);

    final pricePainter = TextPainter(
      text: TextSpan(
        text: 'YES ${(yesPrice * 100).toStringAsFixed(0)}¢',
        style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final trendPainter = TextPainter(
      text: TextSpan(
        text: '${isUp ? '↑' : '↓'} ${(trend * 100).abs().toStringAsFixed(1)}%',
        style: TextStyle(color: trendColor, fontSize: 10, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final y = (size.height - namePainter.height) / 2;
    namePainter.paint(canvas, Offset(x + 12, y));
    pricePainter.paint(canvas, Offset(x + 12 + namePainter.width + 8, y));
    trendPainter.paint(canvas, Offset(x + 12 + namePainter.width + 8 + pricePainter.width + 6, y));

    // Separator dot
    final dotPaint = Paint()..color = mutedColor.withValues(alpha: 0.3);
    canvas.drawCircle(Offset(x + 220 - 6, size.height / 2), 2, dotPaint);
  }

  @override
  bool shouldRepaint(_TickerPainter old) => old.progress != progress;
}
