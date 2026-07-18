import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/puls_snack.dart';
import '../../agent/widgets/decision_log_panel.dart';
import '../../agent/widgets/swarm_visualizer.dart';
import '../widgets/terminal_event_binder.dart';

/// Cyberpunk high-tech grid background with neon color blobs
class _TerminalGridBackground extends StatefulWidget {
  const _TerminalGridBackground({required this.child});
  final Widget child;

  @override
  State<_TerminalGridBackground> createState() => _TerminalGridBackgroundState();
}

class _TerminalGridBackgroundState extends State<_TerminalGridBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      if (_ctrl.isAnimating) _ctrl.stop();
    } else {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Canvas Dark Navy Base
        Positioned.fill(
          child: Container(
            color: const Color(0xFF060913),
          ),
        ),
        // Animated gradient blobs
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final progress = _ctrl.value * 2 * math.pi;
            final offset1 = Offset(
              math.sin(progress) * 45,
              math.cos(progress * 0.8) * 35,
            );
            final offset2 = Offset(
              math.cos(progress * 0.9) * 55,
              math.sin(progress * 0.7) * 45,
            );
            return Stack(
              children: [
                // Neon radial gradient blob 1 (top-left)
                Positioned(
                  top: -150 + offset1.dy,
                  left: -150 + offset1.dx,
                  child: Container(
                    width: 450,
                    height: 450,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF2DD4BF).withValues(alpha: 0.12),
                          const Color(0xFF2DD4BF).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Neon radial gradient blob 2 (bottom-right)
                Positioned(
                  bottom: -200 + offset2.dy,
                  right: -100 + offset2.dx,
                  child: Container(
                    width: 550,
                    height: 550,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFEC4899).withValues(alpha: 0.1),
                          const Color(0xFFEC4899).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        // High-tech grid pattern
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2E3B5D).withValues(alpha: 0.07)
      ..strokeWidth = 0.8;

    const double step = 32.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Mini Sparkline Graph Custom Painter
class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.points, this.color);
  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final stepX = size.width / (points.length - 1);
    
    double minY = points[0];
    double maxY = points[0];
    for (var p in points) {
      if (p < minY) minY = p;
      if (p > maxY) maxY = p;
    }
    final rangeY = (maxY - minY == 0) ? 1.0 : (maxY - minY);

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - ((points[i] - minY) / rangeY) * size.height * 0.8 - size.height * 0.1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}

/// AI Bloomberg Terminal — a dense, 3-column trading interface for the
/// hackathon demo. Left: market list. Center: arena/betting. Right: live
/// agent decision stream.
class MarketTerminalScreen extends StatefulWidget {
  const MarketTerminalScreen({super.key});

  @override
  State<MarketTerminalScreen> createState() => _MarketTerminalScreenState();
}

class _MarketTerminalScreenState extends State<MarketTerminalScreen> {
  int _selectedMarketIdx = 0;

  static const _markets = [
    _Market(slug: 'btc-100k', question: 'Will BTC hit \$100k by August?', yesPrice: 0.67, volume: 124000),
    _Market(slug: 'eth-flip', question: 'Will ETH flip its all-time high?', yesPrice: 0.31, volume: 88000),
    _Market(slug: 'us-recession', question: 'US recession declared in 2026?', yesPrice: 0.18, volume: 210000),
    _Market(slug: 'fed-cut-july', question: 'Fed cuts rates in July?', yesPrice: 0.74, volume: 156000),
    _Market(slug: 'arc-tvl-1b', question: 'Arc TVL exceeds \$1B by Q4?', yesPrice: 0.42, volume: 67000),
    _Market(slug: 'sol-300', question: 'SOL above \$300 this month?', yesPrice: 0.55, volume: 92000),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    // TerminalEventBinder subscribes to the WebSocket event stream and
    // dispatches to SwarmVisualizer + DecisionLogPanel + CameraShake. Wrap
    // it AROUND CameraShake so triggerCameraShake(context) finds the shake
    // state, and inside Scaffold so it finds the viz/log panel descendants.
    return TerminalEventBinder(
      child: CameraShake(
        child: Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: Column(
              children: [
                _TerminalHeader(),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 1100;
                      if (wide) return _threeColumn(context, c);
                      return _singleColumn(context, c);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Wide: 3-column Bloomberg layout ────────────────────────────────────
  Widget _threeColumn(BuildContext context, BoxConstraints c) {
    final leftW = (c.maxWidth * 0.24).clamp(260.0, 340.0);
    final rightW = (c.maxWidth * 0.26).clamp(300.0, 380.0);
    final centerW = c.maxWidth - leftW - rightW - 24; // 24px of gutters

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Left column: market list ──────────────────────────────────
        SizedBox(
          width: leftW,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 8, bottom: 12),
            child: GlassCard(
              padding: const EdgeInsets.all(0),
              child: _MarketList(
                markets: _markets,
                selectedIdx: _selectedMarketIdx,
                onSelect: (i) => setState(() => _selectedMarketIdx = i),
              ),
            ),
          ),
        ),
        // ── Center column: arena / betting ─────────────────────────────
        SizedBox(
          width: centerW,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              child: _ArenaPanel(market: _markets[_selectedMarketIdx]),
            ),
          ),
        ),
        // ── Right column: decision log + swarm viz ─────────────────────
        SizedBox(
          width: rightW,
          child: Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 12),
            child: Column(
              children: [
                // Swarm mini-viz across the top of the right panel.
                SizedBox(
                  height: 160,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: const SwarmVisualizer(
                      background: Colors.transparent,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Expanded(child: DecisionLogPanel()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Narrow fallback: single column ─────────────────────────────────────
  Widget _singleColumn(BuildContext context, BoxConstraints c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: GlassCard(
              padding: EdgeInsets.zero,
              child: _MarketList(
                markets: _markets,
                selectedIdx: _selectedMarketIdx,
                onSelect: (i) => setState(() => _selectedMarketIdx = i),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: _ArenaPanel(market: _markets[_selectedMarketIdx]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: const DecisionLogPanel(),
          ),
        ],
      ),
    );
  }
}

// ── Terminal header ───────────────────────────────────────────────────────
class _TerminalHeader extends StatefulWidget {
  const _TerminalHeader();

  @override
  State<_TerminalHeader> createState() => _TerminalHeaderState();
}

class _TerminalHeaderState extends State<_TerminalHeader> {
  late DateTime _now;
  late int _block;
  int _gas = 12;
  int _tps = 148;
  Timer? _timer;
  bool _blink = true;
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _block = 12847190 + _rand.nextInt(1000);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
          _blink = !_blink;
          if (_rand.nextDouble() < 0.15) {
            _block += 1;
          }
          if (_rand.nextDouble() < 0.3) {
            _gas = (_gas + _rand.nextInt(3) - 1).clamp(8, 28);
          }
          if (_rand.nextDouble() < 0.4) {
            _tps = (_tps + _rand.nextInt(11) - 5).clamp(110, 185);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal_rounded, size: 20, color: t.brand),
          const SizedBox(width: 10),
          const AnimatedGradientText(
            'PULS // TERMINAL',
            style: TextStyle(
              fontFamily: PulsColors.fontMono,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(width: 20),
          // High-tech Clock
          Text(
            _formatTime(_now),
            style: TextStyle(
              color: t.textSubtle,
              fontFamily: PulsColors.fontMono,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // High-tech network statistics
          _StatusChip(label: 'BLOCK #$_block', color: t.textSubtle),
          const SizedBox(width: 8),
          _StatusChip(label: 'GAS: $_gas GWEI', color: t.yes),
          const SizedBox(width: 8),
          _StatusChip(label: 'TPS: $_tps/s', color: t.brand),
          const SizedBox(width: 8),
          // Live pulse badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: PulsColors.red.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: PulsColors.red.withValues(alpha: 0.4), width: 0.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _blink ? PulsColors.red : PulsColors.red.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: PulsColors.red,
                    fontFamily: PulsColors.fontMono,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Icon(Icons.close_rounded, size: 20, color: t.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: PulsColors.fontMono,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ── Left: Market list ─────────────────────────────────────────────────────
class _MarketList extends StatelessWidget {
  const _MarketList({
    required this.markets,
    required this.selectedIdx,
    required this.onSelect,
  });

  final List<_Market> markets;
  final int selectedIdx;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Column header
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: t.surfaceRaised.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: Row(
            children: [
              Text(
                'PREDICTION MARKETS',
                style: TextStyle(
                  color: t.textMuted,
                  fontFamily: PulsColors.fontMono,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                '${markets.length}',
                style: TextStyle(
                  color: t.brand,
                  fontFamily: PulsColors.fontMono,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: markets.length,
            itemBuilder: (context, i) {
              final m = markets[i];
              final selected = i == selectedIdx;
              return _MarketRow(
                market: m,
                selected: selected,
                onTap: () => onSelect(i),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MarketRow extends StatefulWidget {
  const _MarketRow({
    required this.market,
    required this.selected,
    required this.onTap,
  });

  final _Market market;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_MarketRow> createState() => _MarketRowState();
}

class _MarketRowState extends State<_MarketRow> {
  bool _hovered = false;
  late List<double> _sparkPoints;

  @override
  void initState() {
    super.initState();
    // Pseudo-random chart points walk based on slug question hash
    final rand = math.Random(widget.market.slug.hashCode);
    double cur = widget.market.yesPrice;
    _sparkPoints = List.generate(12, (index) {
      cur = (cur + (rand.nextDouble() * 0.16 - 0.08)).clamp(0.02, 0.98);
      return cur;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final yesPct = (widget.market.yesPrice * 100).round();
    final rowAccentColor = yesPct >= 50 ? t.yes : t.no;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.selected
                ? t.brand.withValues(alpha: 0.1)
                : _hovered
                    ? t.surfaceRaised.withValues(alpha: 0.4)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected
                  ? t.brand.withValues(alpha: 0.4)
                  : _hovered
                      ? t.border.withValues(alpha: 0.4)
                      : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Active left indicator bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3.5,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? t.brand
                      : _hovered
                          ? t.brand.withValues(alpha: 0.3)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: widget.selected
                      ? [
                          BoxShadow(
                            color: t.brand.withValues(alpha: 0.6),
                            blurRadius: 4,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              // Question & Volume Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.market.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.selected ? t.text : t.textMuted,
                        fontSize: 12,
                        fontWeight: widget.selected ? FontWeight.bold : FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${widget.market.volume > 1000 ? '${(widget.market.volume / 1000).toStringAsFixed(0)}k' : widget.market.volume.toStringAsFixed(0)} vol',
                          style: TextStyle(
                            color: t.textSubtle,
                            fontFamily: PulsColors.fontMono,
                            fontSize: 9,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Mini Sparkline Graph
                        SizedBox(
                          width: 48,
                          height: 14,
                          child: CustomPaint(
                            painter: _SparklinePainter(_sparkPoints, rowAccentColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Probability Badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? rowAccentColor.withValues(alpha: 0.25)
                      : rowAccentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: widget.selected
                      ? Border.all(color: rowAccentColor, width: 0.8)
                      : null,
                ),
                child: Text(
                  '$yesPct%',
                  style: TextStyle(
                    color: rowAccentColor,
                    fontFamily: PulsColors.fontMono,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Center: Arena / betting panel ─────────────────────────────────────────
class _ArenaPanel extends StatefulWidget {
  const _ArenaPanel({required this.market});
  final _Market market;

  @override
  State<_ArenaPanel> createState() => _ArenaPanelState();
}

class _ArenaPanelState extends State<_ArenaPanel> with SingleTickerProviderStateMixin {
  bool _isYesSelected = true;
  double _stake = 10.0;
  bool _placeHovered = false;
  bool _placePressed = false;
  late AnimationController _btnGlowController;

  @override
  void initState() {
    super.initState();
    _btnGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _btnGlowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final yesPctVal = widget.market.yesPrice;
    
    // Computed values
    final currentPrice = _isYesSelected ? widget.market.yesPrice : (1.0 - widget.market.yesPrice);
    final shares = _stake / currentPrice;
    final profit = shares - _stake;
    final roi = (profit / _stake) * 100;
    
    final activeColor = _isYesSelected ? t.yes : t.no;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title Question
        Text(
          widget.market.question,
          style: TextStyle(
            color: t.text,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            height: 1.25,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Pill(label: widget.market.slug.toUpperCase(), color: t.textMuted),
            const SizedBox(width: 8),
            _Pill(label: 'ARC-TESTNET', color: t.yes),
            const Spacer(),
            Text(
              '\$${(widget.market.volume / 1000).toStringAsFixed(0)}k vol',
              style: TextStyle(
                color: t.textSubtle,
                fontFamily: PulsColors.fontMono,
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Probability Bar (Tween Animated)
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.5, end: yesPctVal),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, animVal, child) {
            final yPct = (animVal * 100).round();
            final nPct = 100 - yPct;
            return Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 12,
                    child: Row(
                      children: [
                        Expanded(
                          flex: yPct,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            color: t.yes,
                          ),
                        ),
                        Expanded(
                          flex: nPct,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            color: t.no,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: t.yes, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text(
                          'YES $yPct¢',
                          style: TextStyle(
                            color: t.yes,
                            fontFamily: PulsColors.fontMono,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'NO $nPct¢',
                          style: TextStyle(
                            color: t.no,
                            fontFamily: PulsColors.fontMono,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: t.no, shape: BoxShape.circle)),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),

        // Tabs to Choose YES/NO
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isYesSelected = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isYesSelected ? t.yes.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isYesSelected ? t.yes : t.border,
                      width: _isYesSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'BET YES',
                      style: TextStyle(
                        color: _isYesSelected ? t.yes : t.textSubtle,
                        fontFamily: PulsColors.fontMono,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isYesSelected = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 48,
                  decoration: BoxDecoration(
                    color: !_isYesSelected ? t.no.withValues(alpha: 0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: !_isYesSelected ? t.no : t.border,
                      width: !_isYesSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'BET NO',
                      style: TextStyle(
                        color: !_isYesSelected ? t.no : t.textSubtle,
                        fontFamily: PulsColors.fontMono,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // STAKE SECTION
        Text(
          'STAKE AMOUNT',
          style: TextStyle(
            color: t.textMuted,
            fontFamily: PulsColors.fontMono,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),

        // Interactive Stake Display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              Text(
                'USDC',
                style: TextStyle(
                  color: t.textSubtle,
                  fontFamily: PulsColors.fontMono,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _stake.toStringAsFixed(2),
                  style: TextStyle(
                    color: t.text,
                    fontFamily: PulsColors.fontMono,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '≈ ${shares.toStringAsFixed(1)} SHARES',
                  style: TextStyle(
                    color: activeColor,
                    fontFamily: PulsColors.fontMono,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Presets List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [5.0, 10.0, 50.0, 100.0, 500.0].map((amt) {
            return _PresetChip(
              amount: amt,
              selected: _stake == amt,
              onTap: () => setState(() => _stake = amt),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // ROI Calculator Display
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surfaceRaised.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.border.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EST. NET PROFIT',
                style: TextStyle(color: t.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Text(
                    '+\$${profit.toStringAsFixed(2)}',
                    style: TextStyle(color: t.yes, fontFamily: PulsColors.fontMono, fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${roi.toStringAsFixed(1)}% ROI)',
                    style: TextStyle(color: t.yes.withValues(alpha: 0.8), fontFamily: PulsColors.fontMono, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // EXECUTE TX BUTTON
        MouseRegion(
          onEnter: (_) => setState(() => _placeHovered = true),
          onExit: (_) => setState(() => _placeHovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _placePressed = true),
            onTapUp: (_) => setState(() => _placePressed = false),
            onTapCancel: () => setState(() => _placePressed = false),
            onTap: () {
              triggerCameraShake(context, intensity: 8);
              PulsSnack.success(
                context,
                'Order placed successfully: $_stake USDC on ${_isYesSelected ? 'YES' : 'NO'} via ARC Chain!',
              );
            },
            child: AnimatedBuilder(
              animation: _btnGlowController,
              builder: (context, child) {
                final glow = _btnGlowController.value;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 52,
                  transform: Matrix4.identity()..scale(_placePressed ? 0.98 : _placeHovered ? 1.01 : 1.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        activeColor,
                        activeColor.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.3 + (glow * 0.2)),
                        blurRadius: 10 + (glow * 8),
                        spreadRadius: 1 + (glow * 2),
                      )
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'EXECUTE TRANSACTION',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: PulsColors.fontMono,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const Spacer(),
        // Commentary Footer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.smart_toy_rounded, size: 16, color: t.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vega ⚡ went YES · \$2.50 · "momentum is breaking out, pressing this hard"',
                  style: TextStyle(
                    color: t.textMuted,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.amount,
    required this.selected,
    required this.onTap,
  });
  final double amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? t.brand.withValues(alpha: 0.2) : t.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? t.brand : t.border,
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: t.brand.withValues(alpha: 0.3),
                    blurRadius: 8,
                  )
                ]
              : null,
        ),
        child: Text(
          '\$${amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: selected ? t.text : t.textMuted,
            fontFamily: PulsColors.fontMono,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: PulsColors.fontMono,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Market data model ─────────────────────────────────────────────────────
class _Market {
  const _Market({
    required this.slug,
    required this.question,
    required this.yesPrice,
    required this.volume,
  });

  final String slug;
  final String question;
  final double yesPrice; // 0..1
  final double volume; // USDC
}
