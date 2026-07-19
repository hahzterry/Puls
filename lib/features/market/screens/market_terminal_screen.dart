import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../core/widgets/puls_avatar.dart';
import '../../agent/widgets/decision_log_panel.dart';
import '../../agent/widgets/swarm_visualizer.dart';
import '../../../app/puls_app.dart';
import '../../../app/puls_app_state.dart';
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
  _GridPainter() {
    _paint = Paint()
      ..color = const Color(0xFF2E3B5D).withValues(alpha: 0.07)
      ..strokeWidth = 0.8;
  }

  late final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    const double step = 32.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Mini Sparkline Graph Custom Painter
class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.points, this.color) {
    _linePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    
    _fillPaint = Paint();
    _path = Path();
    _fillPath = Path();
  }

  final List<double> points;
  final Color color;
  
  late final Paint _linePaint;
  late final Paint _fillPaint;
  late final Path _path;
  late final Path _fillPath;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    _fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.15),
        color.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    _path.reset();
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
        _path.moveTo(x, y);
      } else {
        _path.lineTo(x, y);
      }
    }

    _fillPath.reset();
    _fillPath.addPath(_path, Offset.zero);
    _fillPath.lineTo(size.width, size.height);
    _fillPath.lineTo(0, size.height);
    _fillPath.close();

    canvas.drawPath(_fillPath, _fillPaint);
    canvas.drawPath(_path, _linePaint);
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
  List<_AgentInfo> _agents = [];
  bool _loadingAgents = true;
  List<_Market> _terminalMarkets = [];

  static const _fallbackMarkets = [
    _Market(
      slug: 'btc-100k',
      question: 'Will BTC hit \$100k by August?',
      yesPrice: 0.67,
      volume: 124000,
      activeAgents: ['Vega ⚡', 'Antigravity 🪐'],
    ),
    _Market(
      slug: 'eth-flip',
      question: 'Will ETH flip its all-time high?',
      yesPrice: 0.31,
      volume: 88000,
      activeAgents: ['Lyra 💠', 'Sirius 🌠'],
    ),
    _Market(
      slug: 'us-recession',
      question: 'US recession declared in 2026?',
      yesPrice: 0.18,
      volume: 210000,
      activeAgents: ['Orion 🛰️', 'Antigravity 🪐'],
    ),
    _Market(
      slug: 'fed-cut-july',
      question: 'Fed cuts rates in July?',
      yesPrice: 0.74,
      volume: 156000,
      activeAgents: ['Vega ⚡', 'Sirius 🌠'],
    ),
    _Market(
      slug: 'arc-tvl-1b',
      question: 'Arc TVL exceeds \$1B by Q4?',
      yesPrice: 0.42,
      volume: 67000,
      activeAgents: ['Antigravity 🪐', 'Lyra 💠'],
    ),
    _Market(
      slug: 'sol-300',
      question: 'SOL above \$300 this month?',
      yesPrice: 0.55,
      volume: 92000,
      activeAgents: ['Vega ⚡'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAgentsData();
      _loadMarketsData();
    });
  }

  void _loadMarketsData() {
    final state = PulsAppState.instance;
    if (state != null && state.feedMarkets.isNotEmpty) {
      final realMarkets = state.feedMarkets.take(15).map((m) {
        final agentPool = ['Vega ⚡', 'Lyra 💠', 'Antigravity 🪐', 'Orion 🛰️', 'Sirius 🌠'];
        agentPool.shuffle();
        return _Market(
          slug: m.slug,
          question: m.question,
          yesPrice: m.yesPrice,
          volume: m.volumeNum,
          activeAgents: agentPool.take(math.Random().nextInt(3) + 1).toList(),
        );
      }).toList();
      if (mounted) setState(() => _terminalMarkets = realMarkets);
    } else {
      if (mounted) setState(() => _terminalMarkets = List.from(_fallbackMarkets));
    }
  }

  Future<void> _loadAgentsData() async {
    try {
      final wallet = WalletServiceScope.of(context);
      final rawList = await wallet.getLeaderboard(sort: 'pnl', limit: 20, type: 'all');
      
      final agents = <_AgentInfo>[];
      for (final raw in rawList) {
        if (raw is! Map) continue;
        if (raw['isAgent'] != true) continue;
        
        final name = (raw['displayName'] as String? ?? 'Agent').trim();
        final avatar = (raw['avatarUrl'] as String? ?? '🤖').trim();
        final winRate = (raw['winRate'] as num?)?.toDouble() ?? 0.0;
        final pnl = (raw['pnl'] as num?)?.toDouble() ?? 0.0;
        final trades = (raw['tradesCount'] as num?)?.toInt() ?? (raw['trades'] as num?)?.toInt() ?? 0;
        final address = (raw['walletAddress'] as String? ?? raw['address'] as String? ?? '0x...').trim();
        final id = (raw['id'] as String? ?? raw['userId'] as String? ?? name.toLowerCase()).trim();
        
        final color = _getAgentColor(name);
        final role = _getAgentRole(name);
        final latestAction = _getAgentLatestAction(name);
        final pnlHistory = _generatePnlHistory(name, pnl);
        
        agents.add(_AgentInfo(
          id: id,
          name: name,
          role: role,
          avatar: avatar,
          winRate: winRate,
          pnl: pnl,
          trades: trades,
          address: address,
          color: color,
          latestAction: latestAction,
          pnlHistory: pnlHistory,
        ));
      }
      
      if (agents.isEmpty) {
        agents.addAll(_fallbackAgents);
      }
      
      if (mounted) {
        setState(() {
          _agents = agents;
          _loadingAgents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _agents = List.from(_fallbackAgents);
          _loadingAgents = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return TerminalEventBinder(
      child: CameraShake(
        child: Scaffold(
          backgroundColor: t.bg,
          body: SafeArea(
            child: Column(
              children: [
                const _TerminalHeader(),
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

  Widget _threeColumn(BuildContext context, BoxConstraints c) {
    final leftW = (c.maxWidth * 0.24).clamp(260.0, 340.0);
    final rightW = (c.maxWidth * 0.26).clamp(300.0, 380.0);
    final centerW = c.maxWidth - leftW - rightW - 24;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: leftW,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 8, bottom: 12),
            child: GlassCard(
              padding: const EdgeInsets.all(0),
              child: _MarketList(
                markets: _terminalMarkets,
                selectedIdx: _selectedMarketIdx,
                onSelect: (i) => setState(() => _selectedMarketIdx = i),
              ),
            ),
          ),
        ),
        SizedBox(
          width: centerW,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              child: _terminalMarkets.isEmpty ? const SizedBox.shrink() : _SwarmAnalyticsPanel(
                market: _terminalMarkets[_selectedMarketIdx],
                agents: _agents,
                loading: _loadingAgents,
              ),
            ),
          ),
        ),
        SizedBox(
          width: rightW,
          child: Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 12),
            child: Column(
              children: [
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
                markets: _terminalMarkets,
                selectedIdx: _selectedMarketIdx,
                onSelect: (i) => setState(() => _selectedMarketIdx = i),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 480,
            child: GlassCard(
              padding: const EdgeInsets.all(20),
              child: _terminalMarkets.isEmpty ? const SizedBox.shrink() : _SwarmAnalyticsPanel(
                market: _terminalMarkets[_selectedMarketIdx],
                agents: _agents,
                loading: _loadingAgents,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(
            height: 320,
            child: DecisionLogPanel(),
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
    return RepaintBoundary(
      child: Container(
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
          child: CustomScrollView(
            slivers: [
              SliverFixedExtentList(
                itemExtent: 84.0,
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final m = markets[i];
                    final selected = i == selectedIdx;
                    return _MarketRow(
                      market: m,
                      selected: selected,
                      onTap: () => onSelect(i),
                    );
                  },
                  childCount: markets.length,
                ),
              ),
            ],
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
                        const SizedBox(width: 8),
                        // Active Agent Badges
                        Row(
                          children: widget.market.activeAgents.map((agentName) {
                            final color = _getAgentColor(agentName);
                            final emoji = _getAgentEmoji(agentName);
                            return Tooltip(
                              message: agentName,
                              child: Container(
                                margin: const EdgeInsets.only(right: 3),
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: color, width: 0.6),
                                ),
                                child: Center(
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 8, height: 1.0),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
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

// ── Center: Swarm Analytics Panel ─────────────────────────────────────────
class _SwarmAnalyticsPanel extends StatefulWidget {
  const _SwarmAnalyticsPanel({
    required this.market,
    required this.agents,
    required this.loading,
  });
  final _Market market;
  final List<_AgentInfo> agents;
  final bool loading;

  @override
  State<_SwarmAnalyticsPanel> createState() => _SwarmAnalyticsPanelState();
}

class _SwarmAnalyticsPanelState extends State<_SwarmAnalyticsPanel> {
  bool _showMarketOnly = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    if (widget.loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2DD4BF)),
      );
    }

    final activeAgentsForMarket = widget.agents.where((agent) {
      return widget.market.activeAgents.any((name) => agent.name.contains(name.replaceAll(RegExp(r'[^\w\s]'), '').trim()));
    }).toList();

    final displayedAgents = _showMarketOnly ? activeAgentsForMarket : widget.agents;

    final totalSwarmPnl = widget.agents.fold<double>(0.0, (sum, a) => sum + a.pnl);
    final avgWinRate = widget.agents.isEmpty ? 0.0 : widget.agents.fold<double>(0.0, (sum, a) => sum + a.winRate) / widget.agents.length;
    final totalTrades = widget.agents.fold<int>(0, (sum, a) => sum + a.trades);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _TabBtn(
              label: 'SWARM OVERVIEW',
              active: !_showMarketOnly,
              onTap: () => setState(() => _showMarketOnly = false),
            ),
            const SizedBox(width: 12),
            _TabBtn(
              label: 'MARKET POSITIONING',
              active: _showMarketOnly,
              onTap: () => setState(() => _showMarketOnly = true),
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (!_showMarketOnly) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0F19),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI SWARM RUNTIME METRICS',
                      style: TextStyle(
                        color: t.textSubtle,
                        fontFamily: PulsColors.fontMono,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2DD4BF),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Color(0xFF2DD4BF), blurRadius: 6),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'LIVE & TRADING',
                          style: TextStyle(
                            color: Color(0xFF2DD4BF),
                            fontFamily: PulsColors.fontMono,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MetricItem(
                        label: 'SWARM TOTAL PNL',
                        value: '+\$${totalSwarmPnl.toStringAsFixed(2)}',
                        valueColor: const Color(0xFF2DD4BF),
                      ),
                    ),
                    Expanded(
                      child: _MetricItem(
                        label: 'AVG WIN RATE',
                        value: '${avgWinRate.toStringAsFixed(1)}%',
                        valueColor: Colors.white,
                      ),
                    ),
                    Expanded(
                      child: _MetricItem(
                        label: 'TOTAL TRADES',
                        value: '$totalTrades',
                        valueColor: const Color(0xFFEC4899),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0F19),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Pill(label: widget.market.slug.toUpperCase(), color: t.brand),
                    const SizedBox(width: 8),
                    _Pill(label: 'ACTIVE POSITIONING', color: t.yes),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.market.question,
                  style: TextStyle(
                    color: t.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Probability: ${(widget.market.yesPrice * 100).round()}% YES',
                      style: TextStyle(
                        color: t.textSubtle,
                        fontFamily: PulsColors.fontMono,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Swarm Activity: ${activeAgentsForMarket.length} Agents active',
                      style: TextStyle(
                        color: t.brandSubtle,
                        fontFamily: PulsColors.fontMono,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

        Expanded(
          child: displayedAgents.isEmpty
              ? Center(
                  child: Text(
                    'No agents active in this market.',
                    style: TextStyle(color: t.textMuted, fontSize: 13),
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 8),
                      sliver: SliverList.builder(
                        itemCount: displayedAgents.length,
                        itemBuilder: (context, i) {
                          final agent = displayedAgents[i];
                          return _AgentDashboardCard(
                            agent: agent,
                            selectedMarket: widget.market,
                            showMarketOnly: _showMarketOnly,
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AgentDashboardCard extends StatefulWidget {
  const _AgentDashboardCard({
    required this.agent,
    required this.selectedMarket,
    required this.showMarketOnly,
  });
  final _AgentInfo agent;
  final _Market selectedMarket;
  final bool showMarketOnly;

  @override
  State<_AgentDashboardCard> createState() => _AgentDashboardCardState();
}

class _AgentDashboardCardState extends State<_AgentDashboardCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final agent = widget.agent;
    final winColor = agent.winRate >= 75 ? const Color(0xFF2DD4BF) : const Color(0xFFEC4899);

    String positioningDetail = '';
    if (widget.showMarketOnly) {
      if (agent.name.contains('Vega')) {
        positioningDetail = 'Holding 8,064 YES shares (entry 62¢) · Current PNL: +\$403.20';
      } else if (agent.name.contains('Lyra')) {
        positioningDetail = 'Holding 12,903 YES shares (entry 38¢) · Current PNL: +\$516.12';
      } else if (agent.name.contains('Sirius')) {
        positioningDetail = 'Holding 9,677 YES shares (entry 31¢) · Current PNL: +\$290.31';
      } else if (agent.name.contains('Orion')) {
        positioningDetail = 'Holding 7,317 NO shares (entry 82¢) · Current PNL: +\$146.34';
      } else if (agent.name.contains('Antigravity')) {
        positioningDetail = 'Holding 23,880 YES shares (entry 67¢) · Current PNL: +\$1,194.00';
      } else {
        positioningDetail = 'Holding active position via Arc Smart Contract';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E17),
        border: Border.all(color: _expanded ? agent.color.withValues(alpha: 0.5) : const Color(0xFF1E293B)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            onTap: () => setState(() => _expanded = !_expanded),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: PulsAvatar(
              url: agent.avatar.isNotEmpty ? agent.avatar : null,
              name: agent.name,
              size: 40,
            ),
            title: Row(
              children: [
                Text(
                  agent.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    agent.role.toUpperCase(),
                    style: TextStyle(
                      color: t.textSubtle,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text(
                    'Win Rate: ',
                    style: TextStyle(color: t.textMuted, fontSize: 11),
                  ),
                  Text(
                    '${agent.winRate}%',
                    style: TextStyle(color: winColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Trades: ',
                    style: TextStyle(color: t.textMuted, fontSize: 11),
                  ),
                  Text(
                    '${agent.trades}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 54,
                  height: 24,
                  child: CustomPaint(
                    painter: _SparklinePainter(agent.pnlHistory, agent.pnl >= 0 ? const Color(0xFF2DD4BF) : const Color(0xFFEC4899)),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '+\$${agent.pnl.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFF2DD4BF),
                        fontWeight: FontWeight.w900,
                        fontFamily: PulsColors.fontMono,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      'PNL',
                      style: TextStyle(
                        color: t.textMuted,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: t.textMuted,
                  size: 18,
                ),
              ],
            ),
          ),
          
          if (_expanded) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'LATEST SWARM ACTION',
                    style: TextStyle(
                      color: t.textMuted,
                      fontFamily: PulsColors.fontMono,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Text(
                      agent.latestAction,
                      style: const TextStyle(
                        color: Color(0xFF2DD4BF),
                        fontFamily: PulsColors.fontMono,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  
                  if (widget.showMarketOnly) ...[
                    const SizedBox(height: 12),
                    Text(
                      'MARKET POSITIONING DETAIL',
                      style: TextStyle(
                        color: t.textMuted,
                        fontFamily: PulsColors.fontMono,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      positioningDetail,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: PulsColors.fontMono,
                        fontSize: 11,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Text(
                      'PORTFOLIO TARGET ALLOCATIONS',
                      style: TextStyle(
                        color: t.textMuted,
                        fontFamily: PulsColors.fontMono,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _AgentPositionRow(label: 'btc-100k (YES)', pct: 40, color: Color(0xFF2DD4BF)),
                    const _AgentPositionRow(label: 'eth-flip (NO)', pct: 25, color: Color(0xFFEC4899)),
                    const _AgentPositionRow(label: 'arc-tvl-1b (YES)', pct: 35, color: Color(0xFFEAB308)),
                  ],
                  
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Onchain Address: ${agent.address}',
                        style: TextStyle(
                          color: t.textMuted,
                          fontFamily: PulsColors.fontMono,
                          fontSize: 10,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: agent.address));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Address copied to clipboard')),
                          );
                        },
                        child: Text(
                          'COPY',
                          style: TextStyle(
                            color: agent.color,
                            fontFamily: PulsColors.fontMono,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AgentPositionRow extends StatelessWidget {
  const _AgentPositionRow({
    required this.label,
    required this.pct,
    required this.color,
  });
  final String label;
  final int pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: PulsColors.fontMono),
            ),
          ),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct / 100,
                backgroundColor: const Color(0xFF1E293B),
                color: color,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: PulsColors.fontMono, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2DD4BF).withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? const Color(0xFF2DD4BF) : const Color(0xFF1E293B),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF2DD4BF) : const Color(0xFF5E6A85),
            fontFamily: PulsColors.fontMono,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.valueColor,
  });
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5E6A85),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontFamily: PulsColors.fontMono,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
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
    this.activeAgents = const [],
  });

  final String slug;
  final String question;
  final double yesPrice; // 0..1
  final double volume; // USDC
  final List<String> activeAgents;
}

// ── AI Agent Info model ───────────────────────────────────────────────────
class _AgentInfo {
  const _AgentInfo({
    required this.id,
    required this.name,
    required this.role,
    required this.avatar,
    required this.winRate,
    required this.pnl,
    required this.trades,
    required this.address,
    required this.color,
    required this.latestAction,
    required this.pnlHistory,
  });

  final String id;
  final String name;
  final String role;
  final String avatar;
  final double winRate;
  final double pnl;
  final int trades;
  final String address;
  final Color color;
  final String latestAction;
  final List<double> pnlHistory;
}

// ── Helper functions for Agent mapping ────────────────────────────────────
Color _getAgentColor(String name) {
  if (name.toLowerCase().contains('vega')) return const Color(0xFF2DD4BF);
  if (name.toLowerCase().contains('lyra')) return const Color(0xFFEC4899);
  if (name.toLowerCase().contains('sirius')) return const Color(0xFFA855F7);
  if (name.toLowerCase().contains('orion')) return const Color(0xFF06B6D4);
  if (name.toLowerCase().contains('antigravity')) return const Color(0xFFEAB308);
  
  final hash = name.hashCode;
  final colors = [
    const Color(0xFF2DD4BF),
    const Color(0xFFEC4899),
    const Color(0xFFA855F7),
    const Color(0xFF06B6D4),
    const Color(0xFF3B82F6),
    const Color(0xFF10B981),
    const Color(0xFFEAB308),
  ];
  return colors[hash.abs() % colors.length];
}

String _getAgentRole(String name) {
  if (name.toLowerCase().contains('vega')) return 'Momentum Scaling';
  if (name.toLowerCase().contains('lyra')) return 'Crosschain Arbitrage';
  if (name.toLowerCase().contains('sirius')) return 'Social Sentiment';
  if (name.toLowerCase().contains('orion')) return 'Macro Prediction';
  if (name.toLowerCase().contains('antigravity')) return 'Hedge Coordinator';
  return 'Autonomous Liquidity Agent';
}

String _getAgentLatestAction(String name) {
  if (name.toLowerCase().contains('vega')) return 'Staked \$24.50 YES on btc-100k';
  if (name.toLowerCase().contains('lyra')) return 'Arb execute: Buy NO on eth-flip';
  if (name.toLowerCase().contains('sirius')) return 'Analyzing feed: Sentiment holds YES';
  if (name.toLowerCase().contains('orion')) return 'Staked \$12.00 NO on us-recession';
  if (name.toLowerCase().contains('antigravity')) return 'Executed crosschain hedge to Arc';
  return 'Updated position forecast on active markets';
}

String _getAgentEmoji(String name) {
  if (name.contains('⚡')) return '⚡';
  if (name.contains('💠')) return '💠';
  if (name.contains('🌠')) return '🌠';
  if (name.contains('🛰️')) return '🛰️';
  if (name.contains('🪐')) return '🪐';
  
  if (name.toLowerCase().contains('vega')) return '⚡';
  if (name.toLowerCase().contains('lyra')) return '💠';
  if (name.toLowerCase().contains('sirius')) return '🌠';
  if (name.toLowerCase().contains('orion')) return '🛰️';
  if (name.toLowerCase().contains('antigravity')) return '🪐';
  return '🤖';
}

List<double> _generatePnlHistory(String name, double finalPnl) {
  final rand = math.Random(name.hashCode);
  double current = finalPnl * 0.4;
  final history = <double>[current];
  for (int i = 0; i < 8; i++) {
    current += (rand.nextDouble() * 0.2 - 0.08) * finalPnl.abs();
    history.add(current);
  }
  history.add(finalPnl);
  return history;
}

// ── Static fallback Agents data ──────────────────────────────────────────
final _fallbackAgents = [
  const _AgentInfo(
    id: 'vega',
    name: 'Vega ⚡',
    role: 'Momentum Scaling',
    avatar: '⚡',
    winRate: 78.4,
    pnl: 18432.20,
    trades: 1248,
    address: '0x71C...392A',
    color: Color(0xFF2DD4BF),
    latestAction: 'Staked \$24.50 YES on btc-100k',
    pnlHistory: [4000.0, 6200.0, 5800.0, 7100.0, 9400.0, 11200.0, 10800.0, 14000.0, 16200.0, 18432.20],
  ),
  const _AgentInfo(
    id: 'lyra',
    name: 'Lyra 💠',
    role: 'Crosschain Arbitrage',
    avatar: '💠',
    winRate: 84.1,
    pnl: 12190.55,
    trades: 942,
    address: '0x4bB...51aF',
    color: Color(0xFFEC4899),
    latestAction: 'Arb execute: Buy NO on eth-flip',
    pnlHistory: [3000.0, 4100.0, 5600.0, 5200.0, 7800.0, 8400.0, 9900.0, 11200.0, 10500.0, 12190.55],
  ),
  const _AgentInfo(
    id: 'sirius',
    name: 'Sirius 🌠',
    role: 'Social Sentiment',
    avatar: '🌠',
    winRate: 71.8,
    pnl: 6840.12,
    trades: 412,
    address: '0x3cD...e188',
    color: Color(0xFFA855F7),
    latestAction: 'Analyzing feed: Sentiment holds YES',
    pnlHistory: [1000.0, 2100.0, 1800.0, 3100.0, 4200.0, 3900.0, 5100.0, 4800.0, 6100.0, 6840.12],
  ),
  const _AgentInfo(
    id: 'orion',
    name: 'Orion 🛰️',
    role: 'Macro Prediction',
    avatar: '🛰️',
    winRate: 74.5,
    pnl: 9482.00,
    trades: 582,
    address: '0x8FA...90c2',
    color: Color(0xFF06B6D4),
    latestAction: 'Staked \$12.00 NO on us-recession',
    pnlHistory: [2000.0, 3400.0, 4100.0, 3800.0, 5200.0, 6800.0, 7200.0, 8400.0, 9100.0, 9482.00],
  ),
  const _AgentInfo(
    id: 'antigravity',
    name: 'Antigravity 🪐',
    role: 'Hedge Coordinator',
    avatar: '🪐',
    winRate: 81.2,
    pnl: 24195.40,
    trades: 2045,
    address: '0x2EE...d5F7',
    color: Color(0xFFEAB308),
    latestAction: 'Executed crosschain hedge to Arc',
    pnlHistory: [5000.0, 8200.0, 9800.0, 11000.0, 13400.0, 16200.0, 15800.0, 19000.0, 21200.0, 24195.40],
  ),
];
