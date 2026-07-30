// Web implementation — updates document.title, <meta property="og:*"> /
// <meta name="twitter:*"> tags, and the browser URL via the History API, so
// the URL stays in sync with the current Flutter screen. A refresh lands the
// user back on the same screen, the URL is shareable, and the back/forward
// buttons work.
//
// Uses `package:web` (already a project dependency — see kv_store_web.dart for
// the existing interop pattern) and `dart:js_interop`'s `.toJS` for the
// popstate callback.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'share_metadata.dart';

/// The site-wide default OG image, defined once in index.html. Used as a
/// fallback when a page doesn't supply its own.
const String _defaultOgImage = 'https://pulsmarket.tech/og-image.png';

String currentPath() {
  try {
    return web.window.location.pathname;
  } catch (_) {
    return '/';
  }
}

String currentHref() {
  try {
    return web.window.location.href;
  } catch (_) {
    return '';
  }
}

void setDocumentTitle(String title) {
  web.document.title = title;
}

void redirectToWebUrl(String url) {
  try {
    web.window.location.href = url;
  } catch (_) {}
}

void pushUrl(String path, {String? title}) {
  try {
    final url = _absolutize(path);
    web.window.history.pushState(null, '', url);
    if (title != null) setDocumentTitle(title);
  } catch (_) {
    // Never throw from URL manipulation — it's a UX enhancement, not critical.
  }
}

void replaceUrl(String path, {String? title}) {
  try {
    final url = _absolutize(path);
    web.window.history.replaceState(null, '', url);
    if (title != null) setDocumentTitle(title);
  } catch (_) {
    // Never throw from URL manipulation — it's a UX enhancement, not critical.
  }
}

void setShareMetadata(ShareMetadata meta) {
  try {
    setDocumentTitle(meta.title);
    _setMeta('property', 'og:title', meta.ogTitle);
    _setMeta('property', 'og:description', meta.ogDescription);
    _setMeta('property', 'og:image', meta.ogImage ?? _defaultOgImage);
    if (meta.ogUrl != null) _setMeta('property', 'og:url', meta.ogUrl!);
    _setMeta('name', 'twitter:card', meta.twitterCard);
    _setMeta('name', 'twitter:title', meta.twitterTitle ?? meta.ogTitle);
    _setMeta(
      'name',
      'twitter:description',
      meta.twitterDescription ?? meta.ogDescription,
    );
    _setMeta(
      'name',
      'twitter:image',
      meta.twitterImage ?? meta.ogImage ?? _defaultOgImage,
    );
  } catch (_) {
    // Meta tag updates are a UX enhancement; never throw.
  }
}

void resetShareMetadata() {
  try {
    setDocumentTitle(
      'Puls — The Market for What Happens Next | Prediction Markets on Arc™ Network',
    );
    _setMeta('property', 'og:title', 'Puls — The Market for What Happens Next');
    _setMeta(
      'property',
      'og:description',
      'Swipe to trade predictions — and go head-to-head with live AI agents. '
          'Funded in USDC on Arc. Sign in with Google and place your first '
          'prediction in under a minute.',
    );
    _setMeta('property', 'og:image', _defaultOgImage);
    _setMeta('name', 'twitter:card', 'summary_large_image');
    _setMeta('name', 'twitter:title', 'Puls — Can you beat the AI?');
    _setMeta(
      'name',
      'twitter:description',
      'Swipe to trade predictions and go head-to-head with live AI agents. '
          'USDC on Arc — sign in with Google to play.',
    );
    _setMeta('name', 'twitter:image', _defaultOgImage);
  } catch (_) {
    // Meta tag updates are a UX enhancement; never throw.
  }
}

void Function() onPopState(void Function(String path) callback) {
  final jsCallback = ((web.Event _) {
    try {
      callback(web.window.location.pathname);
    } catch (_) {
      callback('/');
    }
  }).toJS;
  try {
    web.window.addEventListener('popstate', jsCallback);
  } catch (_) {
    return () {};
  }
  return () {
    try {
      web.window.removeEventListener('popstate', jsCallback);
    } catch (_) {
      // Best-effort cleanup.
    }
  };
}

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Set (or create if missing) a `<meta>` tag's content. Handles both
/// `property="og:*"` and `name="twitter:*"` flavours via [attr].
void _setMeta(String attr, String key, String content) {
  final selector = 'meta[$attr="$key"]';
  var el = web.document.querySelector(selector);
  if (el == null) {
    // Tag doesn't exist yet — create it. (index.html ships the common OG tags
    // so this branch only runs for unusual keys.)
    final meta = web.document.createElement('meta') as web.HTMLMetaElement;
    meta.setAttribute(attr, key);
    meta.content = content;
    web.document.head?.appendChild(meta);
    return;
  }
  // Existing tag — update its content.
  if (el is web.HTMLMetaElement) {
    el.content = content;
  } else {
    el.setAttribute('content', content);
  }
}

/// Resolve [path] (which may be relative like `/pulse`) against the current
/// origin so pushState/replaceState get a valid URL.
String _absolutize(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  if (!path.startsWith('/')) path = '/$path';
  try {
    final origin = web.window.location.origin;
    return '$origin$path';
  } catch (_) {
    return path;
  }
}
