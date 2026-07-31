import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

// Guard against re-registering the same view factory on rebuilds.
final _registered = <String>{};

Widget buildWebIframeWidget(String url) {
  final viewId = 'puls-iframe-${url.hashCode}';

  if (_registered.add(viewId)) {
    ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
        ..src = url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..style.background = '#0A0E1A'
        ..setAttribute('allow', 'clipboard-write; fullscreen')
        ..setAttribute('referrerpolicy', 'no-referrer')
        ..setAttribute('scrolling', 'auto');
      return iframe;
    });
  }

  return HtmlElementView(viewType: viewId);
}
