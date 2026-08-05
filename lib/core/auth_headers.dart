import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'utils/kv_store.dart' show kvGet;

/// Builds an authenticated JSON header map for Puls backend calls.
///
/// On a cold web load `currentSession` may not be restored yet, or it may hold
/// an expired access token (Supabase JWTs expire ~1h and reading the cached
/// session does NOT refresh it). Sending that stale/absent token makes the
/// server's `supabase.auth.getUser()` reject the request with 401. So we
/// proactively refresh when the session is missing or about to expire.
Future<Map<String, String>> pulsAuthHeaders() async {
  final auth = Supabase.instance.client.auth;
  var s = auth.currentSession;

  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final needsRefresh =
      s == null || (s.expiresAt != null && s.expiresAt! - nowSec < 60);
  if (needsRefresh) {
    try {
      final res = await auth.refreshSession();
      s = res.session ?? auth.currentSession;
    } catch (_) {
      s = auth.currentSession;
    }
  }

  final h = <String, String>{'Content-Type': 'application/json'};
  if (s != null) h['Authorization'] = 'Bearer ${s.accessToken}';
  return h;
}

/// Variant that prefers the direct-auth token persisted under `direct_auth`
/// in kv-store, falling back to the Supabase session.
Future<Map<String, String>> pulsAuthHeadersWithDirectAuth() async {
  final headers = <String, String>{};
  try {
    final raw = kvGet('direct_auth');
    if (raw != null && raw.isNotEmpty) {
      final saved = jsonDecode(raw) as Map<String, dynamic>?;
      final token = saved?['token'] as String?;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        return headers;
      }
    }
  } catch (_) {}
  try {
    final auth = Supabase.instance.client.auth;
    var session = auth.currentSession;
    session ??= (await auth.refreshSession()).session;
    if (session?.accessToken != null) {
      headers['Authorization'] = 'Bearer ${session!.accessToken}';
    }
  } catch (_) {}
  return headers;
}
