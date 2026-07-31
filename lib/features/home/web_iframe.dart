import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ignore: avoid_web_libraries_in_flutter
import 'web_iframe_stub.dart' if (dart.library.js_interop) 'web_iframe_impl.dart';

/// On web: renders a native <iframe> pointing at [url] (e.g. the live
/// terminal at terminal.pulsmarket.tech). On native: returns null so callers
/// can fall back to an in-app preview.
Widget? buildWebIframe(String url) {
  if (!kIsWeb) return null;
  return buildWebIframeWidget(url);
}
