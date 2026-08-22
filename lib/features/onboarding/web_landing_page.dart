import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/glass_card.dart';
import '../../core/widgets/copy_button.dart';
import '../../core/widgets/dot_grid_painter.dart';

import 'live_activity.dart';
import 'live_ticker.dart';
import 'meet_the_agents.dart';
import 'live_traction.dart';
import 'landing_faq.dart';
import 'accountable_ai.dart';
import 'phone_demo.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/anim/pulse_governor.dart';

import '../../app/puls_app_state.dart';
import '../../app/puls_app.dart';
import 'hero_market_stack.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/motion.dart';
import '../../core/config.dart';

class WebLandingPage extends StatefulWidget {
  const WebLandingPage({super.key});

  @override
  State<WebLandingPage> createState() => _WebLandingPageState();
}

class _WebLandingPageState extends State<WebLandingPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _scrollCtrl = ScrollController();
  // Scroll offset as a ValueNotifier so scroll-driven UI (hero parallax,
  // progress bars, sticky navbar, reveal/lazy triggers) rebuilds locally via
  // ValueListenableBuilder WITHOUT rebuilding the whole page tree вЂ” and thus
  // re-laying-out every section of this ~10k-px column вЂ” on every scroll tick.
  final _scrollOffset = ValueNotifier<double>(0);
  int _lastScrollNotified = 0;
  static const _scrollThrottleMs = 50; // ~20 updates/s max for scroll effects
  late final AnimationController _aurora;
  // Hoisted merge of the aurora + cursor listenables вЂ” built once instead of
  // allocating a new Listenable on every build().
  late final Listenable _auroraListenable;
  // Normalized cursor position (-0.5..0.5 on each axis) for the reactive aurora.
  // A ValueNotifier so mouse moves repaint only the aurora, not the whole page.
  final _pointer = ValueNotifier<Offset>(Offset.zero);
  Offset _lastPointerSent = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The aurora loops continuously; its start/stop is gated on reduce-motion
    // in build() so motion-sensitive users get a single still frame.
    _aurora =
        AnimationController(vsync: this, duration: const Duration(seconds: 24));
    _auroraListenable = Listenable.merge([_aurora, _pointer]);
    // Throttled scroll listener: the notifier fires at most ~20Г—/s instead of
    // once per scroll pixel. Only the scroll-driven leaf widgets (progress bar,
    // hero parallax, sticky navbar, reveal/lazy triggers) listen to it, so a
    // scroll frame never rebuilds вЂ” or re-lays-out вЂ” the whole page.
    _scrollCtrl.addListener(() {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastScrollNotified < _scrollThrottleMs) return;
      _lastScrollNotified = now;
      _scrollOffset.value = _scrollCtrl.offset;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aurora.dispose();
    _scrollCtrl.dispose();
    _scrollOffset.dispose();
    _pointer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On web, hidden/paused fires when the tab loses visibility. Stop the
    // aurora (the only always-running animation) so a background tab burns
    // zero frames; resume when the tab comes back.
    final visible = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (!visible) {
      if (_aurora.isAnimating) _aurora.stop();
    } else if (!_aurora.isAnimating && !context.reduceMotion) {
      _aurora.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = context.isDark;

    // Honor the OS "reduce motion" setting: hold the aurora on a single static
    // frame instead of looping forever. Every other animated surface in the app
    // already respects this (shimmer, skeletons, pulse dots, page routes) вЂ” the
    // landing page was the one gap.
    if (context.reduceMotion) {
      if (_aurora.isAnimating) _aurora.stop();
    } else if (!_aurora.isAnimating) {
      _aurora.repeat();
    }

    final dotColor = isDark
        ? PulsColors.brandMint.withValues(alpha: 0.045)
        : PulsColors.brandPink.withValues(alpha: 0.04);
    final size = MediaQuery.sizeOf(context);
    final w = size.width;

    return Scaffold(
      backgroundColor: t.bg,
      body: MouseRegion(
        opaque: false,
        onHover: (e) {
          if (context.reduceMotion) return;
          if (size.width == 0 || size.height == 0) return;
          final p = Offset(
            e.position.dx / size.width - 0.5,
            e.position.dy / size.height - 0.5,
          );
          // Only notify the aurora when the cursor actually moved (>= ~2% of
          // an axis). A still mouse repaints nothing, and frantic sweeping is
          // decimated to a few parallax steps per frame instead of every
          // pointer event.
          if ((p - _lastPointerSent).distance < 0.01) return;
          _lastPointerSent = p;
          _pointer.value = p;
        },
        child: Stack(
          children: [
            // в”Ђв”Ђ Animated, cursor-reactive Aurora в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
            // RepaintBoundary isolates the 60fps aurora repaints from the
            // rest of the Stack (content, dot grid, grain) so they don't
            // re-rasterize on every animation tick. Excluded from semantics.
            //
            // The painter runs at HALF resolution (a 4Г— reduction in fragment
            // work for the radial gradients) and the layer is upscaled by the
            // compositor вЂ” for a soft, blurred glow this is visually identical
            // but dramatically cheaper on weak GPUs. Rasterized once per
            // animation tick into a half-size RepaintBoundary layer.
            Positioned.fill(
              child: ExcludeSemantics(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Transform.scale(
                    scale: 2,
                    child: SizedBox(
                      width: size.width / 2,
                      height: size.height / 2,
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _auroraListenable,
                          builder: (context, _) => CustomPaint(
                            painter: _AuroraPainter(
                              progress: _aurora.value,
                              isDark: isDark,
                              bg: t.bg,
                              pointer: _pointer.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // в”Ђв”Ђ Dot Grid в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
            // Static painter вЂ” RepaintBoundary ensures it's rasterized once
            // and never repainted when siblings change.
            Positioned.fill(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(painter: DotGridPainter(color: dotColor)),
                ),
              ),
            ),
            // в”Ђв”Ђ Film grain (depth) в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
            // Static painter вЂ” same treatment as the dot grid.
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _GrainPainter(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.025),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // в”Ђв”Ђ Atmospheric Parallax Layer в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
            // Floating ambient gradient orbs with hardware-accelerated transforms
            _ParallaxAtmosphereLayer(scrollOffset: _scrollOffset),
            // в”Ђв”Ђ Content в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
            SingleChildScrollView(
              controller: _scrollCtrl,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Column(
                children: [
                  RepaintBoundary(
                      child: _HeroSection(scrollOffset: _scrollOffset)),
                  _LazySection(
                    scrollOffset: _scrollOffset,
                    estimatedHeight: 140,
                    builder: (_) => _Reveal(
                      scrollOffset: _scrollOffset,
                      child: const RepaintBoundary(child: LiveMarketTicker()),
                    ),
                  ),
                  const _SectionDivider(),
                  _Reveal(
                      scrollOffset: _scrollOffset,
                      child:
                          const RepaintBoundary(child: _HowItWorksSection())),
                  _Reveal(
                      scrollOffset: _scrollOffset,
                      child: RepaintBoundary(
                          child:
                              _FeaturesSection(scrollOffset: _scrollOffset))),
                  const _SectionDivider(),
                  _Reveal(
                      scrollOffset: _scrollOffset,
                      child: const RepaintBoundary(
                          child: AccountableAiSection())),
                  _LazySection(
                    scrollOffset: _scrollOffset,
                    estimatedHeight: 640,
                    builder: (_) => _Reveal(
                      scrollOffset: _scrollOffset,
                      child: const RepaintBoundary(child: PhoneDemoSection()),
                    ),
                  ),
                  _LazySection(
                    scrollOffset: _scrollOffset,
                    estimatedHeight: 560,
                    builder: (_) => _Reveal(
                      scrollOffset: _scrollOffset,
                      child: const RepaintBoundary(
                          child: MeetTheAgentsSection()),
                    ),
                  ),
                  const _SectionDivider(),
                  _LazySection(
                    scrollOffset: _scrollOffset,
                    estimatedHeight: 480,
                    builder: (_) => _Reveal(
                      scrollOffset: _scrollOffset,
                      child:
                          const RepaintBoundary(child: LiveTractionSection()),
                    ),
                  ),
                  _LazySection(
                    scrollOffset: _scrollOffset,
                    estimatedHeight: 420,
                    builder: (_) => _Reveal(
                      scrollOffset: _scrollOffset,
                      child:
                          const RepaintBoundary(child: LiveActivitySection()),
                    ),
                  ),
                  _LazySection(
                    scrollOffset: _scrollOffset,
                    estimatedHeight: 380,
                    builder: (_) => _Reveal(
                      scrollOffset: _scrollOffset,
                      child: const RepaintBoundary(child: _StatsSection()),
                    ),
                  ),
                  const _SectionDivider(),
                  _LazySection(
                    scrollOffset: _scrollOffset,
                    estimatedHeight: 520,
                    builder: (_) => _Reveal(
                      scrollOffset: _scrollOffset,
                      child: const RepaintBoundary(child: FaqSection()),
                    ),
                  ),
                  _LazySection(
                    scrollOffset: _scrollOffset,
                    estimatedHeight: 360,
                    builder: (_) => _Reveal(
                      scrollOffset: _scrollOffset,
                      child: const RepaintBoundary(child: _FinalCtaSection()),
                    ),
                  ),
                  _LazySection(
                    scrollOffset: _scrollOffset,
                    estimatedHeight: 280,
                    builder: (_) => PulseVisibilityGate(
                      scrollOffset: _scrollOffset,
                      child: RepaintBoundary(
                          child: _FooterSection(scrollCtrl: _scrollCtrl)),
                    ),
                  ),
                ],
              ),
            ),
            // в”Ђв”Ђ Scroll progress bar (top) в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
            // Listens to the scroll notifier directly so it never rebuilds the
            // page вЂ” only this 3px strip.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  builder: (context, scrollOffset, _) {
                    final maxExtent = _scrollCtrl.hasClients &&
                            _scrollCtrl.position.hasContentDimensions
                        ? _scrollCtrl.position.maxScrollExtent
                        : 0.0;
                    final progress = maxExtent > 0
                        ? (scrollOffset / maxExtent).clamp(0.0, 1.0)
                        : 0.0;
                    return SizedBox(
                      height: 3,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress == 0 ? 0.0001 : progress,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: PulsColors.pulseGradient,
                              boxShadow: [
                                BoxShadow(
                                    color: Color(0x66F65FA9), blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // в”Ђв”Ђ Sticky navbar (frosted glass, condenses on scroll) в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _StickyNavbar(scrollOffset: _scrollOffset),
            ),
            // в”Ђв”Ђ Scrollytelling 2.0 Chapter Navigator (Desktop >= 1180) в”Ђв”Ђв”Ђв”Ђ
            if (w >= 1180)
              Positioned(
                right: 22,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ScrollyChapterHUD(
                    scrollOffset: _scrollOffset,
                    scrollCtrl: _scrollCtrl,
                  ),
                ),
              )
            else
              // в”Ђв”Ђ Vertical scroll progress rail (mobile/tablet right edge) в”Ђв”Ђ
              Positioned(
                top: 64,
                bottom: 64,
                right: 1,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _scrollOffset,
                      builder: (context, scrollOffset, _) {
                        final maxExtent = _scrollCtrl.hasClients &&
                                _scrollCtrl.position.hasContentDimensions
                            ? _scrollCtrl.position.maxScrollExtent
                            : 0.0;
                        final progress = maxExtent > 0
                            ? (scrollOffset / maxExtent).clamp(0.0, 1.0)
                            : 0.0;
                        return SizedBox(
                          width: 3,
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: t.border.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),
                              ),
                              FractionallySizedBox(
                                alignment: Alignment.topCenter,
                                heightFactor: progress == 0 ? 0.0001 : progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF34E5C0),
                                        Color(0xFFF65FA9),
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.all(
                                        Radius.circular(100)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: PulsColors.brandPink
                                            .withValues(alpha: 0.5),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Same-origin URL for the flagship static pages (/pulse, /agent, /versus, /stats),
// resolved against the current origin so the links work in prod, on Vercel
// previews and locally.
String _pageUrl(String path) => Uri.base.resolve(path).toString();

/// Opens [url] in a new browser tab; never throws into the landing page.
void _openExternal(String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

// в”Ђв”Ђ Scrollytelling 2.0: Atmospheric Parallax Layer в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _ParallaxAtmosphereLayer extends StatelessWidget {
  const _ParallaxAtmosphereLayer({required this.scrollOffset});
  final ValueNotifier<double> scrollOffset;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return const SizedBox.shrink();
    final t = context.puls;
    final isDark = context.isDark;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ValueListenableBuilder<double>(
          valueListenable: scrollOffset,
          builder: (context, offset, _) {
            final dy1 = -(offset * 0.08);
            final dy2 = -(offset * 0.14);
            return Stack(
              children: [
                Positioned(
                  top: 260,
                  right: -80,
                  child: RepaintBoundary(
                    child: Transform.translate(
                      offset: Offset(0, dy1),
                      child: Container(
                        width: 480,
                        height: 480,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              t.brand.withValues(alpha: isDark ? 0.065 : 0.035),
                              t.brand.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 1350,
                  left: -120,
                  child: RepaintBoundary(
                    child: Transform.translate(
                      offset: Offset(0, dy2),
                      child: Container(
                        width: 520,
                        height: 520,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF34E5C0)
                                  .withValues(alpha: isDark ? 0.055 : 0.03),
                              const Color(0xFF34E5C0).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 2700,
                  right: -100,
                  child: RepaintBoundary(
                    child: Transform.translate(
                      offset: Offset(0, dy1 * 0.75),
                      child: Container(
                        width: 500,
                        height: 500,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF8B5CF6)
                                  .withValues(alpha: isDark ? 0.05 : 0.025),
                              const Color(0xFF8B5CF6).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// в”Ђв”Ђ Scrollytelling 2.0: Chapter Navigation HUD в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _ScrollyChapterHUD extends StatefulWidget {
  const _ScrollyChapterHUD({
    required this.scrollOffset,
    required this.scrollCtrl,
  });

  final ValueNotifier<double> scrollOffset;
  final ScrollController scrollCtrl;

  @override
  State<_ScrollyChapterHUD> createState() => _ScrollyChapterHUDState();
}

class _ScrollyChapterHUDState extends State<_ScrollyChapterHUD> {
  int? _hoveredIndex;

  static const _chapters = [
    (
      id: '01',
      title: 'Genesis',
      subtitle: 'First Autonomous Prediction Market',
      offset: 0.0,
    ),
    (
      id: '02',
      title: 'Live Stream',
      subtitle: 'Realtime AI Spreads & Odds on Arc',
      offset: 720.0,
    ),
    (
      id: '03',
      title: 'Architecture',
      subtitle: 'AgentBond & 3-Step Instant Flow',
      offset: 1320.0,
    ),
    (
      id: '04',
      title: 'AI Roster',
      subtitle: 'Meet Pulse, Sage, Nexus & Astra',
      offset: 2450.0,
    ),
    (
      id: '05',
      title: 'Settlement',
      subtitle: 'Sub-Second Arc Engine & Proof',
      offset: 3350.0,
    ),
    (
      id: '06',
      title: 'Mainnet',
      subtitle: 'Terminal, FAQ & Launch App',
      offset: 4300.0,
    ),
  ];

  int _getActiveChapter(double scroll) {
    if (scroll < 500) return 0;
    if (scroll < 1050) return 1;
    if (scroll < 2000) return 2;
    if (scroll < 2900) return 3;
    if (scroll < 3900) return 4;
    return 5;
  }

  void _scrollTo(double offset) {
    widget.scrollCtrl.animateTo(
      offset,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = context.isDark;

    return ValueListenableBuilder<double>(
      valueListenable: widget.scrollOffset,
      builder: (context, offset, _) {
        final activeIdx = _getActiveChapter(offset);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          decoration: BoxDecoration(
            color:
                (isDark ? Colors.black : Colors.white).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: t.border.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _chapters.length; i++) ...[
                if (i > 0)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 2,
                    height: 18,
                    color: i <= activeIdx
                        ? t.brand.withValues(alpha: 0.7)
                        : t.border.withValues(alpha: 0.35),
                  ),
                _buildNode(
                  index: i,
                  isActive: i == activeIdx,
                  chapter: _chapters[i],
                  t: t,
                  isDark: isDark,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNode({
    required int index,
    required bool isActive,
    required ({String id, String title, String subtitle, double offset})
        chapter,
    required PulsThemeColors t,
    required bool isDark,
  }) {
    final isHovered = _hoveredIndex == index;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: () => _scrollTo(chapter.offset),
        child: Stack(
          alignment: Alignment.centerRight,
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: isActive ? 22 : 14,
              height: isActive ? 22 : 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? t.brand
                    : (isHovered
                        ? t.brand.withValues(alpha: 0.6)
                        : t.border.withValues(alpha: 0.6)),
                border: Border.all(
                  color: isActive ? Colors.white : Colors.transparent,
                  width: isActive ? 2.5 : 0,
                ),
                boxShadow: isActive || isHovered
                    ? [
                        BoxShadow(
                          color: t.brand.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: isActive
                  ? Center(
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
            if (isHovered)
              Positioned(
                right: 32,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: isHovered ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    constraints: const BoxConstraints(maxWidth: 220),
                    decoration: BoxDecoration(
                      color: t.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: t.brand.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              chapter.id,
                              style: TextStyle(
                                color: t.brand,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              chapter.title,
                              style: TextStyle(
                                color: t.text,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          chapter.subtitle,
                          style: TextStyle(
                            color: t.textMuted,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// в”Ђв”Ђ Top Navigation Bar (Header) в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _StickyNavbar extends StatelessWidget {
  const _StickyNavbar({required this.scrollOffset});
  final ValueNotifier<double> scrollOffset;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: scrollOffset,
      builder: (context, offset, _) => _StickyNavbarContent(
        scrollOffset: offset,
      ),
    );
  }
}

class _StickyNavbarContent extends StatelessWidget {
  const _StickyNavbarContent({required this.scrollOffset});
  final double scrollOffset;

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final isDark = context.isDark;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 880;

    final isScrolled = scrollOffset > 15;

    return Align(
      alignment: Alignment.topCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.fromLTRB(
          isMobile ? 12 : 24,
          isScrolled ? (isMobile ? 8 : 12) : (isMobile ? 12 : 16),
          isMobile ? 12 : 24,
          0,
        ),
        constraints: const BoxConstraints(maxWidth: 1240),
        decoration: BoxDecoration(
          color: isScrolled
              ? t.bg.withValues(alpha: 0.88)
              : (isDark
                  ? Colors.black.withValues(alpha: 0.32)
                  : Colors.white.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(isMobile ? 18 : 999),
          border: Border.all(
            color: isScrolled
                ? t.border.withValues(alpha: 0.65)
                : t.border.withValues(alpha: 0.3),
          ),
          boxShadow: isScrolled
              ? [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.45)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isMobile ? 18 : 999),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 24,
              vertical: isMobile ? 8 : 10,
            ),
            child: Row(
              children: [
                // Logo + wordmark
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isMobile ? 26 : 28,
                      height: isMobile ? 26 : 28,
                      decoration: BoxDecoration(
                        color: t.brandSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/logo.png',
                          fit: BoxFit.cover, cacheWidth: 112),
                    ),
                    SizedBox(width: isMobile ? 8 : 10),
                    Text(
                      'Puls',
                      style: TextStyle(
                        fontFamily: PulsColors.fontDisplay,
                        color: t.text,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Full nav links вЂ” visible on desktop
                if (!isMobile) ...[
                  _NavDropdown(
                    label: 'Product',
                    items: [
                      ('Pulse', _pageUrl('/pulse')),
                      ('Agent', _pageUrl('/agent')),
                      ('Versus', _pageUrl('/versus')),
                      ('Explorer', _pageUrl('/explorer')),
                    ],
                  ),
                  const SizedBox(width: 4),
                  _NavDropdown(
                    label: 'Developers',
                    items: [
                      ('Docs', 'https://docs.pulsmarket.tech'),
                      ('CLI', _pageUrl('/cli')),
                      ('Build', _pageUrl('/build')),
                      ('GitHub', 'https://github.com/rdmbtc/Puls'),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const _NavDropdown(
                    label: 'Mainnet',
                    items: [
                      ('Countdown', 'https://mainnet.pulsmarket.tech'),
                    ],
                  ),
                  const SizedBox(width: 4),
                  const _NavItemButton(
                    label: 'Invest',
                    url: 'https://invest.pulsmarket.tech',
                  ),
                  const SizedBox(width: 4),
                  _NavIcon(
                    icon: Icons.android_rounded,
                    url: _pageUrl('/mobile-download'),
                    tooltip: 'Download for Android',
                  ),
                  const SizedBox(width: 10),
                  _SecondaryButton(
                    label: 'Terminal',
                    onTap: () => launchUrl(
                      Uri.parse('https://terminal.pulsmarket.tech'),
                      mode: LaunchMode.externalApplication,
                    ),
                    small: true,
                  ),
                  const SizedBox(width: 8),
                ] else
                  const _MobileNavMenu(),
                // Always-visible controls
                IconButton(
                  onPressed: appState.toggleThemeMode,
                  icon: Icon(
                    isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    size: 18,
                    color: t.textMuted,
                  ),
                  tooltip: isDark ? 'Light mode' : 'Dark mode',
                ),
                SizedBox(width: isMobile ? 4 : 8),
                _PrimaryButton(
                  label: isMobile ? 'Launch' : 'Launch App',
                  onTap: () =>
                      appState.dismissWebLanding(terminal: false),
                  small: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A dropdown nav item: shows [label] with a chevron, expands a menu of links on hover/tap.
class _NavDropdown extends StatefulWidget {
  const _NavDropdown({required this.label, required this.items});
  final String label;
  final List<(String, String)> items;

  @override
  State<_NavDropdown> createState() => _NavDropdownState();
}

class _NavDropdownState extends State<_NavDropdown> {
  final _controller = MenuController();
  bool _hovered = false;
  Timer? _closeTimer;

  void _handleEnter() {
    _closeTimer?.cancel();
    if (!_hovered) setState(() => _hovered = true);
    if (!_controller.isOpen) _controller.open();
  }

  void _handleExit() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _hovered = false);
        if (_controller.isOpen) _controller.close();
      }
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _handleEnter(),
      onExit: (_) => _handleExit(),
      child: MenuAnchor(
        controller: _controller,
        alignmentOffset: const Offset(0, 6),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.surface),
          elevation: const WidgetStatePropertyAll(16),
          shadowColor:
              WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.35)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: t.border.withValues(alpha: 0.7)),
            ),
          ),
          padding:
              const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
        ),
        menuChildren: widget.items.map((item) {
          return MouseRegion(
            onEnter: (_) => _handleEnter(),
            onExit: (_) => _handleExit(),
            child: MenuItemButton(
              onPressed: () {
                _controller.close();
                launchUrl(Uri.parse(item.$2),
                    mode: LaunchMode.externalApplication);
              },
              style: ButtonStyle(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                ),
                overlayColor: WidgetStatePropertyAll(
                  t.brandSubtle.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                item.$1,
                style: TextStyle(
                  color: t.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
        builder: (context, controller, child) {
          return GestureDetector(
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      color:
                          _hovered || controller.isOpen ? t.brand : t.textMuted,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color:
                        _hovered || controller.isOpen ? t.brand : t.textMuted,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A standalone nav link button (used for top-level links like Invest).
class _NavItemButton extends StatefulWidget {
  const _NavItemButton({required this.label, required this.url});
  final String label;
  final String url;

  @override
  State<_NavItemButton> createState() => _NavItemButtonState();
}

class _NavItemButtonState extends State<_NavItemButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse(widget.url),
          mode: LaunchMode.externalApplication,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? t.brand : t.textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// A small icon-only nav button (used for the Android download link).
class _NavIcon extends StatefulWidget {
  const _NavIcon(
      {required this.icon, required this.url, required this.tooltip});
  final IconData icon;
  final String url;
  final String tooltip;

  @override
  State<_NavIcon> createState() => _NavIconState();
}

class _NavIconState extends State<_NavIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(widget.url),
              mode: LaunchMode.externalApplication),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Icon(
              widget.icon,
              size: 18,
              color: _hovered ? t.brand : t.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// Compact dropdown for mobile, where inline nav links don't fit. Surfaces the
// flagship pages + key links so judges on a phone can still discover them.
class _MobileNavMenu extends StatefulWidget {
  const _MobileNavMenu();

  @override
  State<_MobileNavMenu> createState() => _MobileNavMenuState();
}

class _MobileNavMenuState extends State<_MobileNavMenu> {
  bool _open = false;

  void _setOpen(bool value) {
    if (_open == value) return;
    setState(() => _open = value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final reduce = context.reduceMotion;

    return PopupMenuButton<String>(
      tooltip: 'Menu',
      onOpened: () => _setOpen(true),
      onCanceled: () => _setOpen(false),
      onSelected: (url) {
        _setOpen(false);
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      color: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.border),
      ),
      itemBuilder: (context) => [
        _item(t, 'Live agent', _pageUrl('/pulse')),
        _item(t, 'Decision trace', _pageUrl('/agent')),
        _item(t, 'Humans vs AI', _pageUrl('/versus')),
        _item(t, 'CLI', _pageUrl('/cli')),
        _item(t, 'Android app', _pageUrl('/mobile-download')),
        _item(t, 'Build an agent', _pageUrl('/build')),
        _item(t, 'Economy Explorer', _pageUrl('/explorer')),
        _item(t, 'Live stats', _pageUrl('/stats')),
        _item(t, 'Mainnet countdown', 'https://mainnet.pulsmarket.tech'),
        _item(t, 'Docs', 'https://docs.pulsmarket.tech'),
        _item(t, 'GitHub', 'https://github.com/rdmbtc/Puls'),
      ],
      // Icon well that morphs between hamburger and close while the menu is open.
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 260),
        curve: PulsCurves.easeOutMagical,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _open ? t.brand.withValues(alpha: 0.16) : t.brandSubtle,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: _open
                ? t.brand.withValues(alpha: 0.4)
                : t.border.withValues(alpha: 0.6),
          ),
        ),
        child: AnimatedRotation(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
          turns: _open ? 0.5 : 0,
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration:
                reduce ? Duration.zero : const Duration(milliseconds: 160),
            child: Icon(
              _open ? Icons.close_rounded : Icons.menu_rounded,
              key: ValueKey(_open),
              size: 20,
              color: _open ? t.brand : t.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(PulsThemeColors t, String label, String url) =>
      PopupMenuItem<String>(
        value: url,
        height: 42,
        child: Text(
          label,
          style: TextStyle(
              color: t.text, fontSize: 14, fontWeight: FontWeight.w600),
        ),
      );
}

// в”Ђв”Ђ Hero Section в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
const String kAndroidApkUrl = 'https://github.com/rdmbtc/Puls/releases/latest';

class _HeroSection extends StatefulWidget {
  const _HeroSection({required this.scrollOffset});
  final ValueNotifier<double> scrollOffset;

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  int _phraseIndex = 0;
  static const _phrases = [
    'accountable AI.',
    'skin in the game.',
    'trustworthy agents.',
  ];

  @override
  void initState() {
    super.initState();
    _cyclePhrases();
  }

  void _cyclePhrases() {
    // Give the first phrase a longer beat before rotating вЂ” a fast first
    // impression (a few seconds) should land on the strongest line and hold,
    // not catch a mid-rotation frame.
    final delay = _phraseIndex == 0 ? 6500 : 3200;
    Future.delayed(Duration(milliseconds: delay), () {
      if (!mounted) return;
      // Reduce-motion: stop cycling and keep a single stable headline.
      if (context.reduceMotion) return;
      setState(() => _phraseIndex = (_phraseIndex + 1) % _phrases.length);
      _cyclePhrases();
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 1000;
    // Local listener: scrolling rebuilds only the hero (parallax + crossfade),
    // never the rest of the page.
    return ValueListenableBuilder<double>(
      valueListenable: widget.scrollOffset,
      builder: (context, scrollOffset, _) {
        if (scrollOffset > h * 0.65) {
          // Offscreen culling: When scrolled past the hero, render a simple empty
          // box to preserve scroll extent, skipping expensive hero subtree rebuilds.
          final heroH = math.max(680.0, h - 80.0);
          return SizedBox(height: isMobile ? heroH * 0.9 : heroH);
        }
        // Reduce-motion: drop the scroll parallax (keep the gentle fade so the
        // hero still clears the content scrolling up beneath it).
        final parallaxY = context.reduceMotion
            ? 0.0
            : -(scrollOffset * 0.18).clamp(0.0, h * 0.25);
        final heroOpacity = (1 - scrollOffset / (h * 0.55)).clamp(0.0, 1.0);

        return _buildHero(
          h: h,
          isMobile: isMobile,
          scrollOffset: scrollOffset,
          parallaxY: parallaxY,
          heroOpacity: heroOpacity,
        );
      },
    );
  }

  Widget _buildHero({
    required double h,
    required bool isMobile,
    required double scrollOffset,
    required double parallaxY,
    required double heroOpacity,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: h),
      child: Stack(
        children: [
          // Hero content with parallax
          Padding(
            padding: EdgeInsets.only(top: isMobile ? 110 : 90),
            child: Transform.translate(
              offset: Offset(0, parallaxY),
              child: Opacity(
                opacity: heroOpacity,
                child: context.reduceMotion
                    ? _HeroContent(
                        phrase: _phrases[_phraseIndex],
                        phraseIndex: _phraseIndex,
                      )
                    : _HeroContent(
                        phrase: _phrases[_phraseIndex],
                        phraseIndex: _phraseIndex,
                      )
                        .animate(
                          key: const ValueKey('hero-entrance'),
                        )
                        .fadeIn(
                          duration: 750.ms,
                          delay: 100.ms,
                          curve: PulsCurves.easeOutMagical,
                        )
                        .slideY(
                          begin: 0.06,
                          end: 0,
                          duration: 750.ms,
                          delay: 100.ms,
                          curve: PulsCurves.easeOutMagical,
                        ),
              ),
            ),
          ),
          // Scroll cue вЂ” pinned to the very bottom, below the trust strip.
          // Positioned at bottom: 6 (was 22) so it never overlaps the trust
          // strip row above it. Fades out as the hero scrolls away.
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: heroOpacity * 0.7,
                child: const Center(child: _ScrollCue()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  const _HeroContent({required this.phrase, required this.phraseIndex});
  final String phrase;
  final int phraseIndex;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 1000;
    final h = MediaQuery.sizeOf(context).height;

    if (isMobile) {
      return SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _HeroCopy(
                  phrase: phrase, phraseIndex: phraseIndex, centered: true),
            ),
            const SizedBox(height: 40),
            const Center(child: HeroMarketStack(compact: true)),
            const SizedBox(height: 36),
            const _TrustStrip(),
            const SizedBox(height: 32),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 1240, minHeight: h - 90),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 11,
                    child: _HeroCopy(
                        phrase: phrase,
                        phraseIndex: phraseIndex,
                        centered: false),
                  ),
                  const SizedBox(width: 48),
                  const Expanded(
                    flex: 9,
                    child: Center(child: HeroMarketStack()),
                  ),
                ],
              ),
              const SizedBox(height: 56),
              const _TrustStrip(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy(
      {required this.phrase,
      required this.phraseIndex,
      required this.centered});
  final String phrase;
  final int phraseIndex;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final isDark = context.isDark;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 1000;
    final double titleSize =
        w < 480 ? 44 : (w < 1000 ? 56 : (w < 1250 ? 64 : 74));

    final cross =
        centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final align = centered ? TextAlign.center : TextAlign.left;

    return Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Live badge
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
              _PulsingDot(color: t.brand),
              const SizedBox(width: 8),
              Text(
                'LIVE ON ARCв„ў NETWORK',
                style: TextStyle(
                    color: t.brand,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2),
              ),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOutCubic),
        SizedBox(height: isMobile ? 22 : 30),
        // Editorial serif headline
        Text(
          'The market for',
          textAlign: align,
          style: TextStyle(
            fontFamily: PulsColors.fontDisplay,
            color: t.text,
            fontSize: titleSize,
            fontWeight: FontWeight.w600,
            height: 1.04,
            letterSpacing: -1.5,
            shadows: isDark
                ? [
                    Shadow(
                      color: PulsColors.brandPinkDark.withValues(alpha: 0.18),
                      blurRadius: 32,
                    ),
                  ]
                : null,
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 60.ms).slideY(
            begin: 0.18,
            end: 0,
            duration: 500.ms,
            delay: 60.ms,
            curve: Curves.easeOutCubic),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.35), end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: AnimatedGradientText(
            phrase,
            key: ValueKey(phraseIndex),
            textAlign: align,
            style: TextStyle(
              fontFamily: PulsColors.fontDisplay,
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              height: 1.08,
              letterSpacing: -1.5,
            ),
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 180.ms).slideY(
            begin: 0.15,
            end: 0,
            duration: 500.ms,
            delay: 180.ms,
            curve: Curves.easeOutCubic),
        SizedBox(height: isMobile ? 18 : 26),
        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            'A mobile prediction market on Arc. Swipe to trade real-world events in USDC '
            'вЂ” no seed phrase. AI agents trade alongside you, staking real USDC on every '
            'call вЂ” slashed when wrong, returned when right.',
            textAlign: align,
            style: TextStyle(
              color: t.textMuted,
              fontSize: isMobile ? 15 : 17,
              height: 1.65,
              fontWeight: FontWeight.w400,
            ),
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(
            begin: 0.12,
            end: 0,
            duration: 500.ms,
            delay: 300.ms,
            curve: Curves.easeOutCubic),
        SizedBox(height: isMobile ? 26 : 34),
        // CTAs
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: centered ? WrapAlignment.center : WrapAlignment.start,
          children: [
            Builder(builder: (context) {
              final wallet = WalletServiceScope.of(context);
              return _PrimaryButton(
                label:
                    wallet.state.isLoading ? 'ConnectingвЂ¦' : 'Get started free',
                onTap: wallet.state.isLoading ? null : wallet.signInWithGoogle,
              );
            }),
            Builder(builder: (context) {
              final wallet = WalletServiceScope.of(context);
              return _SecondaryButton(
                label: 'Connect wallet',
                onTap: () async {
                  await wallet.signInWithExternalWallet();
                  if (wallet.state.isExternalWallet && context.mounted) {
                    appState.dismissWebLanding();
                  }
                },
              );
            }),
          ],
        )
            .animate()
            .fadeIn(duration: 500.ms, delay: 420.ms)
            .slideY(
                begin: 0.08,
                end: 0,
                duration: 500.ms,
                delay: 420.ms,
                curve: Curves.easeOutCubic)
            .scaleXY(
                begin: 0.96,
                end: 1.0,
                duration: 500.ms,
                delay: 420.ms,
                curve: Curves.easeOutCubic),
        SizedBox(height: isMobile ? 14 : 18),
        // Tech depth lives in the docs вЂ” keep the hero to one clear idea.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_rounded, size: 15, color: t.textSubtle),
            const SizedBox(width: 6),
            const _InlineLink(
                label: 'Read the technical docs',
                url: 'https://docs.pulsmarket.tech'),
          ],
        ).animate().fadeIn(duration: 400.ms, delay: 540.ms),
        SizedBox(height: isMobile ? 12 : 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.android_rounded, size: 15, color: t.textSubtle),
            const SizedBox(width: 6),
            const _InlineLink(
                label: 'Get the Android app', url: kAndroidApkUrl),
            Text('  В·  No wallet, no seed phrase, no risk.',
                style: TextStyle(color: t.textSubtle, fontSize: 12.5)),
          ],
        ).animate().fadeIn(duration: 400.ms, delay: 580.ms),
      ],
    );
  }
}

class _InlineLink extends StatefulWidget {
  const _InlineLink({required this.label, required this.url});
  final String label;
  final String url;

  @override
  State<_InlineLink> createState() => _InlineLinkState();
}

class _InlineLinkState extends State<_InlineLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Semantics(
      link: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(widget.url),
              mode: LaunchMode.externalApplication),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: _hovered ? t.brand : t.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Animated underline вЂ” sweeps in from the left on hover.
              Positioned(
                left: 0,
                right: 0,
                bottom: -2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  height: 1.5,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _hovered ? 1.0 : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF34E5C0), Color(0xFFF65FA9)],
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
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

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // Repeat is gated on reduce-motion in build().
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _dot(double v) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.5 * v),
              blurRadius: 6 + 6 * v,
              spreadRadius: 1.5 * v,
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Reduce-motion: a still dot with a gentle fixed glow, no pulsing loop.
    if (context.reduceMotion) {
      if (_c.isAnimating) _c.stop();
      return _dot(0.6);
    }
    if (!_c.isAnimating) _c.repeat(reverse: true);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => _dot(_c.value),
      ),
    );
  }
}

// в”Ђв”Ђ Trust strip в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  static const _rails = [
    ('CIRCLE', 'MPC wallets & CCTP'),
    ('ARC', 'USDC-gas L1'),
    ('PULS GATEWAY', 'x402 payments'),
    ('INDEXNOW', 'instant indexing'),
    ('UMA', 'oracle settlement'),
    ('ERC-8004', 'agent identity'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 700;

    return Column(
      children: [
        Text(
          'BUILT ON REAL RAILS',
          style: TextStyle(
            color: t.textSubtle,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 0,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < _rails.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 22),
                  child: Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: t.brand.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _rails[i].$1,
                    style: TextStyle(
                      fontFamily: PulsColors.fontDisplay,
                      color: t.text.withValues(alpha: 0.75),
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _rails[i].$2,
                    style: TextStyle(
                      color: t.textSubtle,
                      fontSize: isMobile ? 10 : 11.5,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// в”Ђв”Ђ Features Section вЂ” premium bento в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// A curated, asymmetric bento grid replaces the old eight-up card wall. Each cell
// carries a bespoke, brand-coloured micro-animation that *demonstrates* the
// feature rather than parking it behind a flat icon. Every animated surface
// honours reduce-motion (holds a composed still frame) and is isolated behind a
// RepaintBoundary so the buttery lenis scroll never pays for it.
class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection({required this.scrollOffset});
  final ValueNotifier<double> scrollOffset;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 600;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48, vertical: isMobile ? 56 : 112),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              const _SectionEyebrow(label: 'THE AGENTBOND ECONOMY'),
              const SizedBox(height: 22),
              _GradientHeadline(
                lead: 'Agents stake USDC against each other вЂ”',
                accent: 'winner takes all on Arc.',
                isMobile: isMobile,
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  'Every AI agent on Puls backs its predictions with a USDC bond вЂ” slashed '
                  'on bad calls, returned on good ones. They pay each other for intelligence, '
                  'publish premium Signals, and settle on Arc in under a second. A closed-loop economy that runs itself.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: t.textMuted,
                      fontSize: isMobile ? 14.5 : 16.5,
                      height: 1.6),
                ),
              ),
              SizedBox(height: isMobile ? 38 : 66),
              _Bento(scrollOffset: scrollOffset),
              SizedBox(height: isMobile ? 30 : 44),
              const _CapabilityStrip(),
            ],
          ),
        ),
      ),
    );
  }
}

// в”Ђв”Ђ Section header pieces в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: t.brandSubtle,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: t.brand.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CachedGradientMask(
            gradient: PulsColors.pulseGradient,
            child:
                Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
                color: t.brand,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6),
          ),
        ],
      ),
    );
  }
}

class _GradientHeadline extends StatelessWidget {
  const _GradientHeadline(
      {required this.lead, required this.accent, required this.isMobile});
  final String lead;
  final String accent;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final size = isMobile ? 30.0 : 47.0;
    return Column(
      children: [
        Text(
          lead,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: PulsColors.fontDisplay,
            color: t.text,
            fontSize: size,
            fontWeight: FontWeight.w600,
            height: 1.06,
            letterSpacing: -1.4,
          ),
        ),
        AnimatedGradientText(
          accent,
          style: TextStyle(
            fontFamily: PulsColors.fontDisplay,
            fontSize: size,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
            height: 1.12,
            letterSpacing: -1.4,
          ),
        ),
      ],
    );
  }
}

// в”Ђв”Ђ How it works (3 quick steps) в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 760;
    final t = context.puls;
    const steps = [
      (
        Icons.login_rounded,
        '1',
        'Sign in with Google',
        'A Circle MPC wallet is created on Arc instantly вЂ” no seed phrase, no extension, no ETH.',
        '0.18s MPC KEYGEN',
      ),
      (
        Icons.water_drop_rounded,
        '2',
        'Fund with USDC',
        'Claim free USDC. On Arc, USDC is the gas token вЂ” one token pays for everything.',
        'USDC NATIVE GAS',
      ),
      (
        Icons.swipe_rounded,
        '3',
        'Swipe to trade',
        'Swipe right for YES, left for NO on any real-world market. Confirms on-chain in under a second.',
        '<500ms ARC FINALITY',
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48, vertical: isMobile ? 52 : 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              const _SectionEyebrow(label: 'HOW IT WORKS'),
              const SizedBox(height: 22),
              _GradientHeadline(
                lead: 'From zero to trading,',
                accent: 'in under a minute.',
                isMobile: isMobile,
              ),
              SizedBox(height: isMobile ? 36 : 64),
              if (isMobile)
                Column(
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _HowStep(
                        icon: steps[i].$1,
                        step: steps[i].$2,
                        title: steps[i].$3,
                        body: steps[i].$4,
                        badge: steps[i].$5,
                      ),
                    ],
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      if (i > 0) ...[
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(top: 50),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 22,
                                height: 2,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      t.brand.withValues(alpha: 0.2),
                                      t.brand,
                                    ],
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: t.brand,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: _HowStep(
                          icon: steps[i].$1,
                          step: steps[i].$2,
                          title: steps[i].$3,
                          body: steps[i].$4,
                          badge: steps[i].$5,
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowStep extends StatefulWidget {
  const _HowStep({
    required this.icon,
    required this.step,
    required this.title,
    required this.body,
    required this.badge,
  });
  final IconData icon;
  final String step;
  final String title;
  final String body;
  final String badge;

  @override
  State<_HowStep> createState() => _HowStepState();
}

class _HowStepState extends State<_HowStep> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: _hovered
            ? Matrix4.translationValues(0.0, -6.0, 0.0)
            : Matrix4.identity(),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _hovered ? t.brand.withValues(alpha: 0.55) : t.border,
            width: _hovered ? 1.5 : 1.0,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: t.brand.withValues(alpha: 0.2),
                    blurRadius: 32,
                    offset: const Offset(0, 14),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: PulsColors.pulseGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: t.brand.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 24),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.brandSubtle.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: t.brand.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    widget.badge,
                    style: TextStyle(
                      color: t.brand,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              widget.title,
              style: TextStyle(
                color: t.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.body,
              style: TextStyle(
                color: t.textMuted,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// в”Ђв”Ђ Bento layout в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _Bento extends StatefulWidget {
  const _Bento({required this.scrollOffset});
  final ValueNotifier<double> scrollOffset;

  @override
  State<_Bento> createState() => _BentoState();
}

class _BentoState extends State<_Bento> {
  bool _revealed = false;
  double? _top;

  @override
  void initState() {
    super.initState();
    // Scroll listener: the reveal check runs on scroll ticks WITHOUT a page
    // rebuild вЂ” and once revealed (or _top measured) the checks are pure
    // arithmetic, so scrolling never relayouts the bento.
    widget.scrollOffset.addListener(_maybeReveal);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeReveal());
  }

  @override
  void dispose() {
    widget.scrollOffset.removeListener(_maybeReveal);
    super.dispose();
  }

  void _maybeReveal() {
    if (!mounted || _revealed) return;
    if (context.reduceMotion) {
      setState(() => _revealed = true);
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    // Re-measure every tick: lazy sections above grow when they build, so the
    // content-space position shifts вЂ” a cached _top would go stale and fire
    // the reveal thousands of px early. (localToGlobal here is a cheap
    // transform walk, not a relayout.)
    _top = box.localToGlobal(Offset.zero).dy + widget.scrollOffset.value;
    final h = MediaQuery.sizeOf(context).height;
    if (widget.scrollOffset.value + h * 0.9 > _top!) {
      // Only setState on the actual flip вЂ” the parent no longer rebuilds on
      // scroll, so this single rebuild is the only one the bento ever does.
      setState(() => _revealed = true);
    }
  }

  // Staggered entrance per cell once the bento scrolls into view.
  Widget _cell(Widget cell, int i) {
    if (context.reduceMotion) return cell;
    if (!_revealed) return Opacity(opacity: 0, child: cell);
    final delay = (i * 80).ms;
    return cell.animate().fadeIn(duration: 460.ms, delay: delay).slideY(
        begin: 0.14,
        end: 0,
        duration: 540.ms,
        delay: delay,
        curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      const gap = 18.0;

      // Featured card leads with AgentBond вЂ” the core "skin in the game" primitive.
      const hero = _BentoCell(
        accent: Color(0xFFF59E0B),
        featured: true,
        eyebrow: 'AGENTBOND В· SKIN IN THE GAME',
        title: 'Every prediction is staked',
        body:
            'Each agent backs its call with a real USDC AgentBond, locked on-chain. '
            'Wrong call в†’ bond slashed. Right call в†’ returned, reputation rises. '
            'No cheap talk вЂ” reputation is capital at risk.',
        visual: _BondViz(),
      );
      const pay = _BentoCell(
        accent: Color(0xFFEC4899),
        eyebrow: 'x402 В· AGENT-TO-AGENT',
        title: 'Pay-per-read intelligence',
        body: 'Agents buy each other\'s Signals via USDC nanopayments '
            'before trading вЂ” a closed-loop market for on-chain alpha.',
        visual: _PayFlowViz(),
      );
      const bond = _BentoCell(
        accent: Color(0xFF2DD4BF),
        eyebrow: 'AUTONOMOUS В· NO HUMAN IN THE LOOP',
        title: 'Agents that decide, not automate',
        body:
            'Pulse researches live sources, reasons with citations, sizes by risk, '
            'and publishes a HOLD when there is no edge. Genuine agency, on-chain.',
        visual: _AgentDecideViz(),
      );
      const signal = _BentoCell(
        accent: Color(0xFF8B5CF6),
        eyebrow: 'CREATOR ECONOMY',
        title: 'Earn per read',
        body: 'Publish a premium Signal, attested on-chain, unlocked '
            'per read in USDC.',
        visual: _SignalUnlockViz(),
      );
      const director = _BentoCell(
        accent: Color(0xFF0EA5E9),
        eyebrow: 'FINANCE DIRECTOR В· x402 В· PAID',
        title: 'Your AI portfolio manager',
        body:
            'Pay in USDC and it reads your whole portfolio, then returns a risk-managed '
            'basket of +EV predicts sized to your balance вЂ” money-back if it loses.',
        visual: _DirectorViz(),
      );
      final swipe = _BentoCell(
        accent: const Color(0xFFF472B6),
        eyebrow: 'SUB-SECOND В· USDC GAS',
        title: 'Swipe to trade',
        body: 'Right for YES, left for NO вЂ” settled on Arc in under a '
            'second. No modal, no ETH, no seed phrase.',
        visual: const _SwipeViz(),
        horizontal: wide,
      );
      final gateway = _BentoCell(
        accent: const Color(0xFF3B82F6),
        eyebrow: 'PULS GATEWAY В· x402',
        title: 'Agents buy real-world data',
        body:
            'Agents use Circle MPC wallets to purchase verified macro and crypto intel via x402 nanopayments. No hallucination, just verified data.',
        visual: const _GatewayViz(),
        horizontal: wide,
      );
      final journal = _BentoCell(
        accent: const Color(0xFF10B981),
        eyebrow: 'THE PULS JOURNAL В· COMMUNITY & GROWTH',
        title: 'Agents are columnists',
        body:
            'Daily news analyses by the swarm вЂ” grounded in live web research '
            'with cited sources. Humans post too; great writing gets tipped in USDC.',
        visual: const _JournalViz(),
        horizontal: wide,
        onTap: () => _openExternal('https://docs.pulsmarket.tech/community/blog'),
      );
      final sponsor = _BentoCell(
        accent: const Color(0xFF22C55E),
        eyebrow: 'AGENT SPONSORSHIP В· PASSIVE YIELD',
        title: 'Sponsor an agent, share its profits',
        body:
            'Stake USDC into an AI agent and earn a share of its trading '
            'profits on Arc вЂ” it trades 24/7, you collect.',
        visual: const _SponsorViz(),
        horizontal: wide,
        onTap: () => _openExternal('https://invest.pulsmarket.tech/'),
      );

      if (!wide) {
        return Column(
          children: [
            SizedBox(height: 430, child: _cell(hero, 0)),
            const SizedBox(height: gap),
            SizedBox(height: 300, child: _cell(pay, 1)),
            const SizedBox(height: gap),
            SizedBox(height: 280, child: _cell(bond, 2)),
            const SizedBox(height: gap),
            SizedBox(height: 300, child: _cell(signal, 3)),
            const SizedBox(height: gap),
            SizedBox(height: 280, child: _cell(director, 4)),
            const SizedBox(height: gap),
            SizedBox(height: 300, child: _cell(gateway, 5)),
            const SizedBox(height: gap),
            SizedBox(height: 300, child: _cell(swipe, 6)),
            const SizedBox(height: gap),
            SizedBox(height: 280, child: _cell(journal, 7)),
            const SizedBox(height: gap),
            SizedBox(height: 280, child: _cell(sponsor, 8)),
          ],
        );
      }

      return Column(
        children: [
          SizedBox(
            height: 384,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 7, child: _cell(hero, 0)),
                const SizedBox(width: gap),
                Expanded(flex: 5, child: _cell(pay, 1)),
              ],
            ),
          ),
          const SizedBox(height: gap),
          SizedBox(
            height: 292,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _cell(bond, 2)),
                const SizedBox(width: gap),
                Expanded(child: _cell(signal, 3)),
                const SizedBox(width: gap),
                Expanded(child: _cell(director, 4)),
              ],
            ),
          ),
          const SizedBox(height: gap),
          SizedBox(height: 208, child: _cell(gateway, 5)),
          const SizedBox(height: gap),
          SizedBox(height: 208, child: _cell(swipe, 6)),
          const SizedBox(height: gap),
          SizedBox(
            height: 208,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _cell(journal, 7)),
                const SizedBox(width: gap),
                Expanded(child: _cell(sponsor, 8)),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _BentoCell extends StatefulWidget {
  const _BentoCell({
    required this.accent,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.visual,
    this.featured = false,
    this.horizontal = false,
    this.onTap,
  });
  final Color accent;
  final String eyebrow;
  final String title;
  final String body;
  final Widget visual;
  final bool featured;
  final bool horizontal;

  /// When set, the whole card is clickable (external link) and shows a subtle
  /// в†— affordance in the top-right corner.
  final VoidCallback? onTap;

  @override
  State<_BentoCell> createState() => _BentoCellState();
}

class _BentoCellState extends State<_BentoCell> {
  bool _hovered = false;
  // Cursor position as a ValueNotifier: mouse moves repaint only the spotlight
  // layer (via the painter's repaint listenable) instead of rebuilding the
  // whole card on every pointer event.
  final _cursor = ValueNotifier<Offset>(Offset.zero);

  @override
  void dispose() {
    _cursor.dispose();
    super.dispose();
  }

  Widget _wrapVisual(Widget v) =>
      ClipRect(child: SizedBox.expand(child: RepaintBoundary(child: v)));

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final a = widget.accent;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.eyebrow,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: a,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          widget.title,
          style: TextStyle(
            color: t.text,
            fontSize: widget.featured ? 23 : 17.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          widget.body,
          maxLines: widget.featured ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: t.textMuted,
            fontSize: widget.featured ? 14.5 : 12.8,
            height: 1.5,
          ),
        ),
      ],
    );

    final Widget content = widget.horizontal
        ? Row(
            children: [
              Expanded(
                flex: 5,
                child: Align(alignment: Alignment.centerLeft, child: text),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 6, child: _wrapVisual(widget.visual)),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _wrapVisual(widget.visual)),
              const SizedBox(height: 14),
              text,
            ],
          );

    final pad = widget.featured ? 24.0 : 20.0;

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      onHover: (e) {
        if (_hovered) _cursor.value = e.localPosition;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: _hovered
            ? Matrix4.translationValues(0.0, -4.0, 0.0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              t.surface,
              Color.alphaBlend(
                  a.withValues(alpha: widget.featured ? 0.07 : 0.04),
                  t.surface),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _hovered ? a.withValues(alpha: 0.5) : t.border,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                      color: a.withValues(alpha: 0.18),
                      blurRadius: 40,
                      offset: const Offset(0, 18))
                ]
              : [
                  BoxShadow(
                      color: t.text.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8))
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              if (_hovered)
                Positioned.fill(
                  child: IgnorePointer(
                    // Repaints in place via the cursor ValueNotifier вЂ” no
                    // rebuild on mouse move.
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _SpotlightPainter(center: _cursor, color: a),
                      ),
                    ),
                  ),
                ),
              Padding(padding: EdgeInsets.all(pad), child: content),
              // Link affordance for tappable cards.
              if (widget.onTap != null)
                Positioned(
                  top: pad - 4,
                  right: pad - 4,
                  child: Icon(
                    Icons.open_in_new_rounded,
                    size: 14,
                    color: _hovered ? a : a.withValues(alpha: 0.45),
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

// Soft accent glow that tracks the cursor вЂ” the signature "spotlight card" feel.
// Repaints via the [center] ValueNotifier (no widget rebuild per mouse move).
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(
      {required ValueListenable<Offset> center, required this.color})
      : _center = center,
        super(repaint: center);
  final ValueListenable<Offset> _center;
  final Color color;

  static final Map<int, Paint> _unitPaints = {};

  static Paint _unitPaint(Color c) {
    final key = c.toARGB32();
    return _unitPaints.putIfAbsent(key, () {
      return Paint()
        ..shader = RadialGradient(
          colors: [c.withValues(alpha: 0.15), c.withValues(alpha: 0.0)],
        ).createShader(const Rect.fromLTRB(-1.0, -1.0, 1.0, 1.0));
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = _center.value;
    final r = size.longestSide * 0.7;
    if (r <= 0) return;
    final paint = _unitPaint(color);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(r, r);
    canvas.drawRect(
      Rect.fromLTRB(-center.dx / r, -center.dy / r, (size.width - center.dx) / r, (size.height - center.dy) / r),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.color != color || old._center != _center;
}

// в”Ђв”Ђ Visual В· Puls Streams pay-per-second meter в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
// A live meter accruing USDC every second toward a cap вЂ” the "water meter" for
// value. Loops: flow ticks up, settles, resets. Honors reduce-motion.
class _StreamMeterViz extends StatefulWidget {
  const _StreamMeterViz();
  @override
  State<_StreamMeterViz> createState() => _StreamMeterVizState();
}

class _StreamMeterVizState extends State<_StreamMeterViz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  static const _accent = Color(0xFF22D3EE); // cyan вЂ” "flow"
  static const _cap = 0.5; // USDC cap shown

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 7));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final t = context.puls;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final p = reduce ? 0.62 : _c.value; // 0..1 fill of the meter
        final accrued = _cap * p; // USDC streamed so far
        final secs = accrued / 0.015; // at $0.015/sec
        final on = reduce ? true : (p * 6).floor().isEven; // live pulse
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: on ? _accent : _accent.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      boxShadow: on
                          ? [
                              BoxShadow(
                                  color: _accent.withValues(alpha: 0.6),
                                  blurRadius: 6)
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text('STREAMING В· live-alpha',
                      style: TextStyle(
                          color: t.textSubtle,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1)),
                  const Spacer(),
                  const Text('\$0.015/s',
                      style: TextStyle(
                          color: _accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 12),
              Text('\$${accrued.toStringAsFixed(3)}',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
              const SizedBox(height: 2),
              Text('${secs.toStringAsFixed(0)}s В· settled in USDC on Arc',
                  style: TextStyle(color: t.textMuted, fontSize: 11)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: p,
                  minHeight: 7,
                  backgroundColor: t.border,
                  valueColor: const AlwaysStoppedAnimation(_accent),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('rate Г— time',
                      style: TextStyle(
                          color: t.textSubtle,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700)),
                  Text('cap \$${_cap.toStringAsFixed(2)}',
                      style: TextStyle(
                          color: t.textSubtle,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// в”Ђв”Ђ Visual 1 В· the flagship decision engine в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _AgentDecideViz extends StatefulWidget {
  const _AgentDecideViz();
  @override
  State<_AgentDecideViz> createState() => _AgentDecideVizState();
}

class _AgentDecideVizState extends State<_AgentDecideViz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  static const _sources = ['Reuters', 'Polymarket', 'On-chain'];

  @override
  void initState() {
    super.initState();
    _c =
        AnimationController(vsync: this, duration: const Duration(seconds: 12));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final raw = reduce ? 0.85 : _c.value;
        final yes = raw < 0.5; // first half BUY YES, second half HOLD
        final localT = reduce ? 0.85 : (raw % 0.5) / 0.5;
        return _frame(context, localT, yes);
      },
    );
  }

  Widget _frame(BuildContext context, double localT, bool yes) {
    final t = context.puls;
    final confTarget = yes ? 0.78 : 0.46;
    final confFactor =
        Curves.easeOut.transform(((localT - 0.28) / 0.34).clamp(0.0, 1.0));
    final conf = confFactor * confTarget;
    final pct = (conf * 100).round();
    final showVerdict = localT > 0.66;
    final verdictColor = yes ? t.yes : PulsColors.amber;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.bg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _glowDot(t.yes),
              const SizedBox(width: 7),
              Text('SCANNING SOURCES',
                  style: TextStyle(
                      color: t.textSubtle,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < _sources.length; i++)
                _sourceChip(t, _sources[i],
                    ((localT - i * 0.09) / 0.12).clamp(0.0, 1.0)),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Text('CONFIDENCE',
                  style: TextStyle(
                      color: t.textSubtle,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0)),
              const Spacer(),
              Text('$pct%',
                  style: TextStyle(
                      color: t.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Stack(
                children: [
                  Container(height: 7, color: t.surfaceRaised),
                  FractionallySizedBox(
                    widthFactor: conf.clamp(0.0, 1.0),
                    child: Container(
                      height: 7,
                      decoration: const BoxDecoration(
                          gradient: PulsColors.pulseGradient),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: showVerdict ? 1 : 0,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: verdictColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                    border:
                        Border.all(color: verdictColor.withValues(alpha: 0.42)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          yes ? Icons.trending_up_rounded : Icons.pause_rounded,
                          size: 14,
                          color: verdictColor),
                      const SizedBox(width: 5),
                      Text(yes ? 'BUY YES' : 'HOLD',
                          style: TextStyle(
                              color: verdictColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(yes ? 'sized to bankroll' : 'no +EV edge',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: t.textSubtle, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowDot(Color c) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 5)
          ],
        ),
      );

  Widget _sourceChip(PulsThemeColors t, String label, double lit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color:
            Color.alphaBlend(t.brand.withValues(alpha: 0.10 * lit), t.surface),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.brand.withValues(alpha: 0.12 + 0.3 * lit)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 11, color: t.brand.withValues(alpha: 0.35 + 0.65 * lit)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: t.text.withValues(alpha: 0.5 + 0.5 * lit),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// в”Ђв”Ђ Visual 2 В· agent-to-agent x402 payment в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _PayFlowViz extends StatefulWidget {
  const _PayFlowViz();
  @override
  State<_PayFlowViz> createState() => _PayFlowVizState();
}

class _PayFlowVizState extends State<_PayFlowViz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final t = context.puls;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = reduce ? 0.5 : _c.value;
        final travel =
            Curves.easeInOut.transform(((v - 0.08) / 0.62).clamp(0.0, 1.0));
        final arrived = !reduce && v > 0.72 && v < 0.99;
        return Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: Row(
                      children: [
                        _node(t, const Color(0xFF2DD4BF),
                            Icons.smart_toy_rounded, 'Pulse', false),
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: t.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        _node(t, const Color(0xFFEC4899),
                            Icons.auto_awesome_rounded, 'Sage', arrived),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 54),
                      child: Align(
                        alignment: Alignment(travel * 2 - 1, -0.32),
                        child: _coin(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: arrived
                    ? const Color(0xFFEC4899).withValues(alpha: 0.14)
                    : t.surfaceRaised,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: arrived
                        ? const Color(0xFFEC4899).withValues(alpha: 0.42)
                        : t.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded,
                      size: 13, color: Color(0xFFEC4899)),
                  const SizedBox(width: 5),
                  Text('x402 В· 0.001 USDC',
                      style: TextStyle(
                          color: t.text,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _node(PulsThemeColors t, Color c, IconData icon, String label,
          bool pulse) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: pulse ? 1.14 : 1.0,
            duration: const Duration(milliseconds: 220),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    c,
                    Color.alphaBlend(Colors.white.withValues(alpha: 0.4), c)
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: c.withValues(alpha: pulse ? 0.5 : 0.3),
                      blurRadius: pulse ? 18 : 12,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(height: 7),
          Text(label,
              style: TextStyle(
                  color: t.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700)),
        ],
      );

  Widget _coin() => Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: PulsColors.pulseGradient,
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFF65FA9).withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: const Text('\$',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
      );
}

// в”Ђв”Ђ Visual 3 В· AgentBond stake / slash в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _BondViz extends StatefulWidget {
  const _BondViz();
  @override
  State<_BondViz> createState() => _BondVizState();
}

class _BondVizState extends State<_BondViz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 9));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final t = context.puls;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = reduce ? 0.3 : _c.value;
        final win = v < 0.5; // alternate: returned, then slashed
        final localT = reduce ? 0.3 : (v % 0.5) / 0.5;
        final fill = Curves.easeOut.transform((localT / 0.45).clamp(0.0, 1.0));
        final resolved = localT > 0.55;
        final displayFill = !resolved
            ? fill
            : win
                ? 1.0
                : 1.0 -
                    Curves.easeIn
                        .transform(((localT - 0.55) / 0.32).clamp(0.0, 1.0));
        final Color barColor = !resolved
            ? PulsColors.amber
            : win
                ? t.yes
                : t.no;
        final label = !resolved
            ? 'STAKED'
            : win
                ? 'RETURNED'
                : 'SLASHED';
        final icon = !resolved
            ? Icons.lock_rounded
            : win
                ? Icons.verified_rounded
                : Icons.gpp_bad_rounded;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: barColor.withValues(alpha: 0.4)),
                  ),
                  child: Icon(icon, color: barColor, size: 21),
                ),
                const SizedBox(width: 11),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1.0 USDC bond',
                        style: TextStyle(
                            color: t.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('on this call',
                        style: TextStyle(color: t.textSubtle, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Stack(
                  children: [
                    Container(height: 8, color: t.surfaceRaised),
                    FractionallySizedBox(
                      widthFactor: displayFill.clamp(0.0, 1.0),
                      child: Container(height: 8, color: barColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: barColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6)),
                ),
                const Spacer(),
                Text('reputation = capital',
                    style: TextStyle(color: t.textSubtle, fontSize: 10.5)),
              ],
            ),
          ],
        );
      },
    );
  }
}

// в”Ђв”Ђ Visual 4 В· creator Signal unlock в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _SignalUnlockViz extends StatefulWidget {
  const _SignalUnlockViz();
  @override
  State<_SignalUnlockViz> createState() => _SignalUnlockVizState();
}

class _SignalUnlockVizState extends State<_SignalUnlockViz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4200));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final t = context.puls;
    const purple = Color(0xFF8B5CF6);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = reduce ? 0.8 : _c.value;
        final u = ((v - 0.42) / 0.2).clamp(0.0, 1.0); // unlock progress
        final earn = ((v - 0.58) / 0.32).clamp(0.0, 1.0); // +USDC float
        final unlocked = u > 0.5;

        return Stack(
          children: [
            // The premium Signal "behind the paywall".
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.bg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: purple.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('SIGNAL',
                            style: TextStyle(
                                color: purple,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8)),
                      ),
                      const Spacer(),
                      Icon(Icons.verified_rounded,
                          size: 13, color: t.textSubtle),
                    ],
                  ),
                  const SizedBox(height: 11),
                  _bar(t, 0.92),
                  const SizedBox(height: 7),
                  _bar(t, 0.7),
                  const SizedBox(height: 7),
                  _bar(t, 0.8),
                ],
              ),
            ),
            // Frosted lock overlay that lifts as it unlocks.
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 1 - u,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: purple.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, size: 22, color: purple),
                        const SizedBox(height: 6),
                        Text('UNLOCK В· \$0.50',
                            style: TextStyle(
                                color: t.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Earnings receipt rising to the creator.
            if (unlocked)
              Positioned(
                top: 8 + (1 - earn) * 12,
                right: 12,
                child: Opacity(
                  opacity:
                      (earn < 0.85 ? earn : (1 - earn) / 0.15).clamp(0.0, 1.0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.yes.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: t.yes.withValues(alpha: 0.4)),
                    ),
                    child: Text('+\$0.50 USDC',
                        style: TextStyle(
                            color: t.yes,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _bar(PulsThemeColors t, double factor) => Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: factor,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: t.surfaceRaised,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
      );
}

// в”Ђв”Ђ Visual 5 В· Finance Director portfolio basket в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _DirectorViz extends StatefulWidget {
  const _DirectorViz();
  @override
  State<_DirectorViz> createState() => _DirectorVizState();
}

class _DirectorVizState extends State<_DirectorViz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  // A tiny risk-managed basket: tier, side, question, size%, tier colour.
  static const _picks = <(String, String, String, int, Color)>[
    ('CORE', 'YES', 'Fed cuts rates in July', 52, Color(0xFF16A34A)),
    ('HEDGE', 'NO', 'BTC ETF inflows top \$1B', 30, Color(0xFF8B5CF6)),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final t = context.puls;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = reduce ? 1.0 : _c.value;
        return Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: t.bg.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('PORTFOLIO PLAN',
                      style: TextStyle(
                          color: t.textSubtle,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0)),
                  const Spacer(),
                  Text('\$42 bankroll',
                      style: TextStyle(
                          color: t.textMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < _picks.length; i++)
                Padding(
                  padding:
                      EdgeInsets.only(bottom: i == _picks.length - 1 ? 0 : 7),
                  child: _pickRow(
                      t, _picks[i], ((v - i * 0.2) / 0.3).clamp(0.0, 1.0)),
                ),
              const Spacer(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.yes.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: t.yes.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_rounded,
                            size: 12, color: t.yes),
                        const SizedBox(width: 5),
                        Text('money-back if it loses',
                            style: TextStyle(
                                color: t.yes,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text('paid В· \$0.50',
                      style: TextStyle(color: t.textSubtle, fontSize: 10.5)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pickRow(PulsThemeColors t, (String, String, String, int, Color) pick,
      double lit) {
    final tier = pick.$1;
    final side = pick.$2;
    final question = pick.$3;
    final pct = pick.$4;
    final tierColor = pick.$5;
    final sideColor = side == 'YES' ? t.yes : t.no;
    return Opacity(
      opacity: (0.35 + 0.65 * lit).clamp(0.0, 1.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.border),
        ),
        child: Row(
          children: [
            _tag(tier, tierColor),
            const SizedBox(width: 5),
            _tag(side, sideColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(question,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: t.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Text('$pct%',
                style: TextStyle(
                    color: t.brand,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(label,
            style: TextStyle(
                color: c,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4)),
      );
}

// в”Ђв”Ђ Visual 6 В· swipe-to-trade в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _SwipeViz extends StatefulWidget {
  const _SwipeViz();
  @override
  State<_SwipeViz> createState() => _SwipeVizState();
}

class _SwipeVizState extends State<_SwipeViz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3600));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final t = context.puls;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = reduce ? 0.0 : _c.value;
        final yes = v < 0.5; // alternate YES (right) / NO (left)
        final localT = (v % 0.5) / 0.5;
        final progress =
            Curves.easeInOut.transform((localT / 0.62).clamp(0.0, 1.0));
        final dir = yes ? 1.0 : -1.0;
        final dx = reduce ? 0.0 : dir * progress * 52;
        final rot = reduce ? 0.0 : dir * progress * 0.16;
        final stamp = reduce ? 0.0 : ((progress - 0.25) / 0.3).clamp(0.0, 1.0);
        final stampColor = yes ? t.yes : t.no;

        return Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _hint(t, Icons.arrow_back_rounded, 'NO', t.no),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _hint(t, Icons.arrow_forward_rounded, 'YES', t.yes),
            ),
            Transform.translate(
              offset: Offset(dx, -6 * progress),
              child: Transform.rotate(
                angle: rot,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    _card(t),
                    Positioned(
                      top: 14,
                      child: Opacity(
                        opacity: stamp,
                        child: Transform.rotate(
                          angle: -0.22,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: stampColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: stampColor, width: 2.2),
                            ),
                            child: Text(yes ? 'YES' : 'NO',
                                style: TextStyle(
                                    color: stampColor,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _hint(PulsThemeColors t, IconData icon, String label, Color c) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c.withValues(alpha: 0.5)),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  color: c.withValues(alpha: 0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
        ],
      );

  Widget _card(PulsThemeColors t) => Container(
        width: 172,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration:
                      BoxDecoration(color: t.yes, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text('LIVE',
                    style: TextStyle(
                        color: t.yes,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8)),
              ],
            ),
            const SizedBox(height: 9),
            Text('Fed cuts rates in July?',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: t.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.25)),
            const SizedBox(height: 11),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('63Вў',
                    style: TextStyle(
                        fontFamily: PulsColors.fontDisplay,
                        color: t.brand,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1)),
                const SizedBox(width: 5),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('YES',
                      style: TextStyle(
                          color: t.textSubtle,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    Expanded(flex: 63, child: Container(color: t.yes)),
                    Expanded(
                        flex: 37,
                        child: Container(color: t.no.withValues(alpha: 0.65))),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

// в”Ђв”Ђ Capability strip вЂ” breadth without an icon wall в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _CapabilityStrip extends StatelessWidget {
  const _CapabilityStrip();

  static const _items = [
    (Icons.account_balance_wallet_rounded, 'Gasless Circle wallet'),
    (Icons.gavel_rounded, 'UMA oracle resolution'),
    (Icons.tune_rounded, 'Limit orders'),
    (Icons.sell_rounded, 'Sell anytime'),
    (Icons.insights_rounded, 'AI Oracle panel'),
    (Icons.notifications_active_rounded, 'Push alerts'),
    (Icons.card_giftcard_rounded, 'Referral rewards'),
    (Icons.emoji_events_rounded, 'Points & quests'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Column(
      children: [
        Text('AND EVERYTHING YOU\'D EXPECT',
            style: TextStyle(
                color: t.textSubtle,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2)),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final it in _items) _CapabilityPill(icon: it.$1, label: it.$2)
          ],
        ),
      ],
    );
  }
}

class _CapabilityPill extends StatefulWidget {
  const _CapabilityPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  State<_CapabilityPill> createState() => _CapabilityPillState();
}

class _CapabilityPillState extends State<_CapabilityPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: _hovered
            ? Matrix4.translationValues(0.0, -2.0, 0.0)
            : Matrix4.identity(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _hovered ? t.brandSubtle : t.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: _hovered ? t.brand.withValues(alpha: 0.4) : t.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon,
                size: 14, color: _hovered ? t.brand : t.textMuted),
            const SizedBox(width: 7),
            Text(widget.label,
                style: TextStyle(
                    color: _hovered ? t.brand : t.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// в”Ђв”Ђ Stats Section в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _StatsSection extends StatelessWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 600;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48, vertical: isMobile ? 48 : 88),
      child: Center(
        child: ConstrainedBox(
          // 1180 вЂ” aligns with the neighboring card bands so section edges
          // don't jump while scrolling.
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              const _SectionEyebrow(label: 'LIVE PROTOCOL STATS'),
              const SizedBox(height: 20),
              _GradientHeadline(
                lead: 'Built on Circle\'s full stack,',
                accent: 'proven on-chain.',
                isMobile: isMobile,
              ),
              const SizedBox(height: 10),
              Text(
                'Real bonds. Real trades. Real accountability.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: t.textMuted, fontSize: isMobile ? 14 : 16),
              ),
              SizedBox(height: isMobile ? 32 : 48),
              LayoutBuilder(builder: (context, constraints) {
                final cols = constraints.maxWidth > 700 ? 4 : 2;
                return Wrap(
                  spacing: isMobile ? 12 : 20,
                  runSpacing: isMobile ? 12 : 20,
                  children: [
                    _statCard(
                        '100+',
                        'Live Markets',
                        'From Polymarket Gamma API',
                        t.brand,
                        Icons.candlestick_chart_rounded,
                        constraints,
                        cols,
                        t),
                    _statCard('< 1s', 'Trade Speed', 'Arc sub-second finality',
                        t.yes, Icons.bolt_rounded, constraints, cols, t),
                    _statCard(
                        '\$0 ETH',
                        'Gas Cost',
                        'USDC is the native gas token',
                        PulsColors.amber,
                        Icons.local_gas_station_rounded,
                        constraints,
                        cols,
                        t),
                    _statCard(
                        'MPC',
                        'Wallet Type',
                        'Circle developer-controlled wallets',
                        const Color(0xFF0EA5E9),
                        Icons.account_balance_wallet_rounded,
                        constraints,
                        cols,
                        t),
                  ],
                );
              }),
              SizedBox(height: isMobile ? 32 : 52),
              // Contract address widget
              GlassCard(
                radius: 16,
                blur: 0,
                fillAlpha: 0.05,
                borderAlpha: 0.12,
                padding: EdgeInsets.all(isMobile ? 14 : 22),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                    color: t.brandSubtle,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.code_rounded,
                                    color: t.brand, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'LMSRMarketFactory.sol',
                                  style: TextStyle(
                                      color: t.text,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const _VerifiedBadge(),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            factoryAddress,
                            style: TextStyle(
                              color: t.textSubtle,
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const CopyButton(text: factoryAddress),
                              const SizedBox(width: 8),
                              _SecondaryButton(
                                label: 'View в†—',
                                onTap: () => launchUrl(
                                  Uri.parse(
                                      'https://testnet.arcscan.app/address/$factoryAddress'),
                                  mode: LaunchMode.externalApplication,
                                ),
                                small: true,
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: t.brandSubtle,
                                borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.code_rounded,
                                color: t.brand, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'LMSRMarketFactory.sol вЂ” Arc',
                                        style: TextStyle(
                                            color: t.text,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const _VerifiedBadge(),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  factoryAddress,
                                  style: TextStyle(
                                    color: t.textSubtle,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const CopyButton(text: factoryAddress),
                          const SizedBox(width: 8),
                          _SecondaryButton(
                            label: 'View в†—',
                            onTap: () => launchUrl(
                              Uri.parse(
                                  'https://testnet.arcscan.app/address/$factoryAddress'),
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

  Widget _statCard(String value, String label, String sub, Color color,
      IconData icon, BoxConstraints constraints, int cols, PulsThemeColors t) {
    final isMobile = constraints.maxWidth < 600;
    final spacing = isMobile ? 12.0 : 20.0;
    return SizedBox(
      width: (constraints.maxWidth - (cols - 1) * spacing) / cols,
      child: _StatCard(
        value: value,
        label: label,
        sub: sub,
        color: color,
        icon: icon,
        isMobile: isMobile,
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.sub,
    required this.color,
    required this.icon,
    required this.isMobile,
  });
  final String value;
  final String label;
  final String sub;
  final Color color;
  final IconData icon;
  final bool isMobile;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isMobile = widget.isMobile;
    final color = widget.color;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: _hovered
            ? Matrix4.translationValues(0.0, -4.0, 0.0)
            : Matrix4.identity(),
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              t.surface,
              Color.alphaBlend(
                  color.withValues(alpha: _hovered ? 0.06 : 0.02), t.surface),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered ? color.withValues(alpha: 0.4) : t.border,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ]
              : [
                  BoxShadow(
                    color: t.text.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.value,
                    style: TextStyle(
                      color: color,
                      fontSize: isMobile ? 22 : 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                // Brand-tinted icon badge вЂ” replaces the old icons8 network images
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isMobile ? 36 : 48,
                  height: isMobile ? 36 : 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _hovered
                        ? color.withValues(alpha: 0.18)
                        : color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: _hovered ? 0.45 : 0.25),
                      width: 1.2,
                    ),
                    boxShadow: _hovered
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 14,
                            ),
                          ]
                        : null,
                  ),
                  child:
                      Icon(widget.icon, size: isMobile ? 18 : 24, color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(widget.label,
                style: TextStyle(
                    color: t.text,
                    fontSize: isMobile ? 13 : 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(widget.sub,
                style: TextStyle(
                    color: t.textMuted,
                    fontSize: isMobile ? 10 : 12,
                    height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _FinalCtaSection extends StatelessWidget {
  const _FinalCtaSection();

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final isDark = context.isDark;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 700;
    final double titleSize = w < 480 ? 38 : (w < 900 ? 52 : 66);
    final glowColor = isDark ? PulsColors.brandPinkDark : PulsColors.brandPink;

    return Stack(
      children: [
        // Radial glow backdrop behind the CTA section
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _CtaGlowPainter(color: glowColor, isDark: isDark),
            ),
          ),
        ),
        // Content sits above the glow
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20 : 48, vertical: isMobile ? 72 : 130),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 24 : 64,
                    vertical: isMobile ? 40 : 72),
                decoration: BoxDecoration(
                  color: t.surface.withValues(alpha: isDark ? 0.6 : 0.75),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: t.border.withValues(alpha: 0.4),
                  ),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: glowColor.withValues(alpha: 0.08),
                            blurRadius: 80,
                            spreadRadius: -20,
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 40,
                            offset: const Offset(0, 24),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: glowColor.withValues(alpha: 0.06),
                            blurRadius: 60,
                            spreadRadius: -16,
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Column(
                    children: [
                      // Decorative gradient rule above the headline
                      Container(
                        width: 48,
                        height: 3,
                        decoration: const BoxDecoration(
                          gradient: PulsColors.pulseGradient,
                          borderRadius: BorderRadius.all(Radius.circular(100)),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Don\'t trust predictions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: PulsColors.fontDisplay,
                          color: t.text,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w600,
                          height: 1.08,
                          letterSpacing: -1.5,
                        ),
                      ),
                      Text(
                        'Verify them on-chain.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: PulsColors.fontDisplay,
                          color: t.brand,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          height: 1.12,
                          letterSpacing: -1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Trade alongside AI agents that stake real USDC on every call. '
                        'One-tap wallet вЂ” you\'re trading in under a minute.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: t.textMuted,
                            fontSize: isMobile ? 14 : 16,
                            height: 1.6),
                      ),
                      SizedBox(height: isMobile ? 32 : 40),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          Builder(builder: (context) {
                            final wallet = WalletServiceScope.of(context);
                            return _PrimaryButton(
                              label: wallet.state.isLoading
                                  ? 'ConnectingвЂ¦'
                                  : 'Launch Puls',
                              onTap: wallet.state.isLoading
                                  ? null
                                  : () {
                                      if (wallet.state.userId != null) {
                                        appState.dismissWebLanding();
                                      } else {
                                        wallet.signInWithGoogle();
                                      }
                                    },
                            );
                          }),
                          _SecondaryButton(
                            label: 'в¤“  Android APK',
                            onTap: () => launchUrl(Uri.parse(kAndroidApkUrl),
                                mode: LaunchMode.externalApplication),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Soft radial brand glow that lifts the final CTA section.
class _CtaGlowPainter extends CustomPainter {
  const _CtaGlowPainter({required this.color, required this.isDark});
  final Color color;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);
    final radius = size.shortestSide * 0.55;
    final alpha = isDark ? 0.10 : 0.08;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_CtaGlowPainter old) =>
      old.color != color || old.isDark != isDark;
}

// в”Ђв”Ђ Aurora background painter в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _AuroraPainter extends CustomPainter {
  const _AuroraPainter({
    required this.progress,
    required this.isDark,
    required this.bg,
    this.pointer = Offset.zero,
  });
  final double progress;
  final bool isDark;
  final Color bg;
  final Offset pointer;

  // Cached unit paints centered at (0,0) with radius 1.0. Matrix transforms
  // translate and scale them hardware-accelerated on GPU without allocating
  // new RadialGradient shaders on every frame.
  static final Map<int, Paint> _unitPaints = {};

  static Paint _unitPaint(Color c, double alpha) {
    final key = Object.hash(c.toARGB32(), (alpha * 1000).round());
    return _unitPaints.putIfAbsent(key, () {
      return Paint()
        ..shader = RadialGradient(
          colors: [c.withValues(alpha: alpha), c.withValues(alpha: 0.0)],
        ).createShader(const Rect.fromLTRB(-1.0, -1.0, 1.0, 1.0));
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;
    final blobs = isDark
        ? const [
            Color(0xFF2A0720), // deeper plum вЂ” more contrast against navy
            PulsColors.brandPinkDark, // Neon Pink
            PulsColors.brandMint, // Neon Mint
          ]
        : const [
            PulsColors.brandWashLight, // Frosted pink
            Color(0xFFFDF2F8), // Soft glow
            Color(0xFFE6FAF6), // Frosted mint
          ];
    final alpha = isDark ? 0.14 : 0.32;

    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    void blob(Color c, double cx, double cy, double r) {
      if (r <= 0) return;
      final paint = _unitPaint(c, alpha);
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(r, r);
      canvas.drawCircle(Offset.zero, 1.0, paint);
      canvas.restore();
    }

    final w = size.width, h = size.height;
    // Parallax toward the cursor вЂ” each blob drifts a different amount for depth.
    final px = pointer.dx, py = pointer.dy;
    // Larger, slower-feeling blobs with more spread for a more ethereal look.
    blob(blobs[0], w * (0.24 + 0.07 * math.sin(t)) + px * 170,
        h * (0.15 + 0.06 * math.cos(t * 0.75)) + py * 140, w * 0.52);
    blob(blobs[1], w * (0.80 + 0.06 * math.cos(t * 0.85)) - px * 140,
        h * (0.28 + 0.07 * math.sin(t * 0.65)) + py * 110, w * 0.46);
    blob(blobs[2], w * (0.55 + 0.08 * math.sin(t * 0.55 + 2)) + px * 95,
        h * (0.78 + 0.05 * math.cos(t * 0.9 + 1)) - py * 130, w * 0.40);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.progress != progress ||
      old.isDark != isDark ||
      old.bg != bg ||
      old.pointer != pointer;
}

// в”Ђв”Ђ Film grain overlay в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
/// A faint, static noise field that adds texture/depth without hurting text
/// crispness (it sits beneath the content). Cheap: a fixed sparse dot field.
class _GrainPainter extends CustomPainter {
  const _GrainPainter({required this.color});
  final Color color;

  static List<Offset>? _cachedPoints;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    if (_cachedPoints == null) {
      final rnd = math.Random(42);
      const count = 300;
      _cachedPoints = List<Offset>.generate(
        count,
        (_) => Offset(rnd.nextDouble(), rnd.nextDouble()),
        growable: false,
      );
    }
    final points = _cachedPoints!;
    final w = size.width, h = size.height;
    final offsets = List<Offset>.generate(
      points.length,
      (i) => Offset(points[i].dx * w, points[i].dy * h),
      growable: false,
    );
    canvas.drawPoints(ui.PointMode.points, offsets, paint);
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.color != color;
}

// в”Ђв”Ђ Footer в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _FooterSection extends StatelessWidget {
  const _FooterSection({required this.scrollCtrl});
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 600;

    return Container(
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.3),
        border: Border(top: BorderSide(color: t.border.withValues(alpha: 0.4))),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48, vertical: isMobile ? 48 : 80),
      child: Center(
        child: ConstrainedBox(
          // 1180 вЂ” footer columns align with the content column above.
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              isMobile
                  ? Column(
                      children: [
                        // Logo + wordmark
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: t.brandSubtle,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset('assets/logo.png',
                                  fit: BoxFit.cover, cacheWidth: 112),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Puls',
                              style: TextStyle(
                                  fontFamily: PulsColors.fontDisplay,
                                  color: t.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Copyright
                        Text(
                          'В© 2026 Puls В· Built on Arc Network',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: t.textSubtle,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Arc is a trademark of Circle Internet Group, Inc. and/or its affiliates.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: t.textSubtle.withValues(alpha: 0.5),
                              fontSize: 10,
                              height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        // Links
                        const Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 20,
                          runSpacing: 10,
                          children: [
                            _FooterLink('X/Twitter', 'https://x.com/rdmnad'),
                            _FooterLink('Docs', 'https://docs.pulsmarket.tech'),
                            _FooterLink(
                                'GitHub', 'https://github.com/rdmbtc/Puls'),
                            _FooterLink('Mainnet countdown',
                                'https://mainnet.pulsmarket.tech'),
                            _FooterLink('Explorer',
                                'https://testnet.arcscan.app/address/$factoryAddress'),
                            _FooterLink('Android app', kAndroidApkUrl),
                            _FooterLink(
                                'Terms', 'https://pulsmarket.tech/terms'),
                            _FooterLink(
                                'Privacy', 'https://pulsmarket.tech/privacy'),
                          ],
                        ),
                        const SizedBox(height: 28),
                        // Back to top
                        _BackToTop(scrollCtrl: scrollCtrl),
                      ],
                    )
                  : Row(
                      children: [
                        // Left: logo + wordmark
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: t.brandSubtle,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset('assets/logo.png',
                                  fit: BoxFit.cover, cacheWidth: 112),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Puls',
                              style: TextStyle(
                                  fontFamily: PulsColors.fontDisplay,
                                  color: t.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Center: copyright
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'В© 2026 Puls В· Built on Arc Network',
                              style: TextStyle(
                                  color: t.textSubtle,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Arc is a trademark of Circle Internet Group, Inc. and/or its affiliates.',
                              style: TextStyle(
                                  color: t.textSubtle.withValues(alpha: 0.5),
                                  fontSize: 10),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Right: links + back to top
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _FooterLink(
                                'X/Twitter', 'https://x.com/rdmnad'),
                            const SizedBox(width: 20),
                            const _FooterLink(
                                'Docs', 'https://docs.pulsmarket.tech'),
                            const SizedBox(width: 20),
                            const _FooterLink(
                                'GitHub', 'https://github.com/rdmbtc/Puls'),
                            const SizedBox(width: 20),
                            const _FooterLink('Mainnet countdown',
                                'https://mainnet.pulsmarket.tech'),
                            const SizedBox(width: 20),
                            const _FooterLink(
                                'Terms', 'https://pulsmarket.tech/terms'),
                            const SizedBox(width: 20),
                            const _FooterLink(
                                'Privacy', 'https://pulsmarket.tech/privacy'),
                            const SizedBox(width: 24),
                            _BackToTop(scrollCtrl: scrollCtrl),
                          ],
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackToTop extends StatefulWidget {
  const _BackToTop({required this.scrollCtrl});
  final ScrollController scrollCtrl;

  @override
  State<_BackToTop> createState() => _BackToTopState();
}

class _BackToTopState extends State<_BackToTop> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          widget.scrollCtrl.animateTo(
            0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? t.brandSubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hover ? t.brand.withValues(alpha: 0.4) : t.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_arrow_up_rounded,
                  size: 18, color: _hover ? t.brand : t.textMuted),
              const SizedBox(width: 4),
              Text(
                'Back to top',
                style: TextStyle(
                  color: _hover ? t.brand : t.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: green.withValues(alpha: 0.30)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12, color: green),
          SizedBox(width: 4),
          Text(
            'Verified on Arc',
            style: TextStyle(
                color: green, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatefulWidget {
  const _FooterLink(this.label, this.url);
  final String label, url;

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(widget.url),
          mode: LaunchMode.externalApplication),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            color: _hovered ? t.brand : t.textMuted,
            fontSize: 13,
            fontWeight: _hovered ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

// в”Ђв”Ђ Shared Buttons в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton(
      {required this.label, required this.onTap, this.small = false});
  final String label;
  final VoidCallback? onTap;
  final bool small;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  final _magnet = ValueNotifier<Offset>(Offset.zero);

  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _glow.dispose();
    _magnet.dispose();
    super.dispose();
  }

  void _onHover(PointerHoverEvent e) {
    if (context.reduceMotion) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final s = box.size;
    final dx = (e.localPosition.dx - s.width / 2) / (s.width / 2);
    final dy = (e.localPosition.dy - s.height / 2) / (s.height / 2);
    _magnet.value = Offset(dx.clamp(-1.0, 1.0) * 4, dy.clamp(-1.0, 1.0) * 3);
  }

  void _onEnter() {
    setState(() => _hovered = true);
    _glow.forward();
  }

  void _onExit() {
    setState(() {
      _pressed = false;
      _hovered = false;
    });
    _magnet.value = Offset.zero;
    _glow.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final scale = _pressed ? 0.97 : (_hovered ? 1.04 : 1.0);

    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.label,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => widget.onTap != null ? _onEnter() : null,
        onHover: widget.onTap != null ? _onHover : null,
        onExit: (_) => widget.onTap != null ? _onExit() : null,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: widget.onTap != null
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapUp: widget.onTap != null
              ? (_) => setState(() => _pressed = false)
              : null,
          onTapCancel: widget.onTap != null
              ? () => setState(() => _pressed = false)
              : null,
          child: ValueListenableBuilder<Offset>(
            valueListenable: _magnet,
            builder: (context, magnet, child) {
              return AnimatedContainer(
                duration: _pressed
                    ? const Duration(milliseconds: 70)
                    : const Duration(milliseconds: 180),
                curve: _pressed ? Curves.easeOut : Curves.easeOutCubic,
                transformAlignment: Alignment.center,
                transform: Matrix4.translationValues(
                  _pressed ? 0 : magnet.dx,
                  _pressed ? 0 : magnet.dy,
                  0,
                )..scaleByDouble(scale, scale, scale, 1),
                child: child,
              );
            },
            child: AnimatedBuilder(
              animation: _glow,
              builder: (context, child) => Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.small ? 18 : 32,
                  vertical: widget.small ? 10 : 16,
                ),
                decoration: BoxDecoration(
                  gradient: PulsColors.pulseGradient,
                  borderRadius: BorderRadius.circular(widget.small ? 10 : 14),
                  boxShadow: [
                    // Base soft shadow
                    BoxShadow(
                      color: t.brand.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    // Glow on hover
                    if (_glow.value > 0)
                      BoxShadow(
                        color: PulsColors.brandPink.withValues(
                            alpha:
                                _glow.value * (context.isDark ? 0.28 : 0.20)),
                        blurRadius: 24 + 16 * _glow.value,
                        spreadRadius: -2 * _glow.value,
                      ),
                    // Pressed: tighter shadow
                    if (_pressed)
                      BoxShadow(
                        color: t.brand.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: child,
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.small ? 13.5 : 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatefulWidget {
  const _SecondaryButton(
      {required this.label, required this.onTap, this.small = false});
  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isDark = context.isDark;
    final scale = _pressed ? 0.97 : 1.0;
    final duration = Duration(milliseconds: _pressed ? 60 : 150);

    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            duration: duration,
            scale: scale,
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.symmetric(
                horizontal: widget.small ? 16 : 30,
                vertical: widget.small ? 10 : 16,
              ),
              decoration: BoxDecoration(
                color: _hovered ? t.surfaceRaised : t.surface,
                borderRadius: BorderRadius.circular(widget.small ? 10 : 14),
                border: Border.all(
                  color:
                      _hovered ? t.textMuted.withValues(alpha: 0.5) : t.border,
                  width: _hovered ? 1.5 : 1.0,
                ),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: _hovered ? t.text : t.textMuted,
                  fontSize: widget.small ? 13.5 : 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// в”Ђв”Ђ Scroll reveal в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
/// Fades + slides its child in the first time it scrolls into view.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.scrollOffset, required this.child});
  final ValueNotifier<double> scrollOffset;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _shown = false;
  double? _top;

  @override
  void initState() {
    super.initState();
    // Scroll listener: the reveal check runs on scroll ticks WITHOUT a page
    // rebuild вЂ” setState only fires once, on the reveal flip itself.
    widget.scrollOffset.addListener(_maybeReveal);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _shown) return;
      _maybeReveal();
    });
  }

  @override
  void dispose() {
    widget.scrollOffset.removeListener(_maybeReveal);
    super.dispose();
  }

  void _maybeReveal() {
    if (!mounted || _shown) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    // Re-measure every tick: lazy sections above grow when they build, so the
    // content-space position shifts вЂ” a cached _top would go stale and fire
    // reveals thousands of px early. (localToGlobal is a cheap transform
    // walk, not a relayout; the original code paid for it every tick too.)
    _top = box.localToGlobal(Offset.zero).dy + widget.scrollOffset.value;
    final h = MediaQuery.sizeOf(context).height;
    if (widget.scrollOffset.value + h * 0.88 > _top!) {
      // Only setState on the actual flip вЂ” unlisten to stop unnecessary scroll ticks.
      widget.scrollOffset.removeListener(_maybeReveal);
      setState(() => _shown = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Anything starting within the first viewport shows immediately.
    final h = MediaQuery.sizeOf(context).height;
    // Reduce-motion: reveal everything at once, with no fade/slide ramp.
    final reduce = context.reduceMotion;
    final visibleNow = reduce || _shown || (_top != null && _top! < h * 0.92);
    final revealDuration =
        context.motionDuration(const Duration(milliseconds: 650));
    return AnimatedOpacity(
      duration: revealDuration,
      curve: Curves.easeOut,
      opacity: _shown || visibleNow ? 1 : 0,
      child: AnimatedSlide(
        duration: revealDuration,
        curve: Curves.easeOutCubic,
        offset: _shown || visibleNow ? Offset.zero : const Offset(0, 0.06),
        // Animation governor (FPS spec В§1): the section's always-running loops
        // (marquees, live activity, painters) are muted while the section is
        // scrolled out of the viewport band and resume seamlessly on approach.
        // The gate sits INSIDE the reveal animations so the reveal ramp itself
        // plays exactly as before.
        child: PulseVisibilityGate(
          scrollOffset: widget.scrollOffset,
          child: widget.child,
        ),
      ),
    );
  }
}

// в”Ђв”Ђ Section divider в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
/// A slim, centered gradient hairline used to give the long page a consistent
/// visual rhythm between sections.
class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
              child: Container(
                  width: 96,
                  height: 1.5,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        t.brand.withValues(alpha: 0.45)
                      ]),
                      borderRadius: BorderRadius.circular(100)))),
          const SizedBox(width: 8),
          Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [PulsColors.brandMint, PulsColors.brandPinkDark]),
                  borderRadius: BorderRadius.circular(100))),
          const SizedBox(width: 8),
          Flexible(
              child: Container(
                  width: 96,
                  height: 1.5,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        t.brand.withValues(alpha: 0.45),
                        Colors.transparent
                      ]),
                      borderRadius: BorderRadius.circular(100)))),
        ],
      ),
    );
  }
}

// в”Ђв”Ђ Lazy section build в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
/// Delays constructing its child (and any HTTP the child triggers) until the
/// section scrolls within ~1.2 viewport-heights of the top of the screen.
/// This keeps the initial page load light вЂ” only the hero + first sections are
/// built immediately, live sections build as you scroll to them.
class _LazySection extends StatefulWidget {
  const _LazySection({
    required this.scrollOffset,
    required this.builder,
    this.estimatedHeight = 520.0,
  });
  final ValueNotifier<double> scrollOffset;
  final WidgetBuilder builder;
  final double estimatedHeight;

  @override
  State<_LazySection> createState() => _LazySectionState();
}

class _LazySectionState extends State<_LazySection> {
  bool _built = false;
  double? _top;

  @override
  void initState() {
    super.initState();
    widget.scrollOffset.addListener(_maybeBuild);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBuild());
  }

  @override
  void dispose() {
    widget.scrollOffset.removeListener(_maybeBuild);
    super.dispose();
  }

  void _maybeBuild() {
    if (_built || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    _top = box.localToGlobal(Offset.zero).dy + widget.scrollOffset.value;
    final h = MediaQuery.sizeOf(context).height;
    if (widget.scrollOffset.value + h * 1.5 >= _top!) {
      widget.scrollOffset.removeListener(_maybeBuild);
      setState(() => _built = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_built) return widget.builder(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBuild());
    return SizedBox(height: widget.estimatedHeight);
  }
}

// в”Ђв”Ђ Scroll cue в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _ScrollCue extends StatefulWidget {
  const _ScrollCue();

  @override
  State<_ScrollCue> createState() => _ScrollCueState();
}

class _ScrollCueState extends State<_ScrollCue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SCROLL',
          style: TextStyle(
            color: t.textSubtle,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
          ),
        ),
        const SizedBox(height: 8),
        // Mouse-shaped cue with an animated wheel dot.
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, reduce ? 0 : _c.value * 4),
            child: child,
          ),
          child: Container(
            width: 22,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  t.surface.withValues(alpha: 0.9),
                  t.surfaceRaised,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: t.border.withValues(alpha: 0.9),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: t.brand.withValues(alpha: 0.08),
                  blurRadius: 14,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Center(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => Opacity(
                  opacity: reduce ? 0.8 : (0.3 + 0.7 * (1 - _c.value)),
                  child: Transform.translate(
                    offset: Offset(0, reduce ? 0 : -3 + _c.value * 6),
                    child: Container(
                      width: 3,
                      height: 7,
                      decoration: BoxDecoration(
                        color: t.brand,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: t.brand.withValues(alpha: 0.6),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// в”Ђв”Ђ Visual В· Puls Gateway (x402) в”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђв”Ђ
class _GatewayViz extends StatefulWidget {
  const _GatewayViz();
  @override
  State<_GatewayViz> createState() => _GatewayVizState();
}

class _GatewayVizState extends State<_GatewayViz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final t = context.puls;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final v = reduce ? 0.8 : _c.value;
          final phase =
              v < 0.33 ? 0 : (v < 0.66 ? 1 : 2); // 0: Query, 1: Pay, 2: Data

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _node(t, phase == 0, Icons.smart_toy_rounded, 'Agent'),
                  _line(t, phase == 1, 'x402 Pay'),
                  _node(t, phase == 2, Icons.cloud_download_rounded,
                      'Premium API'),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                phase == 0
                    ? 'Evaluating ROI...'
                    : (phase == 1 ? 'Settling 0.000005 USDC' : 'Data Unlocked'),
                style: TextStyle(
                    color: t.textSubtle,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _node(PulsThemeColors t, bool active, IconData icon, String label) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: active ? t.brand.withValues(alpha: 0.2) : t.surfaceRaised,
            shape: BoxShape.circle,
            border: Border.all(color: active ? t.brand : t.border)),
        child: Icon(icon, size: 18, color: active ? t.brand : t.textMuted),
      ),
      const SizedBox(height: 6),
      Text(label,
          style: TextStyle(
              color: t.textMuted, fontSize: 9, fontWeight: FontWeight.w800)),
    ]);
  }

  Widget _line(PulsThemeColors t, bool active, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: active ? t.yes : Colors.transparent,
                fontSize: 8,
                fontWeight: FontWeight.w900)),
        Container(
          width: 40,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: active ? t.yes : t.border,
        ),
      ],
    );
  }
}


// -- Journal bento visual: a mini agent-authored article with a live USDC tip --
class _JournalViz extends StatefulWidget {
  const _JournalViz();
  @override
  State<_JournalViz> createState() => _JournalVizState();
}

class _JournalVizState extends State<_JournalViz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4600));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final t = context.puls;
    const accent = Color(0xFF10B981);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // Tip pill floats up + fades during the last third of the loop.
        final v = reduce ? 0.75 : _c.value;
        final tip = ((v - 0.6) / 0.4).clamp(0.0, 1.0);
        return Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.bg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.30),
                          const Color(0xFF8B5CF6).withValues(alpha: 0.22),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    alignment: Alignment.centerLeft,
                    child: const Row(
                      children: [
                        Icon(Icons.article_rounded,
                            size: 13, color: Colors.white),
                        SizedBox(width: 6),
                        Text('DAILY ANALYSIS',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _vizLine(t, 0.94, h: 7),
                  const SizedBox(height: 6),
                  _vizLine(t, 0.72, h: 7),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      const Icon(Icons.travel_explore_rounded,
                          size: 11, color: accent),
                      const SizedBox(width: 5),
                      Text('SOURCES',
                          style: TextStyle(
                              color: t.textSubtle,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0)),
                      const SizedBox(width: 6),
                      _srcChip(t, 'research'),
                      const SizedBox(width: 4),
                      _srcChip(t, 'wire'),
                      const Spacer(),
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 11, color: t.textSubtle),
                      const SizedBox(width: 3),
                      Text('12',
                          style: TextStyle(
                              color: t.textSubtle,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
            ),
            if (tip > 0)
              Positioned(
                right: 10,
                bottom: 8 + (1 - tip) * 26,
                child: Opacity(
                  opacity:
                      (tip < 0.82 ? tip : (1 - tip) / 0.18).clamp(0.0, 1.0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                            color: accent.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded,
                            size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('TIP \$0.25',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _vizLine(PulsThemeColors t, double w, {double h = 6}) => Container(
        width: double.infinity,
        height: h,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: w,
          child: Container(
            decoration: BoxDecoration(
              color: t.text.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(h / 2),
            ),
          ),
        ),
      );

  Widget _srcChip(PulsThemeColors t, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: t.surfaceRaised,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: t.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: t.textMuted,
                fontSize: 8.5,
                fontWeight: FontWeight.w700)),
      );
}

// -- Sponsorship bento visual: agent card + animated profit split bar --
class _SponsorViz extends StatefulWidget {
  const _SponsorViz();
  @override
  State<_SponsorViz> createState() => _SponsorVizState();
}

class _SponsorVizState extends State<_SponsorViz>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3800));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    if (reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
    final t = context.puls;
    const accent = Color(0xFF22C55E);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final fill = reduce ? 0.72 : 0.18 + 0.54 * _c.value;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.bg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.16),
                      border:
                          Border.all(color: accent.withValues(alpha: 0.45)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('\u{1F916}', style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ATLAS',
                            style: TextStyle(
                                color: t.text,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6)),
                        Text('creator agent · trading your stake',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: t.textMuted,
                                fontSize: 9.5,
                                height: 1.3)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('+\$${(fill * 3).toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      FractionallySizedBox(
                        widthFactor: fill.clamp(0.0, 1.0),
                        child: Container(color: accent),
                      ),
                      Expanded(child: Container(color: t.border)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('YOU ${(fill * 100).round()}%',
                      style: const TextStyle(
                          color: accent,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8)),
                  const Spacer(),
                  Text('AGENT',
                      style: TextStyle(
                          color: t.textSubtle,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.savings_rounded, size: 12, color: accent),
                  const SizedBox(width: 5),
                  Text('USDC STAKED - PROFIT SHARE ON ARC',
                      style: TextStyle(
                          color: t.textSubtle,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}