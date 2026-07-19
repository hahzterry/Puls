// Native/fallback implementation — a release build can't restart itself,
// so this is intentionally a no-op. (The error card is still useful: it
// tells the user something broke and the team has been notified, instead
// of showing Flutter's default red stack-trace screen.)
void reloadApp() {
  // No-op on non-web platforms.
}
