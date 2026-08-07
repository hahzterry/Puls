import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/puls_app_state.dart';
import '../../core/motion.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/puls_fade_in.dart';
import '../../data/models/market.dart';
import 'feed_controls.dart';
import 'prediction_feed_card.dart';

/// Shared stateful feed stream — search, pills, keyboard, undo, cards.
///
/// Used by both mobile (_FeedBody) and desktop (_WebFeedBody center column).
/// Owns query state, focus tracking, and pending-trade countdown.
class FeedStream extends StatefulWidget {
  const FeedStream({
    required this.appState,
    required this.allMarkets,
    required this.categories,
    required this.onOpenDetails,
    required this.onFastBuy,
    required this.onTradePreview,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 120),
    this.maxWidth,
    super.key,
  });

  final PulsAppState appState;
  final List<Market> allMarkets;
  final List<String> categories;
  final void Function(BuildContext, Market) onOpenDetails;
  final Future<void> Function(BuildContext, PulsAppState, Market, MarketSide)
      onFastBuy;
  final void Function(BuildContext, Market, MarketSide) onTradePreview;
  final EdgeInsets padding;
  final double? maxWidth;

  @override
  State<FeedStream> createState() => _FeedStreamState();
}

class _FeedStreamState extends State<FeedStream> {
  static const _undoWindow = Duration(seconds: 3);

  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  var _query = const FeedQuery();
  var _density = FeedDensity.comfortable;
  var _focusedIndex = -1;
  PendingTrade? _pendingTrade;
  Timer? _pendingTimer;

  /// Per-row keys so arrow-key focus can scroll itself into view.
  final _cardKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // Keyboard nav on web — ↑/↓ moves focus, Enter opens, Y/N buys.
      ServicesBinding.instance.keyboard.addHandler(_handleKey);
    }
  }

  /// Runs while the element is still in the tree, so scope lookups inside
  /// [FeedStream.onFastBuy] still resolve. A staged trade the user did not
  /// take back is theirs — commit it rather than silently dropping it.
  @override
  void deactivate() {
    final pending = _pendingTrade;
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _pendingTrade = null;
    if (pending != null) {
      widget.onFastBuy(
          context, widget.appState, pending.market, pending.side);
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    if (kIsWeb) {
      ServicesBinding.instance.keyboard.removeHandler(_handleKey);
    }
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;

    // The handler is global, but the feed is not always on top — without this
    // check, pressing Y on a market detail screen would buy on the feed's
    // focused card behind it.
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    final key = event.logicalKey;

    // While typing, the field owns every key — otherwise "yes" would fire two
    // trades. Escape is the way out of the field.
    if (_searchFocus.hasFocus) {
      if (key == LogicalKeyboardKey.escape) {
        _searchFocus.unfocus();
        return true;
      }
      return false;
    }

    // Any other text field on screen (trade sheet, comment box) keeps its keys.
    final primary = FocusManager.instance.primaryFocus?.context?.widget;
    if (primary is EditableText) return false;

    // "/" jumps to search — the shortcut people already try.
    if (key == LogicalKeyboardKey.slash) {
      _searchFocus.requestFocus();
      return true;
    }

    // Escape takes back a staged trade before it clears the focus ring.
    if (key == LogicalKeyboardKey.escape) {
      if (_pendingTrade != null) {
        _undoTrade();
      } else if (_focusedIndex >= 0) {
        setState(() => _focusedIndex = -1);
      } else {
        return false;
      }
      return true;
    }

    final filtered = _applyQuery();
    if (filtered.isEmpty) return false;

    // Arrow up/down: focus ring moves between cards, scrolling it into view.
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final delta = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      final next = (_focusedIndex < 0 ? 0 : _focusedIndex + delta)
          .clamp(0, filtered.length - 1);
      setState(() => _focusedIndex = next);
      _revealFocused();
      return true;
    }

    if (_focusedIndex < 0 || _focusedIndex >= filtered.length) return false;
    final market = filtered[_focusedIndex];

    if (key == LogicalKeyboardKey.enter) {
      widget.onOpenDetails(context, market);
      return true;
    }
    if (key == LogicalKeyboardKey.keyY) {
      _buyWithUndo(market, MarketSide.yes);
      return true;
    }
    if (key == LogicalKeyboardKey.keyN) {
      _buyWithUndo(market, MarketSide.no);
      return true;
    }

    return false;
  }

  /// Scrolls the keyboard-focused card into view. Only built rows have a
  /// context, which is fine: focus moves one step at a time from a visible row.
  void _revealFocused() {
    final ctx = _cardKeys[_focusedIndex]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.25,
      duration: context.motionDuration(const Duration(milliseconds: 240)),
      curve: PulsCurves.easeOutMagical,
    );
  }

  GlobalKey _keyFor(int index) =>
      _cardKeys.putIfAbsent(index, () => GlobalKey());

  /// Keeps the controls on the same column width as the cards on desktop.
  Widget _constrain(Widget child) => widget.maxWidth == null
      ? child
      : Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth!),
            child: child,
          ),
        );

  /// Fast-buy sends immediately with no confirm step, so that is the path that
  /// needs a way out: hold it for [_undoWindow] with a visible countdown and
  /// only send if the user doesn't take it back. The preview-sheet path already
  /// has a confirm and goes straight through.
  void _buyWithUndo(Market market, MarketSide side) {
    if (!widget.appState.fastBuyEnabled) {
      widget.onTradePreview(context, market, side);
      return;
    }

    // One staged trade at a time — a second swipe commits the first.
    _commitPending();

    final pending =
        PendingTrade(market: market, side: side, window: _undoWindow);
    setState(() => _pendingTrade = pending);
    _pendingTimer = Timer(_undoWindow, () {
      if (!mounted) return;
      setState(() => _pendingTrade = null);
      _pendingTimer = null;
      widget.onFastBuy(context, widget.appState, pending.market, pending.side);
    });
  }

  /// Sends the staged trade now, if any. Does not call setState — callers own
  /// the rebuild.
  void _commitPending() {
    final pending = _pendingTrade;
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _pendingTrade = null;
    if (pending != null) {
      widget.onFastBuy(context, widget.appState, pending.market, pending.side);
    }
  }

  void _undoTrade() {
    hapticLight();
    _pendingTimer?.cancel();
    _pendingTimer = null;
    setState(() => _pendingTrade = null);
  }

  List<Market> _applyQuery() =>
      _query.apply(widget.allMarkets, widget.appState.watchlistIds.toSet());

  int _countFor({FeedSmartFilter? filter, String? category}) {
    final q = FeedQuery(filter: filter, category: category);
    return q.apply(widget.allMarkets, widget.appState.watchlistIds.toSet()).length;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyQuery();
    final compact = _density == FeedDensity.compact;

    final controls = Padding(
      padding: EdgeInsets.fromLTRB(
        widget.padding.left,
        8,
        widget.padding.right,
        0,
      ),
      child: _constrain(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: FeedSearchField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    matchCount: filtered.length,
                    showCount: _query.hasText,
                    onChanged: (val) => setState(() {
                      _query = _query.copyWith(text: val);
                      _focusedIndex = -1;
                    }),
                    onClear: () {
                      _searchCtrl.clear();
                      setState(() {
                        _query = _query.copyWith(text: '');
                        _focusedIndex = -1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                FeedDensityToggle(
                  density: _density,
                  onChanged: (d) => setState(() => _density = d),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FeedFilterPills(
              query: _query,
              categories: widget.categories,
              countFor: _countFor,
              onSmartFilter: (f) => setState(() {
                _query = _query.copyWith(filter: f, clearFilter: f == null);
                _focusedIndex = -1;
              }),
              onCategory: (c) => setState(() {
                _query = _query.copyWith(category: c, clearCategory: c == null);
                _focusedIndex = -1;
              }),
            ),
          ],
        ),
      ),
    );

    // The endless loop is what makes a small market set feel like a feed, but
    // it turns a 2-hit search into an infinite repeat of the same two cards.
    // So: loop only while nothing is filtered.
    final loop = !_query.isActive && !compact;

    final list = filtered.isEmpty
        ? FeedNoResults(
            query: _query,
            onClear: () {
              _searchCtrl.clear();
              setState(() {
                _query = const FeedQuery();
                _focusedIndex = -1;
              });
            },
          )
        : ListView.builder(
            padding: widget.padding.copyWith(top: 14),
            itemCount: loop ? 1000 : filtered.length,
            itemBuilder: (ctx, i) {
              final index = i % filtered.length;
              final market = filtered[index];
              final focused = kIsWeb && _focusedIndex == i;

              final Widget child = compact
                  ? CompactMarketCard(
                      market: market,
                      focused: focused,
                      isWatchlisted: widget.appState.isWatchlisted(market.id),
                      onWatchlist: () =>
                          widget.appState.toggleWatchlist(market.id),
                      onDetails: () => widget.onOpenDetails(ctx, market),
                      onChoose: (side) => _buyWithUndo(market, side),
                    )
                  : PredictionFeedCard(
                      market: market,
                      focused: focused,
                      showSwipeHint: i == 0,
                      isWatchlisted: widget.appState.isWatchlisted(market.id),
                      onWatchlist: () =>
                          widget.appState.toggleWatchlist(market.id),
                      onDetails: () => widget.onOpenDetails(ctx, market),
                      onChoose: (side) => _buyWithUndo(market, side),
                    );

              final row = Padding(
                key: _keyFor(i),
                padding: EdgeInsets.only(bottom: compact ? 10 : 16),
                child: widget.maxWidth == null
                    ? child
                    : Center(
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: widget.maxWidth!),
                          child: child,
                        ),
                      ),
              );

              return PulsFadeIn(
                key: ValueKey('feed_${market.id}_$i'),
                child: row,
              );
            },
          );

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            controls,
            Expanded(child: list),
          ],
        ),
        // Slides up from the bottom edge, so it reads as a consequence of the
        // swipe rather than a dialog that interrupts it.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSwitcher(
            duration: context.motionDuration(const Duration(milliseconds: 260)),
            switchInCurve: PulsCurves.easeOutMagical,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.6),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: _pendingTrade == null
                ? const SizedBox(width: double.infinity)
                : UndoTradeBar(
                    key: ValueKey(_pendingTrade),
                    pending: _pendingTrade!,
                    onUndo: _undoTrade,
                  ),
          ),
        ),
      ],
    );
  }
}
