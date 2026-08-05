import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'puls_snack.dart';

/// Small copy button with a brief "copied" acknowledgement.
///
/// Self-contained: pass [text] and it copies it on tap (showing a snackbar).
/// Controlled: pass [copied] + [onTap] and the parent drives the state.
/// [compact] renders the inline text-button style used in terminal title bars.
class CopyButton extends StatefulWidget {
  const CopyButton({
    super.key,
    this.text,
    this.copied,
    this.onTap,
    this.compact = false,
  });

  final String? text;
  final bool? copied;
  final VoidCallback? onTap;
  final bool compact;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _internalCopied = false;

  bool get _copied => widget.copied ?? _internalCopied;

  void _handleTap() {
    final onTap = widget.onTap;
    if (onTap != null) {
      onTap();
      return;
    }
    final text = widget.text;
    if (text == null) return;
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _internalCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _internalCopied = false);
    });
    PulsSnack.show(context, 'Address copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final copied = _copied;

    if (widget.compact) {
      final color =
          copied ? PulsColors.brandMint : Colors.white.withValues(alpha: 0.55);
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _handleTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 14, color: color),
                const SizedBox(width: 5),
                Text(
                  copied ? 'Copied' : 'Copy',
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: _handleTap,
      icon: Icon(
        copied ? Icons.check_circle_outline_rounded : Icons.copy_rounded,
        color: copied ? t.yes : t.brand,
        size: 18,
      ),
      tooltip: 'Copy contract address',
    );
  }
}
