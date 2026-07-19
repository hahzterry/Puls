// Native/fallback implementation — no-op. Native builds use a different
// analytics path (or none at all), and the call sites shouldn't have to branch.

/// Send an analytics event. No-op on non-web.
void trackEvent(String name, [Map<String, dynamic>? props]) {}

/// Identify the current user for analytics. No-op on non-web.
/// Use an anonymous ID (not PII) — Plausible is cookieless by design and
/// doesn't persist user identities across sessions.
void identifyUser(String anonymousId) {}
