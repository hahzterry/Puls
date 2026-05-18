import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

String _proxied(String url) {
  if (!kIsWeb || url.isEmpty) return url;
  // weserv.nl adds Access-Control-Allow-Origin: * — confirmed working
  return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}&w=600&output=webp';
}

Widget networkImage(
  String url, {
  double? height,
  double? width,
  BoxFit fit = BoxFit.cover,
}) {
  if (url.isEmpty) return const SizedBox.shrink();
  return Image.network(
    _proxied(url),
    height: height,
    width: width,
    fit: fit,
    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
  );
}
