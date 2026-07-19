// Web implementation — sends events to Plausible via window.plausible().
// Plausible is cookieless (GDPR-compliant by default — no consent banner
// required in EU/UK), so events can fire immediately on first load without
// any user opt-in.
//
// Uses `dart:js_interop` (already a project dependency — the same interop
// pattern used by kv_store_web.dart). The Plausible script (added to
// index.html) defines `window.plausible` as a global JS function.

import 'dart:js_interop';

/// The JS global `window` object, accessed via `dart:js_interop`'s
/// `globalContext`. Using `js_util` here (rather than `package:web`) keeps
/// this file free of the heavier `package:web` dependency — the call we
/// need is a single global function lookup.
@JS('window.plausible')
external void _plausible(String eventName, [JSAny? arg]);

/// Send a custom event to Plausible. Plausible's custom-events API expects
/// `window.plausible('EventName', { props: { key: value, ... } })`.
///
/// Events are fire-and-forget — if the Plausible script hasn't loaded yet
/// (e.g. the user navigates very fast on first load), the event is silently
/// dropped rather than blocking the UI. This is the right trade-off for
/// analytics: it's better to lose an event than to crash the app.
void trackEvent(String name, [Map<String, dynamic>? props]) {
  try {
    if (props == null || props.isEmpty) {
      // No props — call with just the event name.
      _plausible(name);
      return;
    }
    // Build the { props: {...} } argument as a JS object via jsify.
    final propsJs = props.jsify();
    final arg = {'props': propsJs}.jsify();
    _plausible(name, arg);
  } catch (_) {
    // Never throw from analytics — it's a UX enhancement, not critical.
  }
}

/// Identify the current user for analytics. Plausible is cookieless by
/// design — it doesn't persist user identities across sessions. This is a
/// no-op kept for API symmetry with the native implementation; on web, all
/// events are anonymous by default (which is the GDPR-compliant default).
void identifyUser(String anonymousId) {
  // No-op on Plausible — it's cookieless and doesn't track user identities.
}
