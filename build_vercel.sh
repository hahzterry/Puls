#!/bin/bash
set -e

# Generate secrets.dart from Vercel environment variables.
# SENTRY_DSN is optional — when unset, the empty default makes Sentry.init a
# safe no-op (useful for preview deploys where we don't want crash telemetry).
printf "const supabaseUrl = '%s';\nconst supabaseAnonKey = '%s';\nconst sentryDsn = '%s';\n" \
  "$SUPABASE_URL" "$SUPABASE_ANON_KEY" "${SENTRY_DSN:-}" > lib/core/secrets.dart

echo "Generated secrets.dart"

# Clone Flutter if not present
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable flutter
fi

# Build web
flutter/bin/flutter build web --wasm --release


