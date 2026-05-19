import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/puls_app_state.dart';

// ── Colors ────────────────────────────────────────────────────────────────────
const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _muted = Color(0xFFA6A6A6);
const _heroSubtitle = Color(0xFFF0F3F7);

class WebLandingPage extends StatefulWidget {
  const WebLandingPage({super.key});

  @override
  State<WebLandingPage> createState() => _WebLandingPageState();
}

class _WebLandingPageState extends State<WebLandingPage> {
  final _scrollCtrl = ScrollController();
  double _scrollFraction = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    if (max <= 0) return;
    setState(() => _scrollFraction = (_scrollCtrl.offset / max).clamp(0, 1));
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      body: SingleChildScrollView(
        controller: _scrollCtrl,
        child: Column(
          children: [
            _HeroSection(scrollFraction: _scrollFraction),
            const _TestimonialSection(),
          ],
        ),
      ),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.scrollFraction});
  final double scrollFraction;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    // Parallax: hero content fades and moves up as user scrolls
    final heroOpacity = (1 - scrollFraction * 4).clamp(0.0, 1.0);
    final heroY = -scrollFraction * h * 0.3;

    return SizedBox(
      height: h,
      child: Stack(
        children: [
          // ── Navbar ──────────────────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: _Navbar(),
          ),
          // ── Hero content ─────────────────────────────────────────────────
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, heroY),
              child: Opacity(
                opacity: heroOpacity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 80),
                    _HeroContent(),
                  ],
                ),
              ),
            ),
          ),
          // ── Bottom fade ───────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 160,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [_black, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Navbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 112, vertical: 16),
      child: Row(
        children: [
          // Logo
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/logo.png', fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          const Text('Puls Market',
              style: TextStyle(color: _white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          const SizedBox(width: 80),
          // Nav links
          ...[('Home', true), ('Leaderboard', false), ('Rewards', false), ('FAQ', false)].map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton(
                onPressed: item.$2 ? null : () {},
                style: TextButton.styleFrom(
                  foregroundColor: item.$2 ? _white : _muted,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(item.$1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: item.$2 ? FontWeight.w600 : FontWeight.w400,
                      color: item.$2 ? _white : _muted,
                    )),
              ),
            ),
          ),
          const Spacer(),
          // Play Now button
          GestureDetector(
            onTap: appState.completeOnboarding,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Play Now',
                    style: TextStyle(
                      color: _black,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    return Column(
      children: [
        // ── Liquid glass pill ──────────────────────────────────────────────
        _LiquidGlassPill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('New',
                    style: TextStyle(color: _black, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 10),
              const Text('Introducing Swipe-to-Predict v1.0',
                  style: TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.3, duration: 500.ms),
        const SizedBox(height: 24),

        // ── Title ──────────────────────────────────────────────────────────
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              color: _white,
              fontSize: 72,
              fontWeight: FontWeight.w500,
              height: 1.1,
              letterSpacing: -2,
            ),
            children: [
              const TextSpan(text: 'Predict. Swipe.\n'),
              const TextSpan(text: 'Win'),
              const TextSpan(
                text: ' Big.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                  color: _white,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 100.ms).slideY(begin: 0.3, duration: 600.ms, delay: 100.ms),
        const SizedBox(height: 20),

        // ── Subtitle ───────────────────────────────────────────────────────
        const Text(
          'Puls Market turns market movements into a game.\nPredict trends, swipe to lock in, and win rewards.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _heroSubtitle,
            fontSize: 18,
            fontWeight: FontWeight.w400,
            height: 1.6,
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.3, duration: 600.ms, delay: 200.ms),
        const SizedBox(height: 36),

        // ── CTA ────────────────────────────────────────────────────────────
        _CTAButton(
          label: 'Play for Free',
          onTap: appState.completeOnboarding,
        ).animate().fadeIn(duration: 600.ms, delay: 300.ms).slideY(begin: 0.3, duration: 600.ms, delay: 300.ms),
      ],
    );
  }
}

// ── Liquid Glass Pill ─────────────────────────────────────────────────────────
class _LiquidGlassPill extends StatelessWidget {
  const _LiquidGlassPill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            blurRadius: 0,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── CTA Button ────────────────────────────────────────────────────────────────
class _CTAButton extends StatefulWidget {
  const _CTAButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_CTAButton> createState() => _CTAButtonState();
}

class _CTAButtonState extends State<_CTAButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(widget.label,
                style: const TextStyle(
                  color: _black,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                )),
          ),
        ),
      ),
    );
  }
}

// ── Testimonial Section ───────────────────────────────────────────────────────
class _TestimonialSection extends StatefulWidget {
  const _TestimonialSection();

  @override
  State<_TestimonialSection> createState() => _TestimonialSectionState();
}

class _TestimonialSectionState extends State<_TestimonialSection> {
  final _key = GlobalKey();
  double _revealFraction = 0;

  static const _quote =
      'Puls Market completely changed how I look at crypto. '
      'Swiping on market predictions is incredibly fun, '
      'and I\'m earning rewards faster than I ever imagined! '
      'Puls Market completely changed the game.';

  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to attach scroll listener via ancestor
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateReveal());
  }

  void _updateReveal() {
    if (!mounted) return;
    final ctx = _key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final screenH = MediaQuery.sizeOf(context).height;
    final sectionH = box.size.height;
    // fraction: 0 when section enters bottom, 1 when section center reaches screen center
    final fraction = ((screenH - pos.dy) / (screenH + sectionH * 0.5)).clamp(0.0, 1.0);
    if ((fraction - _revealFraction).abs() > 0.001) {
      setState(() => _revealFraction = fraction);
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = _quote.split(' ');
    final total = words.length;

    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _updateReveal();
        return false;
      },
      child: Container(
        key: _key,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 112, vertical: 128),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quote symbol
                const Text('"',
                    style: TextStyle(
                      color: _white,
                      fontSize: 80,
                      height: 0.8,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 32),

                // Scroll-driven word reveal
                Wrap(
                  children: List.generate(total, (i) {
                    final wordFraction = (i / total);
                    final t = ((_revealFraction - wordFraction) * total).clamp(0.0, 1.0);
                    final color = Color.lerp(
                      const Color(0xFF595959),
                      _white,
                      t,
                    )!;
                    return Text(
                      '${words[i]} ',
                      style: TextStyle(
                        color: color,
                        fontSize: 40,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                        letterSpacing: -0.5,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 40),

                // Author
                Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _white, width: 3),
                        color: const Color(0xFF1a1a2e),
                      ),
                      child: const Center(
                        child: Text('A',
                            style: TextStyle(
                              color: _white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Alex Carter',
                            style: TextStyle(
                              color: _white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            )),
                        SizedBox(height: 2),
                        Text('Top Ranked Predictor',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            )),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 64),

                // Final CTA
                Center(
                  child: _CTAButton(
                    label: 'Start Predicting →',
                    onTap: PulsStateScope.of(context).completeOnboarding,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
