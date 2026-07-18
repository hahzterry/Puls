import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../agent/widgets/decision_log_panel.dart';
import '../../agent/widgets/swarm_visualizer.dart';

/// AI Bloomberg Terminal — a dense, 3-column trading interface for the
/// hackathon demo. Left: market list. Center: arena/betting. Right: live
/// agent decision stream.
///
/// Layout strategy:
///   - On wide screens (≥1100px): a fixed 3-column Row, each column pinned.
///   - On medium screens (700–1099px): 2 columns, market list collapses to a drawer.
///   - On narrow screens (<700px): single column with bottom-nav between panels.
///   (This file implements the wide layout — the money shot for the demo.)
class MarketTerminalScreen extends StatefulWidget {
  const MarketTerminalScreen({super.key});

  @override
  State<MarketTerminalScreen> createState() => _MarketTerminalScreenState();
}

class _MarketTerminalScreenState extends State<MarketTerminalScreen> {
  int _selectedMarketIdx = 0;

  // Demo market data — in production this would come from PulsStateScope.
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
    return CameraShake(
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
                    borderRadius: BorderRadius.circular(8),
                    child: const SwarmVisualizer(
                      background: Color(0xFF000000),
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
class _TerminalHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal_rounded, size: 18, color: t.brand),
          const SizedBox(width: 10),
          const AnimatedGradientText(
            'PULS // TERMINAL',
            style: TextStyle(
              fontFamily: PulsColors.fontMono,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          _StatusChip(label: 'ARC', color: t.yes),
          const SizedBox(width: 8),
          _StatusChip(label: 'x402', color: t.brand),
          const SizedBox(width: 8),
          _StatusChip(label: 'LIVE', color: PulsColors.red),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Icon(Icons.close_rounded, size: 18, color: t.textMuted),
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.6),
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
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: t.surfaceRaised.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: Row(
            children: [
              Text(
                'MARKETS',
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
            padding: const EdgeInsets.symmetric(vertical: 4),
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

class _MarketRow extends StatelessWidget {
  const _MarketRow({
    required this.market,
    required this.selected,
    required this.onTap,
  });

  final _Market market;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final yesPct = (market.yesPrice * 100).round();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? t.brand.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: selected
              ? Border.all(color: t.brand.withValues(alpha: 0.4), width: 0.6)
              : Border.all(color: Colors.transparent, width: 0.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              market.question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? t.text : t.textMuted,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${market.volume > 1000 ? '${(market.volume / 1000).toStringAsFixed(0)}k' : market.volume.toStringAsFixed(0)} vol',
                  style: TextStyle(
                    color: t.textSubtle,
                    fontFamily: PulsColors.fontMono,
                    fontSize: 9,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: (yesPct >= 50 ? t.yes : t.no).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '$yesPct%',
                    style: TextStyle(
                      color: yesPct >= 50 ? t.yes : t.no,
                      fontFamily: PulsColors.fontMono,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Center: Arena / betting panel ─────────────────────────────────────────
class _ArenaPanel extends StatelessWidget {
  const _ArenaPanel({required this.market});
  final _Market market;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final yesPct = (market.yesPrice * 100).round();
    final noPct = 100 - yesPct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Market question
        Text(
          market.question,
          style: TextStyle(
            color: t.text,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            height: 1.2,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
          _Pill(label: market.slug.toUpperCase(), color: t.textMuted),
          const SizedBox(width: 8),
          _Pill(label: 'ARC-TESTNET', color: t.yes),
          const Spacer(),
          Text(
            '\$${(market.volume / 1000).toStringAsFixed(0)}k vol',
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

        // Probability bar — mint vs pink
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: yesPct,
                  child: Container(color: t.yes),
                ),
                Expanded(
                  flex: noPct,
                  child: Container(color: t.no),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'YES $yesPct¢',
              style: TextStyle(
                color: t.yes,
                fontFamily: PulsColors.fontMono,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              'NO $noPct¢',
              style: TextStyle(
                color: t.no,
                fontFamily: PulsColors.fontMono,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Bet amount input
        Text(
          'STAKE (USDC)',
          style: TextStyle(
            color: t.textMuted,
            fontFamily: PulsColors.fontMono,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.border),
          ),
          child: Row(
            children: [
              Text(
                '\$',
                style: TextStyle(
                  color: t.textSubtle,
                  fontFamily: PulsColors.fontMono,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '10.00',
                style: TextStyle(
                  color: t.text,
                  fontFamily: PulsColors.fontMono,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                '≈ ${(10 / market.yesPrice).toStringAsFixed(1)} YES',
                style: TextStyle(
                  color: t.yes,
                  fontFamily: PulsColors.fontMono,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // YES / NO action buttons
        Row(
          children: [
            Expanded(
              child: _BetButton(
                label: 'BUY YES',
                price: '${(market.yesPrice * 100).round()}¢',
                color: t.yes,
                onTap: () => triggerCameraShake(context, intensity: 6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BetButton(
                label: 'BUY NO',
                price: '${(noPct * 1).round()}¢',
                color: t.no,
                onTap: () {},
              ),
            ),
          ],
        ),
        const Spacer(),
        // Footer: agent commentary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.smart_toy_rounded, size: 14, color: t.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Vega ⚡ went YES · \$2.50 · "momentum is breaking out, pressing this hard"',
                  style: TextStyle(
                    color: t.textMuted,
                    fontSize: 11,
                    height: 1.4,
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

class _BetButton extends StatelessWidget {
  const _BetButton({
    required this.label,
    required this.price,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String price;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.heavyImpact();
        onTap();
      },
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: PulsColors.fontMono,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '@ $price',
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontFamily: PulsColors.fontMono,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
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
