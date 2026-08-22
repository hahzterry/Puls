import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../widgets/tab_visibility.dart';

/// ── Animation governor ────────────────────────────────────────────────────────
///
/// Two structural widgets that mute animation tickers Flutter-wide whenever the
/// work they drive cannot be seen. Muting (via `TickerMode`) freezes a ticker's
/// clock — no ticks, no rebuilds, no raster work — and unmuting resumes from
/// the exact frame where it stopped, so pausing is visually undetectable.
///
/// Both gates are fail-safe by construction: there is no pause/resume
/// bookkeeping of our own to get wrong; the framework owns ticker lifecycle.
///
/// Used by the FPS performance pass (see
/// docs/superpowers/specs/2026-08-22-fps-performance-design.md §1).

/// Mutes every ticker in [child] while the browser tab is hidden.
///
/// Wrap the app once via `MaterialApp.builder` so all routes, dialogs and
/// sheets are covered. A hidden tab then burns zero animation frames instead
/// of running every marquee/aurora/pulse loop at full rate in the background.
class TabPulseGate extends StatelessWidget {
  const TabPulseGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    TabVisibility.ensureListening();
    return ValueListenableBuilder<bool>(
      valueListenable: TabVisibility.listenable,
      builder: (context, visible, child) =>
          TickerMode(enabled: visible, child: child!),
      child: child,
    );
  }
}

/// Mutes every ticker in [child] while it is scrolled out of the viewport.
///
/// Built for long pages (the landing page has ~12 sections, several with
/// always-running loops). Follows the same scroll-tick + `localToGlobal`
/// pattern as the page's `_LazySection`/`_Reveal` machinery: position is
/// re-measured on each throttled scroll tick (a cheap transform walk, not a
/// relayout), and the gate only notifies when the inside/outside flip actually
/// changes — scrolling never rebuilds anything above this widget.
///
/// [scrollOffset] is the host page's throttled scroll notifier. [marginPx]
/// extends the "visible" band beyond the viewport so loops resume slightly
/// before their section scrolls into view (default 600px ≈ half a viewport).
class PulseVisibilityGate extends StatefulWidget {
  const PulseVisibilityGate({
    super.key,
    required this.scrollOffset,
    required this.child,
    this.marginPx = 600,
  });

  final ValueListenable<double> scrollOffset;
  final Widget child;
  final double marginPx;

  @override
  State<PulseVisibilityGate> createState() => _PulseVisibilityGateState();
}

class _PulseVisibilityGateState extends State<PulseVisibilityGate> {
  final ValueNotifier<bool> _inside = ValueNotifier<bool>(true);
  Timer? _debounce;
  double _viewportH = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollOffset.addListener(_evaluate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  @override
  void didUpdateWidget(covariant PulseVisibilityGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.scrollOffset, widget.scrollOffset)) {
      oldWidget.scrollOffset.removeListener(_evaluate);
      widget.scrollOffset.addListener(_evaluate);
      _evaluate();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.scrollOffset.removeListener(_evaluate);
    _inside.dispose();
    super.dispose();
  }

  void _evaluate() {
    // Coalesce bursts of scroll ticks into at most one measurement per ~2
    // frames; the gate is a coarse on/off band, not pixel-accurate.
    _debounce ??= Timer(const Duration(milliseconds: 32), () {
      _debounce = null;
      _measure();
    });
  }

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    if (_viewportH == 0) {
      final mq = MediaQuery.maybeSizeOf(context);
      _viewportH = mq?.height ?? 0;
    }
    if (_viewportH == 0) return;
    final m = widget.marginPx;
    final nowInside = bottom > -m && top < _viewportH + m;
    if (_inside.value != nowInside) _inside.value = nowInside;
  }

  @override
  Widget build(BuildContext context) {
    _viewportH = MediaQuery.sizeOf(context).height;
    return ValueListenableBuilder<bool>(
      valueListenable: _inside,
      builder: (context, inside, child) =>
          TickerMode(enabled: inside, child: child!),
      child: widget.child,
    );
  }
}
