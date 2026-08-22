import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme/app_theme.dart';
import '../utils/agent_pfp.dart';
import 'package:puls/core/config.dart';

/// Filters out DiceBear URLs which were previously used as placeholders,
/// replacing them with the branded monogram fallback.
bool isPlaceholderUrl(String url) {
  return url.contains('api.dicebear.com');
}

/// Avatar that never shows a broken image: renders the (normalized) network
/// image when possible and falls back to a branded monogram otherwise.
class PulsAvatar extends StatelessWidget {
  const PulsAvatar({
    super.key,
    required this.url,
    required this.name,
    this.size = 40,
    this.radius,
  });

  final String? url;
  final String name;
  final double size;

  /// Corner radius. Defaults to a circle.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final r = radius ?? size / 2;

    String fallbackChar = 'P';
    if (name.isNotEmpty) {
      final match = RegExp(r'[a-zA-Z0-9]').firstMatch(name);
      if (match != null) {
        fallbackChar = match.group(0)!.toUpperCase();
      } else {
        fallbackChar = name.characters.first.toUpperCase();
      }
    }

    Widget fallback = Container(
      width: size,
      height: size,
      color: t.brandSubtle,
      alignment: Alignment.center,
      child: Text(
        fallbackChar,
        style: TextStyle(
          color: t.brand,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    Widget child;
    final pfp = agentPfpAsset(name);
    if (pfp != null) {
      // Named house/swarm agent → use its bundled PFP.
      child = Image.asset(
        pfp,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
    } else if (url != null && url!.isNotEmpty && !isPlaceholderUrl(url!)) {
      child = CachedNetworkImage(imageUrl: proxifyImageUrl(url!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Avatars render at ≤48 logical px almost everywhere; decoding the
        // full-res upload for each of dozens of feed rows is pure waste
        // (FPS spec §2).
        memCacheWidth: (size * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0))
            .round()
            .clamp(64, 256),
        errorWidget: (_, __, ___) => fallback,
      );
    } else {
      child = fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}
