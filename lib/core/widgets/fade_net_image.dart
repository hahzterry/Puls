import 'package:flutter/material.dart';

import '../config.dart';
import '../theme/app_theme.dart';

/// Network image with a short opacity fade on load (and a muted placeholder
/// while decoding / on error) so heavy covers never pop in harshly.
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

  @override
  Widget build(BuildContext context) {
    final placeholder = context.puls.border.withValues(alpha: 0.45);
    return Image.network(
      proxifyImageUrl(url),
      fit: fit,
      height: height,
      width: width,
      cacheHeight: cacheHeight,
      cacheWidth: cacheWidth,
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
  }
}
