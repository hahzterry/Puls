import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Market depth chart вЂ” visualizes YES/NO liquidity at price levels.
/// Reads on-chain pool sizes from the market's contract via the backend.
class MarketDepthChart extends StatefulWidget {
  const MarketDepthChart(
      {super.key, required this.yesPrice, this.yesPool = 0, this.noPool = 0});
  final double yesPrice;
  final double yesPool;
  final double noPool;

  @override
  State<MarketDepthChart> createState() => _MarketDepthChartState();
}

class _MarketDepthChartState extends State<MarketDepthChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(MarketDepthChart old) {
    super.didUpdateWidget(old);
    if (old.yesPrice != widget.yesPrice) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PulsColors.dark50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PulsColors.dark300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('MARKET DEPTH',
                  style: TextStyle(
                      color: PulsColors.dark400,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: PulsColors.fontMono,
                      letterSpacing: 1.5)),
              const Spacer(),
              Text('${(widget.yesPrice * 100).round()}Вў YES',
                  style: const TextStyle(
                      color: PulsColors.brandMint,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: PulsColors.fontMono)),
              const SizedBox(width: 8),
              Text('${((1 - widget.yesPrice) * 100).round()}Вў NO',
                  style: const TextStyle(
                      color: PulsColors.brandPink,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: PulsColors.fontMono)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => CustomPaint(
                  painter: _DepthPainter(widget.yesPrice, widget.yesPool,
                      widget.noPool, _ctrl.value),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _poolStat('YES LIQ', '\$${widget.yesPool.toStringAsFixed(0)}',
                  PulsColors.brandMint),
              _poolStat('NO LIQ', '\$${widget.noPool.toStringAsFixed(0)}',
                  PulsColors.brandPink),
              _poolStat(
                  'TOTAL',
                  '\$${(widget.yesPool + widget.noPool).toStringAsFixed(0)}',
                  PulsColors.dark900),
            ],
          ),
        ],
      ),
    );
  }

  Widget _poolStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: PulsColors.dark400,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                fontFamily: PulsColors.fontMono)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFamily: PulsColors.fontMono)),
      ],
    );
  }
}

class _DepthPainter extends CustomPainter {
  _DepthPainter(this.yesPrice, this.yesPool, this.noPool, this.anim);
  final double yesPrice;
  final double yesPool;
  final double noPool;
  final double anim;

  @override
  void paint(Canvas canvas, Size size) {
    // Background grid
    final gridPaint = Paint()
      ..color = PulsColors.dark300
      ..strokeWidth = 0.5;
    for (var i = 1; i < 10; i++) {
      final x = size.width * i / 10;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final midX = size.width * yesPrice;
    final h = size.height;

    // YES area (left of midpoint, mint)
    final yesPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.3)
      ..quadraticBezierTo(midX * 0.3, h * 0.15, midX, h * 0.05 * anim)
      ..lineTo(midX, h)
      ..close();
    final yesPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          PulsColors.brandMint.withValues(alpha: 0.3 * anim),
          PulsColors.brandMint.withValues(alpha: 0.05)
        ],
      ).createShader(Rect.fromLTWH(0, 0, midX, h));
    canvas.drawPath(yesPath, yesPaint);

    // NO area (right of midpoint, pink)
    final noPath = Path()
      ..moveTo(midX, h)
      ..lineTo(midX, h * 0.05 * anim)
      ..quadraticBezierTo(
          midX + (size.width - midX) * 0.7, h * 0.15, size.width, h * 0.3)
      ..lineTo(size.width, h)
      ..close();
    final noPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          PulsColors.brandPink.withValues(alpha: 0.3 * anim),
          PulsColors.brandPink.withValues(alpha: 0.05)
        ],
      ).createShader(Rect.fromLTWH(midX, 0, size.width - midX, h));
    canvas.drawPath(noPath, noPaint);

    // Midpoint line
    final midPaint = Paint()
      ..color = PulsColors.dark900.withValues(alpha: 0.4 * anim)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(midX, 0), Offset(midX, h), midPaint);

    // Price labels
    final labelStyle = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 10; i += 2) {
      final price = i * 10;
      labelStyle.text = TextSpan(
        text: '${price}Вў',
        style: const TextStyle(
            color: PulsColors.dark400, fontSize: 8, fontFamily: 'DM Sans'),
      );
      labelStyle.layout();
      labelStyle.paint(canvas, Offset(size.width * i / 10 - 8, h + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _DepthPainter old) =>
      old.yesPrice != yesPrice || old.anim != anim;
}
