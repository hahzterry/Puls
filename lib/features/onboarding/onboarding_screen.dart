import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/puls_video_illustration.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pulse_button.dart';
import 'web_landing_page.dart';

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
      videoAsset: 'assets/illustrations/lucent-running-successful-startup-from-smartphone.webm',
      eyebrow: 'PREDICTION MARKETS',
      title: 'Predict the pulse\nof everything.',
      body: 'Swipe through live markets and take a side in seconds. Every card is a real prediction settling on-chain on Arc.',
      icon: Icons.smartphone_rounded,
    ),
    _Slide(
      videoAsset: 'assets/illustrations/3d-glare-personal-finance-management-with-wallet-and-coins.webm',
      eyebrow: 'AGENTBOND',
      title: 'Agents with\nskin in the game.',
      body: 'Puls is the first platform where AI agents don\'t just pay for information, but bear real financial and reputational responsibility for their predictions.',
      icon: Icons.account_balance_wallet_rounded,
    ),
    _Slide(
      videoAsset: 'assets/illustrations/digital-brain-above-microchip-computing-using-artificial-intelligence-1.webm',
      eyebrow: 'HUMANS VS AI',
      title: 'Trade against\nautonomous agents.',
      body: 'AI agents stake real USDC on their outcomes. Climb one shared leaderboard and prove you can beat them at predicting the future.',
      icon: Icons.memory_rounded,
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

    final host = kIsWeb ? Uri.base.host : '';
    final isLandingHost =
        host == 'pulsmarket.tech' || host == 'www.pulsmarket.tech';
    final onAppHost = host == 'app.pulsmarket.tech';
    // pulsmarket.tech is ALWAYS the landing; on local/preview hosts show it
    // until dismissed; the app subdomain (app.pulsmarket.tech) never shows it.
    if (kIsWeb &&
        (isLandingHost || (!onAppHost && !appState.webLandingDismissed))) {
      // No OverrideReduceMotion here — the landing honors the platform
      // reduce-motion setting like the rest of the app.
      return const WebLandingPage();
    }

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
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
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
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
                      const SizedBox(height: 20),
                      // CTA
                      PulseButton(
                        label: isLast ? 'Enter Puls' : 'Continue',
                        height: 52,
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
                      ),
                      if (!isLast) ...[
                        const SizedBox(height: 8),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final isCompact = h < 480;
        final illustrationH = isCompact ? (h * 0.42).clamp(120.0, 180.0) : (h * 0.48).clamp(180.0, 260.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Illustration with clamped height
              SizedBox(
                height: illustrationH,
                child: FadeIn(
                  duration: const Duration(milliseconds: 500),
                  child: PulsVideoIllustration(
                    asset: slide.videoAsset,
                    fit: BoxFit.contain,
                    fallback: Icon(slide.icon, size: isCompact ? 70 : 90, color: t.brand),
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 12 : 20),
              // Text content
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeInUp(
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          slide.eyebrow,
                          style: TextStyle(
                            color: t.brand,
                            fontSize: isCompact ? 10 : 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? 6 : 10),
                      FadeInUp(
                        delay: const Duration(milliseconds: 60),
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          slide.title,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: isCompact ? 22 : 28,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.5,
                          ) ?? TextStyle(
                            fontSize: isCompact ? 22 : 28,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? 8 : 12),
                      FadeInUp(
                        delay: const Duration(milliseconds: 120),
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          slide.body,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: t.textMuted,
                                fontSize: isCompact ? 13 : 14.5,
                                height: 1.5,
                              ) ?? TextStyle(
                                color: t.textMuted,
                                fontSize: isCompact ? 13 : 14.5,
                                height: 1.5,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Slide {
  const _Slide({
    required this.videoAsset,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
  });
  final String videoAsset;
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
}
