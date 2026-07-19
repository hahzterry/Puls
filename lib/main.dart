import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/error_reporting.dart';
import 'app/puls_app.dart';
import 'core/secrets.dart';
import 'core/utils/kv_store.dart';

Future<void> main() async {
  // Preserve the referral-capture ordering: binding first, then url strategy,
  // then Sentry init (which wraps runApp so the SDK can install its zone guard
  // before any widget is built).
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  // Capture an inbound referral code (?ref=CODE) BEFORE Google OAuth redirects
  // away — we persist it to localStorage so it survives the round-trip and can
  // be auto-claimed once the invitee signs in. See WalletService._maybeClaimReferral.
  _captureReferralCode();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // Sentry init must happen before runApp so the SDK can install its zone
  // guard. An empty DSN is a safe no-op (the SDK short-circuits when no DSN
  // is configured, so no events are sent and no network traffic is generated),
  // which is the right default for local dev.
  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      // PII redaction: don't ship user IPs to Sentry by default.
      options.sendDefaultPii = false;
      // Sample 100% of sessions in release builds so we actually see the
      // crash rate. Drop to e.g. 0.2 once volume justifies it.
      options.tracesSampleRate = 1.0;
    },
    appRunner: () {
      // Install the framework-level error handlers BEFORE runApp so any error
      // thrown during the first build is captured.
      installErrorHandlers();
      runApp(const PulsApp());
    },
  );
}

void _captureReferralCode() {
  try {
    final raw = Uri.base.queryParameters['ref'];
    if (raw == null) return;
    final code = raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (code.isNotEmpty && code.length <= 12) {
      kvSet('puls_ref', code);
    }
  } catch (_) {
    // Never block app startup over a malformed URL.
  }
}
