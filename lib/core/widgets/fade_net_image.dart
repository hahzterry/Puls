import 'package:flutter/material.dart';

import '../config.dart';
import '../theme/app_theme.dart';

/// Network image with a short opacity fade on load (and a muted placeholder
/// while decoding / on error) so heavy covers never pop in harshly.
///
/// Decode-size caps (FPS spec §2): unless the caller passes explicit
/// [cacheWidth]/[cacheHeight], the decode size is derived from the layout box
/// × device pixel ratio (clamped to 64–1600px). Without this, every network
/// image decodes at full intrinsic resolution into RAM — multi-MP hero art and
/// avatars alike — which drives GC pauses and paging on low-RAM machines.
///
/// Only ONE dimension is ever capped so the codec preserves aspect ratio.
class FadeNetImage extends StatelessWidget {
  const FadeNetImage({
    super.key,
    required this.url,
    this.fit,
    this.height,
    this.width,
    this.cacheHeight,
    this.cacheWidth,
    this.alignment = Alignment.center,
  });

  final String url;
  final BoxFit? fit;
  final double? height;
  final double? width;
  final int? cacheHeight;
  final int? cacheWidth;
  final Alignment alignment;

  /// Long-edge clamp: below this a decode is never useful; above this the eye
  /// cannot distinguish extra pixels at any plausible render size here.
  static const int _minPx = 64;
  static const int _maxPx = 1600;

  int _capPx(double logicalPx, double dpr) =>
      (logicalPx * dpr).round().clamp(_minPx, _maxPx);

  @override
  Widget build(BuildContext context) {
    final placeholder = context.puls.border.withValues(alpha: 0.45);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Caller-explicit caps always win (existing tuned call sites keep
        // exactly their current behavior + cache identity).
        int? cw = cacheWidth;
        int? ch = cacheHeight;
        if (cw == null && ch == null) {
          final dpr =
              MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
          if (constraints.hasBoundedWidth) {
            cw = _capPx(constraints.maxWidth, dpr);
          } else if (width != null) {
            cw = _capPx(width!, dpr);
          } else if (constraints.hasBoundedHeight) {
            ch = _capPx(constraints.maxHeight, dpr);
          } else if (height != null) {
            ch = _capPx(height!, dpr);
          }
          // Fully unbounded (and no explicit size): leave uncapped rather than
          // guess — e.g. sliver headers measuring intrinsic content.
        }
        return Image.network(
          proxifyImageUrl(url),
          fit: fit,
          height: height,
          width: width,
          cacheHeight: ch,
          cacheWidth: cw,
          alignment: alignment,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              child: frame == null
                  ? ColoredBox(color: placeholder, child: child)
                  : child,
            );
          },
          errorBuilder: (_, __, ___) => ColoredBox(color: placeholder),
        );
      },
    );
  }
}
