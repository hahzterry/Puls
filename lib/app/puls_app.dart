import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/mock/mock_market_repository.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/shell/puls_shell.dart';
import '../features/wallet/wallet_service.dart';
import 'puls_app_state.dart';

class PulsApp extends StatefulWidget {
  const PulsApp({super.key});

  @override
  State<PulsApp> createState() => _PulsAppState();
}

class _PulsAppState extends State<PulsApp> {
  late final PulsAppState _state;
  final _walletService = WalletService();

  @override
  void initState() {
    super.initState();
    _state = PulsAppState(mockRepo: MockMarketRepository());
  }

  @override
  void dispose() {
    _walletService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_state, _walletService]),
      builder: (context, _) {
        return WalletServiceScope(
          service: _walletService,
          child: PulsStateScope(
            notifier: _state,
            child: MaterialApp(
              title: 'Puls',
              debugShowCheckedModeBanner: false,
              theme: PulsTheme.light(),
              darkTheme: PulsTheme.dark(),
              // Web always dark — matches the glassmorphism design
              themeMode: kIsWeb ? ThemeMode.dark : _state.themeMode,
              home: _state.onboardingComplete
                  ? const PulsShell()
                  : const OnboardingScreen(),
            ),
          ),
        );
      },
    );
  }
}

// ── InheritedWidget scope for WalletService ───────────────────────────────────
class WalletServiceScope extends InheritedWidget {
  const WalletServiceScope({
    required this.service,
    required super.child,
    super.key,
  });

  final WalletService service;

  static WalletService of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<WalletServiceScope>();
    assert(scope != null, 'WalletServiceScope not found');
    return scope!.service;
  }

  @override
  bool updateShouldNotify(WalletServiceScope old) => service != old.service;
}
