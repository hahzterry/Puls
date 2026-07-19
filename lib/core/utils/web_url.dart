// Cross-platform URL + document metadata helper for web deep-linking.
//
// On web, this updates `document.title`, `<meta property="og:*">` /
// `<meta name="twitter:*">` tags, and uses the History API (`pushState` /
// `replaceState`) so the browser URL stays in sync with the current Flutter
// screen — which means a refresh lands the user back on the same screen and
// the URL is shareable.
//
// On non-web platforms this is a no-op (no browser URL to update).
library web_url;

export 'share_metadata.dart';
export 'web_url_io.dart' if (dart.library.js_interop) 'web_url_web.dart';
