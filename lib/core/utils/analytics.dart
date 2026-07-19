// Cross-platform analytics — sends events to Plausible on web (cookieless,
// so no EU/UK consent banner required) and is a no-op on other platforms.
//
// Events are sent by calling `window.plausible('EventName', { props: {...} })`
// — the Plausible script (added to index.html) handles the network call.
//
// On non-web, this is a no-op: native builds use a different analytics path
// (or none at all), and the call sites shouldn't have to branch.
export 'analytics_io.dart' if (dart.library.js_interop) 'analytics_web.dart';
