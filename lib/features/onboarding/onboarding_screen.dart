import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _index = 0;

  // Free Lottie animations from lottiefiles.com (CDN URLs)
  static const _slides = [
    _Slide(
      lottieUrl:
          'https://assets10.lottiefiles.com/packages/lf20_jcikwtux.json',
      eyebrow: 'PREDICTION MARKETS',
      title: 'Predict the pulse\nof everything.',
      body: 'Swipe through live questions, read the market, and choose Yes or No in seconds.',
    ),
    _Slide(
      lottieUrl:
          'https://assets9.lottiefiles.com/packages/lf20_qp1q7mct.json',
      eyebrow: 'DEEP MARKETS',
      title: 'Fast feed.\nDeep markets.',
      body: 'Start with a TikTok-style prediction stream, then open full odds, charts, and context.',
    ),
    _Slide(
      lottieUrl:
          'https://assets4.lottiefiles.com/packages/lf20_ysas4vcp.json',
      eyebrow: 'PROTOTYPE',
      title: 'Demo only.\nBuilt to explore.',
      body: 'Puls uses mock data. No wallet, no deposits, and no real trades.',
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);
    final t = context.puls;
    final isLast = _index == _slides.length - 1;

    if (kIsWeb) {
      return Scaffold(
        backgroundColor: t.bg,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Row(
              children: [
                // Left: branding panel
                Expanded(
                  child: Container(
                    color: t.brand,
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset('assets/logo.png',
                                  fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Puls',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        FadeInLeft(
                          key: ValueKey(_index),
                          duration: const Duration(milliseconds: 400),
                          child: Lottie.network(
                            _slides[_index].lottieUrl,
                            height: 220,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.auto_graph_rounded,
                              size: 80,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          _slides[_index].eyebrow,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _slides[_index].title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _slides[_index].body,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right: controls panel
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Get started',
                            style: Theme.of(context).textTheme.displaySmall),
                        const SizedBox(height: 8),
                        Text(
                          'Predict the pulse of everything on Arc Testnet.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: t.textMuted),
                        ),
                        const SizedBox(height: 40),
                        // Step dots
                        Row(
                          children: List.generate(
                            _slides.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              width: _index == i ? 24 : 8,
                              height: 8,
                              margin:
                                  const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: _index == i ? t.brand : t.border,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            onPressed: () {
                              if (!isLast) {
                                setState(() => _index++);
                              } else {
                                appState.completeOnboarding();
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: t.brand,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              isLast ? 'Enter Puls' : 'Continue',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        if (!isLast) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: appState.completeOnboarding,
                            child: Text('Skip',
                                style: TextStyle(
                                    color: t.textSubtle, fontSize: 13)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top wordmark
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: t.brandSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Puls',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (v) => setState(() => _index = v),
                itemBuilder: (context, i) =>
                    _SlidePage(slide: _slides[i], t: t),
              ),
            ),
            // Bottom controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        width: _index == i ? 20 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: _index == i ? t.brand : t.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // CTA
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: () {
                        if (!isLast) {
                          _ctrl.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          );
                        } else {
                          appState.completeOnboarding();
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: t.brand,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        isLast ? 'Enter Puls' : 'Continue',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: appState.completeOnboarding,
                      child: Text('Skip',
                          style: TextStyle(
                              color: t.textSubtle, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide, required this.t});
  final _Slide slide;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Lottie animation
          Expanded(
            flex: 5,
            child: FadeIn(
              duration: const Duration(milliseconds: 500),
              child: Lottie.network(
                slide.lottieUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.auto_graph_rounded,
                  size: 80,
                  color: t.brand,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Text content
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    slide.eyebrow,
                    style: TextStyle(
                      color: t.brand,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeInUp(
                  delay: const Duration(milliseconds: 60),
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    slide.title,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
                const SizedBox(height: 14),
                FadeInUp(
                  delay: const Duration(milliseconds: 120),
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    slide.body,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: t.textMuted, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.lottieUrl,
    required this.eyebrow,
    required this.title,
    required this.body,
  });
  final String lottieUrl;
  final String eyebrow;
  final String title;
  final String body;
}
