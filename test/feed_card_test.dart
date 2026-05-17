import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/data/mock/mock_market_repository.dart';
import 'package:puls/data/models/market.dart';
import 'package:puls/features/feed/prediction_feed_card.dart';

void main() {
  testWidgets('renders prediction card and emits Yes action', (tester) async {
    final market = MockMarketRepository().markets.first;
    MarketSide? selectedSide;

    await tester.pumpWidget(
      MaterialApp(
        theme: PulsTheme.dark(),
        home: Scaffold(
          body: PredictionFeedCard(
            market: market,
            isWatchlisted: false,
            onWatchlist: () {},
            onDetails: () {},
            onChoose: (side) => selectedSide = side,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(market.question), findsOneWidget);
    expect(find.text('YES'), findsOneWidget);
    expect(find.text('NO'), findsOneWidget);

    await tester.tap(find.text('YES'));
    expect(selectedSide, MarketSide.yes);
  });
}
