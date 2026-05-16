import 'package:flutter/material.dart';

import '../../app/puls_app_state.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _slides = [
    _OnboardingSlide(
      title: 'Predict the pulse of everything.',
      body:
          'Swipe through live questions, read the market, and choose Yes or No in seconds.',
      icon: Icons.bolt_rounded,
    ),
    _OnboardingSlide(
      title: 'Fast feed. Deep markets.',
      body:
          'Start with a TikTok-style prediction stream, then open full odds, charts, and context.',
      icon: Icons.auto_graph_rounded,
    ),
    _OnboardingSlide(
      title: 'Demo only. Built to explore.',
      body:
          'Puls uses mock data in this prototype. No wallet, no deposits, and no real trades.',
      icon: Icons.verified_user_rounded,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = PulsStateScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PulsWordmark(),
              const SizedBox(height: 28),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return _OnboardingPage(slide: slide);
                  },
                ),
              ),
              Row(
                children: List.generate(
                  _slides.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: _index == index ? 28 : 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _index == index
                          ? PulsColors.blue
                          : PulsColors.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    if (_index < _slides.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                      );
                    } else {
                      appState.completeOnboarding();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: PulsColors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _index == _slides.length - 1 ? 'Enter Puls' : 'Continue',
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

class _PulsWordmark extends StatelessWidget {
  const _PulsWordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: PulsColors.blue.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: PulsColors.blue.withValues(alpha: 0.6)),
          ),
          child: const Icon(Icons.show_chart_rounded, color: PulsColors.blue),
        ),
        const SizedBox(width: 10),
        Text(
          'Puls',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            color: PulsColors.panelElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: PulsColors.border),
            boxShadow: [
              BoxShadow(
                color: PulsColors.blue.withValues(alpha: 0.24),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Icon(slide.icon, color: PulsColors.cyan, size: 34),
        ),
        const SizedBox(height: 34),
        Text(slide.title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 16),
        Text(slide.body, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;
}
