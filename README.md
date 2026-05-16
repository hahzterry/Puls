# Puls

Puls is an Android-first Flutter UI prototype for a premium prediction-market app. The prototype uses mock data only: no backend, no wallet, no real authentication, and no real trading.

## Current State

This repo contains the Flutter source, design spec, mock data, and tests. Flutter is not currently installed on this machine, so SDK-generated Android files are not included yet.

After installing Flutter, generate the platform files and run the app:

```powershell
flutter create . --platforms=android
flutter pub get
flutter run
```

## Prototype Scope

- Light onboarding
- Puls Feed as the home screen
- Vertical TikTok-style prediction cards
- Yes/No reaction flow with demo trade preview
- Discover, market detail, portfolio, watchlist, and profile tabs
- Mock data with MVP-ready repository boundaries

See the design spec at `docs/superpowers/specs/2026-05-16-puls-flutter-ui-prototype-design.md`.
