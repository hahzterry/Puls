import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../feed/feed_screen.dart';
import 'landing_kit.dart';
import 'mac_window_frame.dart';

/// "Your first trade in a swipe" — an auto-playing phone mockup that swipes
/// markets YES/NO and shows the sub-second on-chain settle. Fully self-contained
/// (no backend) and reduce-motion aware (holds a still card).
class PhoneDemoSection extends StatelessWidget {
  const PhoneDemoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 880;

    final copy = _Copy(isMobile: isMobile);
    final phone = Center(
      child: liveAppPreview(
        screen: const FeedScreen(),
        width: 390,
        height: 800,
      ),
    );

    return Container(
      color: t.surface.withValues(alpha: 0.35),
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 48, vertical: isMobile ? 52 : 96),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: isMobile
              ? Column(children: [copy, const SizedBox(height: 44), phone])
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: copy),
                    const SizedBox(width: 48),
                    Expanded(flex: 5, child: phone),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Copy extends StatelessWidget {
  const _Copy({required this.isMobile});
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final cross = isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final align = isMobile ? TextAlign.center : TextAlign.left;
    return Column(
      crossAxisAlignment: cross,
      children: [
        const LandingEyebrow(label: 'MOBILE-FIRST', icon: Icons.swipe_rounded),
        const SizedBox(height: 20),
        // Headline (left-aligned variant)
        Column(
          crossAxisAlignment: cross,
          children: [
            Text('Your first trade',
                textAlign: align,
                style: TextStyle(
                    fontFamily: PulsColors.fontDisplay,
                    color: t.text,
                    fontSize: isMobile ? 30 : 46,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    letterSpacing: -1.3)),
            AnimatedGradientText('in a single swipe.',
                textAlign: align,
                style: TextStyle(
                    fontFamily: PulsColors.fontDisplay,
                    fontSize: isMobile ? 30 : 46,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    height: 1.12,
                    letterSpacing: -1.3)),
          ],
        ),
        const SizedBox(height: 22),
        _bullet(t, Icons.swipe_right_rounded, t.yes, 'Swipe right for YES, left for NO',
            'No order forms, no confirmation modal — just a flick.', align, isMobile),
        _bullet(t, Icons.bolt_rounded, t.brand, 'Settled on Arc in under a second',
            'Sub-second finality means it feels instant.', align, isMobile),
        _bullet(t, Icons.account_balance_wallet_rounded, const Color(0xFF0EA5E9),
            'USDC is the gas token', 'No ETH, no seed phrase, no bridging — ever.', align, isMobile),
      ],
    );
  }

  Widget _bullet(PulsThemeColors t, IconData icon, Color c, String title, String body,
      TextAlign align, bool isMobile) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: c),
        ),
        const SizedBox(width: 13),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: t.text, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(body,
                  style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.5)),
            ],
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: isMobile
          ? ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: row)
          : row,
    );
  }
}
