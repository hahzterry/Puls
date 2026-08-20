import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/puls_snack.dart';

class SocialShareModal extends StatelessWidget {
  const SocialShareModal({
    super.key,
    required this.marketQuestion,
    required this.side,
    required this.amountUsdc,
    required this.marketSlug,
    this.potentialPayoutUsdc,
  });

  final String marketQuestion;
  final String side; // 'YES' | 'NO'
  final double amountUsdc;
  final String marketSlug;
  final double? potentialPayoutUsdc;

  static Future<void> show(
    BuildContext context, {
    required String marketQuestion,
    required String side,
    required double amountUsdc,
    required String marketSlug,
    double? potentialPayoutUsdc,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SocialShareModal(
        marketQuestion: marketQuestion,
        side: side,
        amountUsdc: amountUsdc,
        marketSlug: marketSlug,
        potentialPayoutUsdc: potentialPayoutUsdc,
      ),
    );
  }

  String get _shareUrl => 'https://pulsmarket.tech/m/$marketSlug';

  String get _shareText =>
      '⚡ I just predicted $side on "$marketQuestion" on @pulsmarket!\n\n'
      'Built on @arc with USDC gas & AI swarm consensus 🤖\n'
      'Trade with me: $_shareUrl';

  Future<void> _shareToTwitter(BuildContext context) async {
    final uri = Uri.parse(
      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(_shareText)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareToTelegram(BuildContext context) async {
    final uri = Uri.parse(
      'https://t.me/share/url?url=${Uri.encodeComponent(_shareUrl)}&text=${Uri.encodeComponent(_shareText)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final sideColor = side == 'YES' ? t.yes : t.no;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: t.surfaceRaised,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: t.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.share_rounded, color: t.brand, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Share Your Prediction',
                    style: TextStyle(
                      color: t.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Preview Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: sideColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            side,
                            style: TextStyle(
                              color: sideColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '\$$amountUsdc USDC Staked',
                          style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      marketQuestion,
                      style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareToTwitter(context),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Twitter / X', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareToTelegram(context),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('Telegram', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: t.text,
                        side: BorderSide(color: t.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _shareUrl));
                    Navigator.of(context).pop();
                    PulsSnack.of(context).show('Market link copied to clipboard! 📋');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Copy Market Link', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: t.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
