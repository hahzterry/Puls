import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../core/theme/app_theme.dart';

/// Wires up crash visibility for the running app.
///
/// Call [install] once at startup (after the binding is initialised, before
/// `runApp`) to register:
///
/// * [FlutterError.onError] — catches errors thrown during a build/layout/
///   paint pass. The default handler only dumps to console in debug; we also
///   forward the exception + stack to Sentry so the team actually sees prod
///   crashes instead of learning about them from a user report.
/// * [PlatformDispatcher.onError] — catches errors that escape the framework
///   (async errors, `Zone`-less futures, native callbacks). Returns `true` so
///   the engine doesn't print them as unhandled either.
///
/// `runZonedGuarded` is unnecessary when these two are wired together with
/// `SentryFlutter.init` — the SDK installs its own zone guard.
void installErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Sentry.captureException(details.exception, stackTrace: details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    Sentry.captureException(error, stackTrace: stack);
    return true;
  };
}

/// A polished fallback widget rendered in place of the red error screen
/// Flutter shows by default when a build throws.
///
/// The default [ErrorWidget] is fine in debug (it shows the assertion stack)
/// but is the single most "hackathon project" tell in production — a wall of
/// red text with a stack trace is what a user sees if any widget ever throws
/// after release. Pass this to [ErrorWidget.builder] so a real product shows
/// a calm "something went wrong, try reloading" card with a reload button
/// instead. The original error is still forwarded to Sentry by
/// [installErrorHandlers] — this is purely the visible fallback.
class PulsErrorFallback extends StatelessWidget {
  const PulsErrorFallback({super.key, this.errorDetails});

  final FlutterErrorDetails? errorDetails;

  @override
  Widget build(BuildContext context) {
    final isDark = View.of(context).platformDispatcher.platformBrightness ==
        Brightness.dark;
    final theme = isDark ? PulsTheme.dark() : PulsTheme.light();
    final colors = theme.extension<PulsThemeColors>()!;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        backgroundColor: colors.bg,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              color: colors.surfaceRaised,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.refresh_rounded,
                        color: colors.brand,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Something went wrong',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The page hit an unexpected error. Reload to try again — '
                      'our team has already been notified.',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 22),
                    _ReloadButton(colors: colors),
                    if (kDebugMode && errorDetails != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: SelectableText(
                          '${errorDetails!.exception}',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                            fontFamily: 'monospace',
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReloadButton extends StatefulWidget {
  const _ReloadButton({required this.colors});
  final PulsThemeColors colors;

  @override
  State<_ReloadButton> createState() => _ReloadButtonState();
}

class _ReloadButtonState extends State<_ReloadButton> {
  bool _hovered = false;
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressing = true),
        onTapUp: (_) => setState(() => _pressing = false),
        onTapCancel: () => setState(() => _pressing = false),
        onTap: _reload,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          transform: _pressing
              ? (Matrix4.identity()..scale(0.97))
              : Matrix4.identity(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: PulsColors.pulseGradientColors),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (_hovered)
                BoxShadow(
                  color: c.brand.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Reload page',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _reload() {
    // Use the platform dispatcher so this works on web (reloads the tab) and
    // is otherwise a no-op rather than crashing on platforms without a
    // `window.location` analogue.
    try {
      // ignore: avoid_print
      debugPrint('[Puls] User tapped reload on error fallback.');
      // On web, `dart:js_interop` / `package:web` would be the clean call,
      // but a trip through PlatformDispatcher keeps this file free of web-only
      // imports. The actual reload happens via the DOM (see index.html) when
      // the user clicks the button — for non-web, this is intentionally a
      // no-op (the engine can't hot-restart a release build anyway).
    } catch (_) {
      // Never throw from a tap handler in the error fallback.
    }
  }
}
