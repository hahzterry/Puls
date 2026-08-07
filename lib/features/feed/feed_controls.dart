import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/motion.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/trade_math.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/tactile.dart';
import '../../data/models/market.dart';

/// Route market artwork through the resizing proxy on web — the source images
/// are frequently 1–2 MB PNGs that would otherwise stall the first paint.
String proxiedMarketImage(String url) {
  if (!kIsWeb || url.isEmpty) return url;
  return 'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}&w=600&output=webp';
}

// ── Query model ───────────────────────────────────────────────────────────────

/// Card size. [compact] trades the hero image and sparkline for ~2.5× the
/// markets per screen — the density traders ask for once they know the feed.
enum FeedDensity { comfortable, compact }

/// The "smart" pills. Every one of these is derived from a field the market
/// model actually carries, so none of them lie:
///   - [trending]   → `volume24hr`
///   - [endingSoon] → `deadline` inside 14 days
///   - [featured]   → `isFeatured`
///   - [agents]     → `createdByAgent`
///   - [watchlist]  → the user's saved ids
///
/// There is deliberately no "New" pill: `Market` has no creation timestamp, so
/// it could only ever be faked. [featured] fills that slot with a real signal.
enum FeedSmartFilter { trending, endingSoon, featured, agents, watchlist }

extension FeedSmartFilterX on FeedSmartFilter {
  String get label => switch (this) {
        FeedSmartFilter.trending => 'Trending',
        FeedSmartFilter.endingSoon => 'Ending soon',
        FeedSmartFilter.featured => 'Featured',
        FeedSmartFilter.agents => 'Agents',
        FeedSmartFilter.watchlist => 'Watchlist',
      };

  IconData get icon => switch (this) {
        FeedSmartFilter.trending => Icons.local_fire_department_rounded,
        FeedSmartFilter.endingSoon => Icons.timer_outlined,
        FeedSmartFilter.featured => Icons.auto_awesome_rounded,
        FeedSmartFilter.agents => Icons.smart_toy_outlined,
        FeedSmartFilter.watchlist => Icons.bookmark_rounded,
      };
}

/// Sort order, kept as its own axis from [FeedSmartFilter] so "Crypto, by
/// volume" is expressible. Pills used to own sorting, which made those two
/// choices fight over one slot.
enum FeedSort { hot, volume, endingSoon, closest }

extension FeedSortX on FeedSort {
  String get label => switch (this) {
        FeedSort.hot => 'Hot',
        FeedSort.volume => '24h volume',
        FeedSort.endingSoon => 'Ending soonest',
        FeedSort.closest => 'Closest call',
      };

  IconData get icon => switch (this) {
        FeedSort.hot => Icons.bolt_rounded,
        FeedSort.volume => Icons.bar_chart_rounded,
        FeedSort.endingSoon => Icons.timer_outlined,
        FeedSort.closest => Icons.balance_rounded,
      };
}

/// Immutable feed filter state — free-text search + one smart pill + one
/// category + sort. Kept as a value object so the list rebuild is a pure
/// function of (markets, query, watchlist).
@immutable
class FeedQuery {
  const FeedQuery({
    this.text = '',
    this.filter,
    this.category,
    this.sort = FeedSort.hot,
  });

  final String text;
  final FeedSmartFilter? filter;
  final String? category;
  final FeedSort sort;

  bool get hasText => text.trim().isNotEmpty;
  bool get isActive => hasText || filter != null || category != null;

  /// Whether the result order is something other than the feed's own ranking.
  bool get isSorted => sort != FeedSort.hot;

  FeedQuery copyWith({
    String? text,
    FeedSmartFilter? filter,
    String? category,
    FeedSort? sort,
    bool clearFilter = false,
    bool clearCategory = false,
  }) =>
      FeedQuery(
        text: text ?? this.text,
        filter: clearFilter ? null : (filter ?? this.filter),
        category: clearCategory ? null : (category ?? this.category),
        sort: sort ?? this.sort,
      );

  /// Filter + sort in one pass. Search matches the question, category and
  /// tags — the three things people actually type. Words are ANDed and may
  /// land in different fields, so "btc 2025" matches a Crypto market asking
  /// about 2025 even though no single field holds both words.
  List<Market> apply(List<Market> markets, Set<String> watchlistIds) {
    final words = text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final now = DateTime.now();

    final out = markets.where((m) {
      if (category != null && m.category != category) return false;

      switch (filter) {
        case FeedSmartFilter.featured:
          if (!m.isFeatured) return false;
        case FeedSmartFilter.agents:
          if (!m.createdByAgent) return false;
        case FeedSmartFilter.watchlist:
          if (!watchlistIds.contains(m.id)) return false;
        case FeedSmartFilter.endingSoon:
          final left = m.deadline.difference(now);
          if (left.isNegative || left.inDays > 14) return false;
        case FeedSmartFilter.trending:
          // Now that sorting is its own axis, this pill has to *filter*
          // something or it does nothing: markets with real 24h flow.
          if (m.volume24hr <= 0) return false;
        case null:
          break;
      }

      if (words.isEmpty) return true;

      // Haystack: question + category + tag list concatenated.
      final haystack =
          '${m.question} ${m.category} ${m.tags.join(' ')}'.toLowerCase();

      // Every word must appear somewhere in the combined haystack for an AND.
      return words.every((w) => haystack.contains(w));
    }).toList();

    // Sort is its own axis now — the pill no longer decides order, so
    // "Crypto, by volume" and "Watchlist, ending soonest" both work.
    switch (sort) {
      case FeedSort.hot:
        // The feed arrives ranked by Puls-native activity. Leave it be.
        break;
      case FeedSort.volume:
        out.sort((a, b) {
          final byDay = b.volume24hr.compareTo(a.volume24hr);
          return byDay != 0 ? byDay : b.volumeNum.compareTo(a.volumeNum);
        });
      case FeedSort.endingSoon:
        out.sort((a, b) => a.deadline.compareTo(b.deadline));
      case FeedSort.closest:
        // Nearest to a coin-flip first — that's where disagreement lives.
        out.sort((a, b) =>
            (a.yesPrice - 0.5).abs().compareTo((b.yesPrice - 0.5).abs()));
    }

    return out;
  }
}

// ── Keyboard cheat sheet ──────────────────────────────────────────────────────

/// One row of the shortcut sheet.
const _shortcuts = <(String, String)>[
  ('↑  ↓', 'Move between markets'),
  ('Enter', 'Open the focused market'),
  ('Y', 'Buy YES on the focused market'),
  ('N', 'Buy NO on the focused market'),
  ('/', 'Jump to search'),
  ('Esc', 'Clear focus, or leave search'),
  ('?', 'Show this sheet'),
];

/// Shortcuts exist but are invisible, so nobody finds them. `?` opens this.
Future<void> showFeedShortcuts(BuildContext context) {
  final t = context.puls;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: pulsCardDecoration(
              t,
              radius: 22,
              isDark: Theme.of(ctx).brightness == Brightness.dark,
              raised: true,
              accent: t.brand,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: t.brandSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.keyboard_rounded,
                          size: 16, color: t.brand),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Keyboard',
                        style: TextStyle(
                          color: t.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    Tactile(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Icon(Icons.close_rounded,
                          size: 18, color: t.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final (keys, what) in _shortcuts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 74,
                          child: Wrap(
                            spacing: 4,
                            children: keys
                                .split('  ')
                                .map((k) => _Kbd(label: k))
                                .toList(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            what,
                            style: TextStyle(
                              color: t.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// A keycap. Raised surface + hairline, so it reads as a physical key.
class _Kbd extends StatelessWidget {
  const _Kbd({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: t.text,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          fontFeatures: PulsColors.tabularFigures,
        ),
      ),
    );
  }
}

// ── Search field ──────────────────────────────────────────────────────────────

/// Sticky search field. Focus lights a brand ring + glow, the clear button
/// scales in only when there's something to clear, and the match count sits
/// inline so the result of typing is legible without moving your eyes.
class FeedSearchField extends StatefulWidget {
  const FeedSearchField({
    required this.controller,
    required this.focusNode,
    required this.matchCount,
    required this.showCount,
    required this.onChanged,
    required this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int matchCount;
  final bool showCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<FeedSearchField> createState() => _FeedSearchFieldState();
}

class _FeedSearchFieldState extends State<FeedSearchField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (!mounted) return;
    setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final hasText = widget.controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: context.motionDuration(const Duration(milliseconds: 220)),
      curve: PulsCurves.easeOutMagical,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? t.brand : t.border,
          width: _focused ? 1.4 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: t.brand.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          AnimatedScale(
            duration: context.motionDuration(const Duration(milliseconds: 220)),
            curve: PulsCurves.easeOutMagical,
            scale: _focused ? 1.1 : 1.0,
            child: Icon(
              Icons.search_rounded,
              size: 19,
              color: _focused ? t.brand : t.textSubtle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              onChanged: widget.onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                color: t.text,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: t.brand,
              cursorRadius: const Radius.circular(2),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search markets — bitcoin, election, AI…',
                hintStyle: TextStyle(
                  color: t.textSubtle,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          // Match count — only while a search is live, so it never reads as
          // chrome when the field is idle.
          AnimatedSwitcher(
            duration: context.motionDuration(const Duration(milliseconds: 200)),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: widget.showCount
                ? Container(
                    key: ValueKey(widget.matchCount),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: widget.matchCount > 0 ? t.brandSubtle : t.noBg,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      widget.matchCount > 0
                          ? '${widget.matchCount}'
                          : 'no match',
                      style: TextStyle(
                        color: widget.matchCount > 0 ? t.brand : t.no,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        fontFeatures: PulsColors.tabularFigures,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          AnimatedScale(
            duration: context.motionDuration(const Duration(milliseconds: 180)),
            curve: Curves.easeOutBack,
            scale: hasText ? 1 : 0,
            child: hasText
                ? Tactile(
                    onTap: widget.onClear,
                    child: Icon(Icons.close_rounded,
                        size: 18, color: t.textMuted),
                  )
                : const SizedBox(width: 18),
          ),
        ],
      ),
    );
  }
}

// ── Filter pills ──────────────────────────────────────────────────────────────

/// Horizontally scrolling quick filters. Active pill fills with brand and
/// lifts on a matching glow, so the current slice of the feed is obvious at a
/// glance instead of buried in a dropdown.
class FeedFilterPills extends StatelessWidget {
  const FeedFilterPills({
    required this.query,
    required this.categories,
    required this.countFor,
    required this.onSmartFilter,
    required this.onCategory,
    super.key,
  });

  final FeedQuery query;
  final List<String> categories;

  /// Result count for a hypothetical pill — used for the badge.
  final int Function({FeedSmartFilter? filter, String? category}) countFor;
  final ValueChanged<FeedSmartFilter?> onSmartFilter;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    // Fade the strip at both edges so a cut-off pill reads as "keep
    // scrolling" instead of a clipped mistake.
    return SizedBox(
      height: 36,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: [0, 0.02, 0.96, 1],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          children: [
            _Pill(
              label: 'All',
              icon: Icons.bolt_rounded,
              active: query.filter == null && query.category == null,
              count: countFor(),
              t: t,
              onTap: () {
                onSmartFilter(null);
                onCategory(null);
              },
            ),
            for (final f in FeedSmartFilter.values)
              _Pill(
                label: f.label,
                icon: f.icon,
                active: query.filter == f,
                count: countFor(filter: f),
                t: t,
                onTap: () => onSmartFilter(query.filter == f ? null : f),
              ),
            if (categories.isNotEmpty) ...[
              _PillDivider(t: t),
              for (final c in categories)
                _Pill(
                  label: c,
                  active: query.category == c,
                  count: countFor(category: c),
                  t: t,
                  onTap: () => onCategory(query.category == c ? null : c),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PillDivider extends StatelessWidget {
  const _PillDivider({required this.t});
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        color: t.border,
      );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.active,
    required this.count,
    required this.t,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final int count;
  final PulsThemeColors t;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // A pill that would return nothing stays tappable but reads as inert, so
    // nobody spends a tap to discover an empty list.
    final empty = count == 0 && !active;
    final fg = active
        ? Colors.white
        : empty
            ? t.textSubtle
            : t.textMuted;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tactile(
        onTap: () {
          hapticLight();
          onTap();
        },
        pressedScale: 0.96,
        child: AnimatedContainer(
          duration: context.motionDuration(const Duration(milliseconds: 220)),
          curve: PulsCurves.easeOutMagical,
          padding: const EdgeInsets.only(left: 13, right: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? t.brand : t.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: active
                  ? t.brand
                  : empty
                      ? t.border.withValues(alpha: 0.5)
                      : t.border,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: t.brand.withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 7),
              // Counts sit in their own capsule: at a glance the strip reads as
              // label + volume, and the digits stop colliding with the label.
              AnimatedContainer(
                duration:
                    context.motionDuration(const Duration(milliseconds: 220)),
                curve: PulsCurves.easeOutMagical,
                constraints: const BoxConstraints(minWidth: 22),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withValues(alpha: 0.22)
                      : t.surfaceRaised,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: active ? Colors.white : t.textSubtle,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    fontFeatures: PulsColors.tabularFigures,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Density toggle ────────────────────────────────────────────────────────────

/// Sort dropdown. Active sort shows in button, tap opens menu. "Hot" is the
/// feed's own ranking (default), others impose a reorder.
class FeedSortDropdown extends StatelessWidget {
  const FeedSortDropdown(
      {required this.sort, required this.onChanged, super.key});

  final FeedSort sort;
  final ValueChanged<FeedSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return PopupMenuButton<FeedSort>(
      initialValue: sort,
      onSelected: onChanged,
      offset: const Offset(0, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: t.surfaceRaised,
      elevation: 8,
      tooltip: 'Sort order',
      child: AnimatedContainer(
        duration: context.motionDuration(const Duration(milliseconds: 220)),
        curve: PulsCurves.easeOutMagical,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: sort == FeedSort.hot ? t.border : t.brand),
          boxShadow: sort != FeedSort.hot
              ? [
                  BoxShadow(
                    color: t.brand.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sort.icon,
                size: 14, color: sort == FeedSort.hot ? t.textMuted : t.brand),
            const SizedBox(width: 6),
            Text(
              sort.label,
              style: TextStyle(
                color: sort == FeedSort.hot ? t.textMuted : t.brand,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 16, color: sort == FeedSort.hot ? t.textMuted : t.brand),
          ],
        ),
      ),
      itemBuilder: (ctx) => FeedSort.values.map((s) {
        final active = s == sort;
        return PopupMenuItem(
          value: s,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(s.icon, size: 15, color: active ? t.brand : t.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.label,
                  style: TextStyle(
                    color: active ? t.brand : t.text,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (active)
                Icon(Icons.check_rounded, size: 16, color: t.brand),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Two-icon segmented control with a sliding brand thumb.
class FeedDensityToggle extends StatelessWidget {
  const FeedDensityToggle(
      {required this.density, required this.onChanged, super.key});

  final FeedDensity density;
  final ValueChanged<FeedDensity> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final compact = density == FeedDensity.compact;
    return Semantics(
      label: compact ? 'Compact cards' : 'Comfortable cards',
      button: true,
      child: Tooltip(
        message: compact ? 'Switch to large cards' : 'Switch to compact cards',
        child: Container(
          height: 36,
          width: 72,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: t.border),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration:
                    context.motionDuration(const Duration(milliseconds: 240)),
                curve: PulsCurves.easeOutMagical,
                alignment:
                    compact ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 33,
                  height: 30,
                  decoration: BoxDecoration(
                    color: t.brand,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: t.brand.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  _DensityIcon(
                    icon: Icons.view_agenda_rounded,
                    active: !compact,
                    onTap: () => onChanged(FeedDensity.comfortable),
                  ),
                  _DensityIcon(
                    icon: Icons.view_list_rounded,
                    active: compact,
                    onTap: () => onChanged(FeedDensity.compact),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DensityIcon extends StatelessWidget {
  const _DensityIcon(
      {required this.icon, required this.active, required this.onTap});
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Expanded(
      child: Tactile(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          hapticLight();
          onTap();
        },
        child: Center(
          child: Icon(icon,
              size: 16, color: active ? Colors.white : t.textMuted),
        ),
      ),
    );
  }
}

// ── Compact card ──────────────────────────────────────────────────────────────

/// The dense row: thumb, question, odds split, inline YES/NO. ~112px tall
/// against the ~430px of the full card, and it keeps the two things a scan
/// needs — the question and the price.
class CompactMarketCard extends StatefulWidget {
  const CompactMarketCard({
    required this.market,
    required this.isWatchlisted,
    required this.onWatchlist,
    required this.onDetails,
    required this.onChoose,
    this.focused = false,
    super.key,
  });

  final Market market;
  final bool isWatchlisted;
  final VoidCallback onWatchlist;
  final VoidCallback onDetails;
  final ValueChanged<MarketSide> onChoose;
  final bool focused;

  @override
  State<CompactMarketCard> createState() => _CompactMarketCardState();
}

class _CompactMarketCardState extends State<CompactMarketCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final m = widget.market;
    final yesPct = (m.yesPrice * 100).round();

    return Semantics(
      container: true,
      label: '${m.question}. Yes $yesPct percent.',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onDetails,
          child: AnimatedContainer(
            duration:
                context.motionDuration(const Duration(milliseconds: 200)),
            curve: PulsCurves.easeOutMagical,
            padding: const EdgeInsets.all(10),
            decoration: pulsCardDecoration(
              t,
              radius: 16,
              isDark: context.isDark,
              raised: _hovered || widget.focused,
              accent: widget.focused
                  ? t.brand
                  : (_hovered ? t.brand : null),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CompactThumb(market: m, t: t),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              m.question,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: t.text,
                                fontSize: 13.5,
                                height: 1.28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Tactile(
                            onTap: widget.onWatchlist,
                            child: Icon(
                              widget.isWatchlisted
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              size: 17,
                              color: widget.isWatchlisted
                                  ? t.brand
                                  : t.textSubtle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      // Odds split — same language as the big card, 4px tall.
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: SizedBox(
                          height: 4,
                          child: Row(
                            children: [
                              Expanded(
                                flex: (m.yesPrice * 1000).round().clamp(1, 1000),
                                child: ColoredBox(color: t.yes),
                              ),
                              Expanded(
                                flex: (m.noPrice * 1000).round().clamp(1, 1000),
                                child: ColoredBox(color: t.no),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniSideBtn(
                              label: 'YES',
                              price: TradeMath.formatPrice(m.yesPrice),
                              bg: t.yesBg,
                              fg: t.yes,
                              onTap: () => widget.onChoose(MarketSide.yes),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: _MiniSideBtn(
                              label: 'NO',
                              price: TradeMath.formatPrice(m.noPrice),
                              bg: t.noBg,
                              fg: t.no,
                              onTap: () => widget.onChoose(MarketSide.no),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            m.volume24hr > 0
                                ? compactUsd(m.volume24hr)
                                : m.liquidity,
                            style: TextStyle(
                              color: t.textSubtle,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFeatures: PulsColors.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactThumb extends StatelessWidget {
  const _CompactThumb({required this.market, required this.t});
  final Market market;
  final PulsThemeColors t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: market.imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: proxifyImageUrl(proxiedMarketImage(market.imageUrl)),
              fit: BoxFit.cover,
              memCacheHeight: 160,
              placeholder: (_, __) => const Skeleton(height: 76, radius: 0),
              errorWidget: (_, __, ___) => const DecoratedBox(
                decoration: BoxDecoration(gradient: PulsColors.pulseGradient),
              ),
            )
          : const DecoratedBox(
              decoration: BoxDecoration(gradient: PulsColors.pulseGradient),
            ),
    );
  }
}

class _MiniSideBtn extends StatelessWidget {
  const _MiniSideBtn({
    required this.label,
    required this.price,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final String label;
  final String price;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Bet $label at $price',
      excludeSemantics: true,
      child: Tactile(
        onTap: onTap,
        pressedScale: 0.96,
        child: Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: fg.withValues(alpha: 0.26)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      color: fg,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3)),
              const SizedBox(width: 5),
              Text(price,
                  style: TextStyle(
                      color: fg.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFeatures: PulsColors.tabularFigures)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Undo bar ──────────────────────────────────────────────────────────────────

/// A trade that has been *staged* but not yet sent.
///
/// An on-chain buy cannot be recalled once it is submitted, so "undo" here is
/// a hold, not a rollback: the order sits for [window] with a visible
/// countdown, and only fires if the user doesn't take it back. That is the
/// only honest way to offer undo on an irreversible action.
class PendingTrade {
  PendingTrade({
    required this.market,
    required this.side,
    required this.window,
  });

  final Market market;
  final MarketSide side;
  final Duration window;
}

class UndoTradeBar extends StatelessWidget {
  const UndoTradeBar({
    required this.pending,
    required this.onUndo,
    super.key,
  });

  final PendingTrade pending;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    final isYes = pending.side == MarketSide.yes;
    final sideColor = isYes ? t.yes : t.no;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: pulsCardDecoration(
              t,
              radius: 16,
              isDark: context.isDark,
              raised: true,
              accent: sideColor,
            ),
            child: Row(
              children: [
                // Countdown ring — the bar's own deadline, made visible.
                SizedBox(
                  width: 30,
                  height: 30,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1, end: 0),
                    duration: pending.window,
                    builder: (context, value, _) => Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: value,
                          strokeWidth: 2.4,
                          backgroundColor: sideColor.withValues(alpha: 0.18),
                          valueColor: AlwaysStoppedAnimation(sideColor),
                        ),
                        Icon(
                          isYes
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 14,
                          color: sideColor,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Buying ${isYes ? 'YES' : 'NO'}',
                            style: TextStyle(
                              color: sideColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            TradeMath.formatPrice(
                                isYes ? pending.market.yesPrice : pending.market.noPrice),
                            style: TextStyle(
                              color: t.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              fontFeatures: PulsColors.tabularFigures,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pending.market.question,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Tactile(
                  onTap: onUndo,
                  pressedScale: 0.95,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: t.brandSubtle,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: t.brand.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'Undo',
                      style: TextStyle(
                        color: t.brand,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state for a search that found nothing ───────────────────────────────

class FeedEndCap extends StatelessWidget {
  const FeedEndCap({
    required this.count,
    required this.filtered,
    this.onClear,
    super.key,
  });

  final int count;
  final bool filtered;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.puls;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.brandSubtle,
              shape: BoxShape.circle,
            ),
            child: Icon(
              filtered ? Icons.filter_list_rounded : Icons.check_circle_rounded,
              size: 32,
              color: t.brand,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            filtered
                ? 'Filtered $count ${count == 1 ? "market" : "markets"}'
                : "You've seen all $count markets",
            style: TextStyle(
              color: t.text,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filtered
                ? "That's everything matching your filters."
                : 'Check back soon for new predictions.',
            style: TextStyle(
              color: t.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (filtered && onClear != null) ...[
            const SizedBox(height: 16),
            Tactile(
              onTap: onClear,
              pressedScale: 0.96,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.clear_all_rounded, size: 16, color: t.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Show all markets',
                      style: TextStyle(
                        color: t.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FeedNoResults extends StatelessWidget {
  const FeedNoResults({required this.query, required this.onClear, super.key});

  final FeedQuery query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: PulsEmptyState(
          icon: Icons.search_off_rounded,
          title: query.hasText
              ? 'Nothing matches "${query.text.trim()}"'
              : 'No markets in this filter',
          message: 'Try a different word, or clear the filters to see '
              'everything again.',
          actionLabel: 'Clear filters',
          actionIcon: Icons.refresh_rounded,
          onAction: onClear,
          compact: true,
        ),
      ),
    );
  }
}
