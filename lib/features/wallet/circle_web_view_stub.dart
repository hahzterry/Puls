import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'circle_web_view.dart';

void openUrlInNewTab(String url) {
  web.window.open(url, '_blank');
}

Widget buildNativeWebView(BuildContext context, CircleWebView widget) {
  return const SizedBox.shrink();
}
