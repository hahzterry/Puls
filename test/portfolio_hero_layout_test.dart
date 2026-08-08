import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/features/portfolio/liquid_wealth_terrain.dart';

/// Regression guard for the portfolio hero going blank below the fold.
///
/// `LiquidWealthTerrain` used to build a `LayoutBuilder` at its root. Any parent
/// that asks for an intrinsic dimension (`IntrinsicHeight`, an unbounded flex)
/// then threw mid-layout, and because the throw aborts `performLayout` the
/// render object never got a size — cascading "RenderBox was not laid out" all
/// the way up. On the desktop portfolio that wiped the tab bar, the claim
/// banner and the entire position list off the page while the hero's own
/// numbers still painted, so it read as "my trades don't load".
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: PulsTheme.dark(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  testWidgets('terrain lays out under an IntrinsicHeight parent',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      host(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(flex: 4, child: Text('money')),
              SizedBox(width: 24),
              Expanded(
                flex: 6,
                child: LiquidWealthTerrain(pnlUsdc: -16.18, height: 300),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(LiquidWealthTerrain)).height, 300);
  });

  testWidgets('siblings after the terrain still render', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      host(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            LiquidWealthTerrain(pnlUsdc: 12.5, height: 240),
            SizedBox(height: 20),
            Text('positions-below'),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('positions-below'), findsOneWidget);
  });

  // The second, and the one that actually shipped to production.
  //
  // The hero's stat boxes drew their accent rail as
  // `Row(crossAxisAlignment: stretch)` + a fixed-width `Container`. `RenderFlex`
  // implements stretch as `BoxConstraints.tightFor(height: constraints.maxHeight)`,
  // and every child of a `SliverToBoxAdapter` is laid out with maxHeight
  // infinity — so the rail came back `Size(3, Infinity)`, which propagated up
  // through the stat row, the hero card and the sliver's whole scroll extent.
  // The tab toggle, the claim banner and every position card were then parked
  // at scroll offset infinity: unreachable, unpainted, and (in release, where
  // asserts are stripped) completely silent.
  //
  // These two tests pin the rule the stat box now follows: an accent rail
  // inside an unbounded sliver has to take its height from a sibling, not from
  // the incoming constraints.
  Widget railCard({required Widget rail}) => MaterialApp(
        theme: PulsTheme.dark(),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(children: [rail, const Text('below-the-hero')]),
              ),
            ],
          ),
        ),
      );

  testWidgets('stretch rail inside a sliver blows the height up to infinity',
      (tester) async {
    await tester.pumpWidget(railCard(
      rail: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          SizedBox(width: 3, child: ColoredBox(color: Color(0xFF14B8A6))),
          Expanded(child: Text('42%')),
        ],
      ),
    ));

    expect(tester.takeException(), isNotNull,
        reason: 'stretch under an unbounded sliver must not be considered safe');
  });

  testWidgets('Positioned rail keeps the sliver finite and the page scrollable',
      (tester) async {
    await tester.pumpWidget(railCard(
      rail: Stack(
        children: const [
          Padding(padding: EdgeInsets.fromLTRB(14, 10, 10, 10), child: Text('42%')),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3,
            child: ColoredBox(color: Color(0xFF14B8A6)),
          ),
        ],
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('below-the-hero'), findsOneWidget);
  });
}
