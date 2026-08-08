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
}
