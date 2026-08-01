// Web implementation: GET with `credentials: include` so the HttpOnly
// puls_session cookie (set by the backend OAuth callback on .pulsmarket.tech)
// is sent cross-origin. Returns the parsed JSON body, or null on any failure.
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<Map<String, dynamic>?> fetchSessionWithCookies(String url) async {
  try {
    final res = await web.window.fetch(
      url.toJS,
      web.RequestInit(
        method: 'GET',
        credentials: 'include',
      ),
    ).toDart;
    if (res.status != 200) return null;
    final text = await res.text().toDart;
    final data = jsonDecode(text.toDart);
    return data is Map<String, dynamic> ? data : null;
  } catch (_) {
    return null;
  }
}
