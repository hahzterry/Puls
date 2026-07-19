// Cross-platform "reload the app" helper used by the production error
// fallback card. On web it reloads the browser tab (the only sane way to
// recover from a broken widget tree); on other platforms it's a no-op
// because a release build can't hot-restart itself.
export 'web_reload_io.dart'
    if (dart.library.js_interop) 'web_reload_web.dart';
