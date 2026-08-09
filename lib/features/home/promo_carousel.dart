import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tactile.dart';

class PromoSlide {
  const PromoSlide({
    required this.title,
    required this.subtitle,
    required this.cta,
    this.onTap,
    this.gradient,
    this.backgroundColor,
    this.imageAsset,
  });

  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? backgroundColor;

  /// Optional background image (e.g. an HD promo banner). Text is rendered on
  /// top of a dark scrim for legibility, so banners can ship without baked-in text.
  final String? imageAsset;
}

class PromoCarousel extends StatefulWidget {
  const PromoCarousel({super.key, required this.slides, this.height = 160});
  final List<PromoSlide> slides;
  final double height;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  late final PageController _ctrl;
  Timer? _timer;
  // Page index as a ValueNotifier: only the dots row listens to it, so page
  // changes never rebuild (or repaint) the PageView itself.
  final ValueNotifier<int> _current = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      final next = (_current.value + 1) % widget.slides.length;
      _ctrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    _current.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: widget.height,
            child: PageView.builder(
              controller: _ctrl,
              itemCount: widget.slides.length,
              onPageChanged: (i) {
                _current.value = i;
                _startAutoPlay();
              },
              itemBuilder: (context, i) => _PromoCard(
                slide: widget.slides[i],
                t: t,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Dots indicator — only this row listens to page changes.
          RepaintBoundary(
            child: ValueListenableBuilder<int>(
              valueListenable: _current,
              builder: (context, current, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.slides.length, (i) {
                  final active = i == current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: active ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: active ? t.brand : t.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.slide, required this.t});
  final PromoSlide slide;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    final bg = slide.backgroundColor ?? t.brand;
    final hasImage = slide.imageAsset != null;
    return Tactile(
      onTap: slide.onTap,
      // Promo banners are the most prominent tap target on Home — give them a
      // subtle desktop hover-lift on top of the press feedback.
      hoverScale: 1.02,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: hasImage
              ? null
              : (slide.gradient ??
                  LinearGradient(
                    colors: [bg, bg.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // HD banner image (no baked-in text) + dark scrim for legibility.
            if (hasImage) ...[
              Image.asset(slide.imageAsset!, fit: BoxFit.cover),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    slide.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slide.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      slide.cta,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
