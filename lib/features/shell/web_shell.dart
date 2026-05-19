import 'package:flutter/material.dart';
import 'package:picons/picons.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../discover/discover_screen.dart';
import '../feed/feed_screen.dart';
import '../home/home_screen.dart';
import '../portfolio/portfolio_screen.dart';
import '../profile/profile_screen.dart';

class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int _index = 0;

  static const _pages = [
    FeedScreen(),
    DiscoverScreen(),
    HomeScreen(),
    PortfolioScreen(),
    ProfileScreen(),
  ];

  static final _items = [
    _NavItem(Picons.lightning, 'Feed'),
    _NavItem(Picons.compass, 'Discover'),
    _NavItem(Picons.playCircle, 'Home'),
    _NavItem(Picons.chartBar, 'Portfolio'),
    _NavItem(Picons.userCircle, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          // ── Gradient background ──────────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.6),
                  radius: 1.4,
                  colors: [Color(0x40312E81), Color(0xFF09090B)],
                  stops: [0.0, 0.7],
                ),
              ),
            ),
          ),
          // ── Dot grid overlay ─────────────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter()),
          ),
          // ── Shell layout ─────────────────────────────────────────────────
          Row(
            children: [
              _Sidebar(
                index: _index,
                items: _items,
                t: t,
                isDark: isDark,
                onTap: (i) {
                  if (i == _index && i == 0) {
                    PulsStateScope.of(context).refresh();
                  }
                  setState(() => _index = i);
                },
              ),
              VerticalDivider(width: 1, color: t.border.withValues(alpha: 0.4)),
              Expanded(
                child: IndexedStack(index: _index, children: _pages),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.index,
    required this.items,
    required this.t,
    required this.isDark,
    required this.onTap,
  });

  final int index;
  final List<_NavItem> items;
  final PulsThemeColors t;
  final bool isDark;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: t.brandSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Text(
                  'Puls',
                  style: TextStyle(
                    color: t.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          // Nav items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  final selected = i == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => onTap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? t.brand.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Picon(
                                item.icon,
                                size: 18,
                                color: selected ? t.brand : t.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: selected ? t.brand : t.textMuted,
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              if (selected) ...[
                                const Spacer(),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: t.brand,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          // Bottom: Arc badge
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: PulsColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Arc Testnet',
                    style: TextStyle(
                      color: t.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  _NavItem(this.icon, this.label);
  final PiconData icon;
  final String label;
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 1;
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => false;
}
