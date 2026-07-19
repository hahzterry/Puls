// Native/fallback implementation — no browser URL or document metadata to
// update, so everything is a no-op. (Calls remain safe to make from shared
// widget code; they just do nothing on iOS/Android.)

import 'share_metadata.dart';

/// The current URL path. On non-web, there's no URL — return '/' so callers
/// don't have to branch.
String currentPath() => '/';

/// The full current URL (path + query + hash). Empty on non-web.
String currentHref() => '';

/// Update the browser tab title. No-op on non-web.
void setDocumentTitle(String title) {}

/// Push a new URL onto the browser history without navigating (so the back
/// button works). No-op on non-web.
void pushUrl(String path, {String? title}) {}

/// Replace the current URL in-place (no new history entry). No-op on non-web.
void replaceUrl(String path, {String? title}) {}

/// Update OG/Twitter meta tags for social sharing. No-op on non-web.
void setShareMetadata(ShareMetadata meta) {}

/// Reset OG/Twitter meta tags to the site defaults. No-op on non-web.
void resetShareMetadata() {}

/// Register a callback for browser back/forward navigation. Returns a
/// disposer; calling it removes the listener. Always returns a no-op
/// disposer on non-web.
void Function() onPopState(void Function(String path) callback) => () {};
