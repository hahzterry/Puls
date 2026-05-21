import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/puls_app_state.dart';
import '../../app/puls_app.dart';
import '../../core/theme/app_theme.dart';

class WebLandingPage extends StatefulWidget {
  const WebLandingPage({super.key});

  @override
  State<WebLandingPage> createState() => _WebLandingPageState();
}

class _WebLandingPageState extends State<WebLandingPage> {
  final _scrollCtrl = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (mounted) setState(() => _scrollOffset = _scrollCtrl.offset);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = context.isDark;

    // Background patterns
    final gradientGlow = isDark
        ? const Color(0x30312E81) // Dark indigo glow
        : const Color(0x124F46E5); // Light indigo glow
    final dotColor = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : const Color(0xFF4F46E5).withValues(alpha: 0.03);

    return Scaffold(
      backgroundColor: t.bg,
      body: Stack(
        children: [
          // ── Radial Glow Background ───────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.4,
                  colors: [gradientGlow, t.bg],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          // ── Dot Grid ────────────────────────────────────────────────────
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter(color: dotColor)),
          ),
          // ── Content ─────────────────────────────────────────────────────
          SingleChildScrollView(
            controller: _scrollCtrl,
            child: Column(
              children: [
                _HeroSection(scrollOffset: _scrollOffset),
                const _FeaturesSection(),
                const _HowItWorksSection(),
                const _StatsSection(),
                const _FooterSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Navbar ────────────────────────────────────────────────────────────────────
class _Navbar extends StatelessWidget {
  const _Navbar();

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final isDark = context.isDark;

    return Container(
      color: t.bg.withValues(alpha: 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: t.brandSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/logo.png', fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Text(
            'Puls',
            style: TextStyle(
              color: t.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          _NavLink('GitHub', 'https://github.com/rdmbtc/Puls'),
          const SizedBox(width: 8),
          _NavLink('Explorer', 'https://testnet.arcscan.app/address/0x6c1f21fe9d5dff9a2feabd9c760cb9296aa48072'),
          const SizedBox(width: 16),
          // Theme Toggle button
          IconButton(
            onPressed: appState.toggleThemeMode,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 20,
              color: t.textMuted,
            ),
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          ),
          const SizedBox(width: 16),
          _PrimaryButton(
            label: 'Launch App',
            onTap: appState.completeOnboarding,
            small: true,
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  const _NavLink(this.label, this.url);
  final String label;
  final String url;

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(widget.url), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? t.brand : t.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.scrollOffset});
  final double scrollOffset;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final h = MediaQuery.sizeOf(context).height;
    final parallaxY = -(scrollOffset * 0.2).clamp(0.0, h * 0.25);
    final heroOpacity = (1 - scrollOffset / (h * 0.5)).clamp(0.0, 1.0);

    return SizedBox(
      height: h,
      child: Stack(
        children: [
          // Navbar
          const Positioned(top: 0, left: 0, right: 0, child: _Navbar()),
          // Hero content with parallax
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, parallaxY),
              child: Opacity(
                opacity: heroOpacity,
                child: const _HeroContent(),
              ),
            ),
          ),
          // Bottom fade gradient
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [t.bg, t.bg.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent();

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 80),
        // Live on Arc badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: t.brandSubtle,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: t.brand.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: t.brand, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'Live on Arc Testnet · Chain ID 5042002',
                style: TextStyle(color: t.brand, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.15),
        const SizedBox(height: 28),
        // Title
        Text(
          'Trade on the\nFuture of Everything.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: PulsColors.fontDisplay,
            color: t.text,
            fontSize: 62,
            fontWeight: FontWeight.w700,
            height: 1.12,
            letterSpacing: -2.0,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 0.15, delay: 100.ms),
        const SizedBox(height: 24),
        // Subtitle
        Text(
          'An on-chain prediction market powered by USDC.\nNo gas tokens needed. Sub-second finality.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: t.textMuted,
            fontSize: 17,
            height: 1.65,
            fontWeight: FontWeight.w400,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.15, delay: 200.ms),
        const SizedBox(height: 38),
        // Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PrimaryButton(label: 'Sign in with Google', onTap: appState.completeOnboarding)
                .animate().fadeIn(duration: 600.ms, delay: 300.ms).slideY(begin: 0.15, delay: 300.ms),
            const SizedBox(width: 12),
            Builder(
              builder: (context) {
                final wallet = WalletServiceScope.of(context);
                return _SecondaryButton(
                  label: 'Connect Wallet',
                  onTap: () async {
                    await wallet.signInWithExternalWallet();
                    if (wallet.state.isExternalWallet && context.mounted) {
                      appState.completeOnboarding();
                    }
                  },
                ).animate().fadeIn(duration: 600.ms, delay: 350.ms).slideY(begin: 0.15, delay: 350.ms);
              },
            ),
          ],
        ),
        const SizedBox(height: 52),
        // Live stats strip
        _LiveStatsStrip()
            .animate().fadeIn(duration: 600.ms, delay: 450.ms),
      ],
    );
  }
}

class _LiveStatsStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatChip(icon: Icons.bolt_rounded, label: '100 Live Markets', color: t.brand),
          _Divider(),
          _StatChip(icon: Icons.account_balance_wallet_rounded, label: 'Circle MPC Wallets', color: t.yes),
          _Divider(),
          _StatChip(icon: Icons.speed_rounded, label: 'Sub-second Finality', color: PulsColors.amber),
          _Divider(),
          _StatChip(icon: Icons.water_drop_rounded, label: 'USDC Gas Token', color: const Color(0xFF0EA5E9)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      width: 1, height: 16,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: t.border,
    );
  }
}

// ── Features Section ──────────────────────────────────────────────────────────
class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  static const _features = [
    _Feature(
      icon: Icons.swipe_rounded,
      color: Color(0xFF4F46E5),
      title: 'Swipe to Trade',
      body: 'Swipe right for YES, left for NO. Buy any Polymarket prediction in under a second — no confirmation modal.',
    ),
    _Feature(
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF16A34A),
      title: 'Instant MPC Wallet',
      body: 'Sign in with Google and get a Circle MPC wallet on Arc Testnet automatically. No seed phrase, no setup.',
    ),
    _Feature(
      icon: Icons.show_chart_rounded,
      color: Color(0xFF0EA5E9),
      title: 'Real Polymarket Data',
      body: '100 live markets from Polymarket with real odds, sparkline charts, bid/ask spread, and 24h volume.',
    ),
    _Feature(
      icon: Icons.water_drop_rounded,
      color: Color(0xFFD97706),
      title: 'USDC — No ETH Needed',
      body: 'Arc Testnet uses USDC as the native gas token. Pay fees in USDC. No ETH, no bridging, no friction.',
    ),
    _Feature(
      icon: Icons.bar_chart_rounded,
      color: Color(0xFFEC4899),
      title: 'Portfolio & PNL',
      body: 'Track every trade with entry price, current price, and real-time PNL. View transactions on Arc Explorer.',
    ),
    _Feature(
      icon: Icons.play_circle_rounded,
      color: Color(0xFF8B5CF6),
      title: 'TikTok-style Feed',
      body: 'Vertical video feed with prediction pills. Swipe through content and lock in your prediction without leaving.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.puls;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 96),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: t.brandSubtle,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: t.brand.withValues(alpha: 0.3)),
            ),
            child: Text(
              'FEATURES',
              style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Everything you need to trade predictions',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.text, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            'Built on Circle\'s full-stack: MPC wallets, USDC, Arc Testnet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.textMuted, fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 56),
          LayoutBuilder(builder: (context, constraints) {
            final cols = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: _features.map((f) => SizedBox(
                width: (constraints.maxWidth - (cols - 1) * 20) / cols,
                child: _FeatureCard(feature: f),
              )).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _Feature {
  const _Feature({required this.icon, required this.color, required this.title, required this.body});
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

class _FeatureCard extends StatefulWidget {
  const _FeatureCard({required this.feature});
  final _Feature feature;

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final f = widget.feature;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: _hovered ? t.surfaceRaised : t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _hovered ? f.color.withValues(alpha: 0.5) : t.border),
          boxShadow: _hovered
              ? [BoxShadow(color: f.color.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: f.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(f.icon, color: f.color, size: 24),
            ),
            const SizedBox(height: 18),
            Text(
              f.title,
              style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              f.body,
              style: TextStyle(color: t.textMuted, fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ── How It Works ──────────────────────────────────────────────────────────────
class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  static const _steps = [
    ('01', 'Sign in with Google', 'One tap. A Circle MPC wallet is created on Arc Testnet automatically. No seed phrase.', Color(0xFF4F46E5)),
    ('02', 'Get testnet USDC', 'Visit faucet.circle.com → select Arc Testnet → paste your wallet address. Free USDC in seconds.', Color(0xFF16A34A)),
    ('03', 'Browse 100 live markets', 'Real Polymarket predictions with live odds, sparkline charts, and volume data.', Color(0xFF0EA5E9)),
    ('04', 'Swipe YES or NO', 'Swipe right for YES, left for NO. Your USDC is sent to the PulsMarket smart contract on-chain.', Color(0xFFD97706)),
    ('05', 'Track your PNL', 'Portfolio shows entry price, current price, and real-time PNL. Claim winnings when markets resolve.', Color(0xFFEC4899)),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.puls;

    return Container(
      color: t.surface.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 96),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: t.brandSubtle,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: t.brand.withValues(alpha: 0.3)),
            ),
            child: Text(
              'HOW IT WORKS',
              style: TextStyle(color: t.brand, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'From zero to on-chain in 60 seconds',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.text, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.2),
          ),
          const SizedBox(height: 56),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              children: _steps.asMap().entries.map((e) {
                final step = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _StepRow(
                    number: step.$1,
                    title: step.$2,
                    body: step.$3,
                    color: step.$4,
                    isLast: e.key == _steps.length - 1,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.body,
    required this.color,
    required this.isLast,
  });
  final String number, title, body;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(number, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: t.border,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: TextStyle(color: t.textMuted, fontSize: 14, height: 1.6),
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

// ── Stats Section ─────────────────────────────────────────────────────────────
class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    final t = context.puls;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 88),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Text(
                'Built on Circle\'s full stack',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.text, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1),
              ),
              const SizedBox(height: 8),
              Text(
                'Real infrastructure. Real trades. Testnet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.textMuted, fontSize: 16),
              ),
              const SizedBox(height: 48),
              LayoutBuilder(builder: (context, constraints) {
                final cols = constraints.maxWidth > 700 ? 4 : 2;
                return Wrap(
                  spacing: 20, runSpacing: 20,
                  children: [
                    _statCard('100+', 'Live Markets', 'From Polymarket Gamma API', t.brand, constraints, cols, t),
                    _statCard('< 1s', 'Trade Speed', 'Arc Testnet sub-second finality', t.yes, constraints, cols, t),
                    _statCard('\$0 ETH', 'Gas Cost', 'USDC is the native gas token', PulsColors.amber, constraints, cols, t),
                    _statCard('MPC', 'Wallet Type', 'Circle developer-controlled wallets', const Color(0xFF0EA5E9), constraints, cols, t),
                  ],
                );
              }),
              const SizedBox(height: 52),
              // Contract address widget
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.03), blurRadius: 10)
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: t.brandSubtle, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.code_rounded, color: t.brand, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PulsMarket.sol — Arc Testnet',
                            style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '0x6c1f21fe9d5dff9a2feabd9c760cb9296aa48072',
                            style: TextStyle(color: t.textSubtle, fontSize: 12, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CopyButton(text: '0x6c1f21fe9d5dff9a2feabd9c760cb9296aa48072'),
                    const SizedBox(width: 8),
                    _SecondaryButton(
                      label: 'View ↗',
                      onTap: () => launchUrl(
                        Uri.parse('https://testnet.arcscan.app/address/0x6c1f21fe9d5dff9a2feabd9c760cb9296aa48072'),
                        mode: LaunchMode.externalApplication,
                      ),
                      small: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, String sub, Color color, BoxConstraints constraints, int cols, PulsThemeColors t) {
    return SizedBox(
      width: (constraints.maxWidth - (cols - 1) * 20) / cols,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(color: t.textMuted, fontSize: 12, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});
  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return IconButton(
      onPressed: () {
        Clipboard.setData(ClipboardData(text: widget.text));
        setState(() => _copied = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _copied = false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address copied to clipboard!')),
        );
      },
      icon: Icon(
        _copied ? Icons.check_circle_outline_rounded : Icons.copy_rounded,
        color: _copied ? t.yes : t.brand,
        size: 18,
      ),
      tooltip: 'Copy contract address',
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────
class _FooterSection extends StatelessWidget {
  const _FooterSection();

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;

    return Container(
      color: t.surface.withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(52),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [t.brand, t.brand.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: t.brand.withValues(alpha: 0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Ready to predict?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sign in with Google. Get a wallet. Trade in 60 seconds.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16, height: 1.6),
                    ),
                    const SizedBox(height: 32),
                    _WhiteButton(
                      label: 'Launch Puls →',
                      onTap: appState.completeOnboarding,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              Row(
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: t.brandSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Puls',
                    style: TextStyle(color: t.text, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    'Built on Arc Testnet · Circle MPC Wallets',
                    style: TextStyle(color: t.textSubtle, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  _FooterLink('GitHub', 'https://github.com/rdmbtc/Puls'),
                  const SizedBox(width: 20),
                  _FooterLink('Explorer', 'https://testnet.arcscan.app/address/0x6c1f21fe9d5dff9a2feabd9c760cb9296aa48072'),
                  const SizedBox(width: 20),
                  _FooterLink('Faucet', 'https://faucet.circle.com'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.label, this.url);
  final String label, url;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          label,
          style: TextStyle(color: t.textMuted, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

// ── Shared Buttons ────────────────────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.label, required this.onTap, this.small = false});
  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.small ? 18 : 32,
              vertical: widget.small ? 10 : 16,
            ),
            decoration: BoxDecoration(
              color: t.brand,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _hovered
                  ? [BoxShadow(color: t.brand.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatefulWidget {
  const _SecondaryButton({required this.label, required this.onTap, this.small = false});
  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.small ? 16 : 30,
            vertical: widget.small ? 10 : 16,
          ),
          decoration: BoxDecoration(
            color: _hovered ? t.surfaceRaised : t.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hovered ? t.textMuted : t.border),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? t.text : t.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _WhiteButton extends StatefulWidget {
  const _WhiteButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_WhiteButton> createState() => _WhiteButtonState();
}

class _WhiteButtonState extends State<_WhiteButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _hovered
                  ? [BoxShadow(color: const Color(0xFF4F46E5).withValues(alpha: 0.12), blurRadius: 15, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Text(
              widget.label,
              style: TextStyle(color: t.brand, fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 32.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.75, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
