import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget buildWebVideoWidget(String url, {bool loop = true}) {
  final viewId = 'video-${url.hashCode}';

  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final video = web.document.createElement('video') as web.HTMLVideoElement
      ..src = url
      ..setAttribute('crossorigin', 'anonymous')
      ..setAttribute('playsinline', '')
      ..setAttribute('webkit-playsinline', '')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..autoplay = false
      ..loop = loop
      ..muted = false
      ..controls = true;
    return video;
  });

  return HtmlElementView(viewType: viewId);
}
