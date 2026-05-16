import 'package:flutter/material.dart';

import '../data/mock/mock_market_repository.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/puls_shell.dart';
import '../core/theme/app_theme.dart';
import 'puls_app_state.dart';

class PulsApp extends StatefulWidget {
  const PulsApp({super.key});

  @override
  State<PulsApp> createState() => _PulsAppState();
}

class _PulsAppState extends State<PulsApp> {
  late final PulsAppState _state;

  @override
  void initState() {
    super.initState();
    _state = PulsAppState(repository: MockMarketRepository());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _state,
      builder: (context, _) {
        return PulsStateScope(
          notifier: _state,
          child: MaterialApp(
            title: 'Puls',
            debugShowCheckedModeBanner: false,
            theme: PulsTheme.dark(),
            home: _state.onboardingComplete
                ? const PulsShell()
                : const OnboardingScreen(),
          ),
        );
      },
    );
  }
}
