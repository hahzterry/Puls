import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:puls/core/config.dart';

String _proxied(String url) {
  if (!kIsWeb || url.isEmpty) return url;
  // weserv.nl adds Access-Control-Allow-Origin: * — confirmed working
  return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}&w=600&output=webp';
}

Widget networkImage(String url, {
  double? height,
  double? width,
  BoxFit fit = BoxFit.cover,
}) {
  if (url.isEmpty) return const SizedBox.shrink();
  return CachedNetworkImage(imageUrl: proxifyImageUrl(_proxied(url)),
    height: height,
    width: width,
    fit: fit,
    // Cap the decode to the render size (longest known edge only, so aspect
    // is preserved by the codec) — see FPS spec §2.
    memCacheWidth: width == null
        ? null
        : (width * 2).round().clamp(64, 1600),
    memCacheHeight: height == null
        ? null
        : (height * 2).round().clamp(64, 1600),
    errorWidget: (_, __, ___) => const SizedBox.shrink(),
  );
}
