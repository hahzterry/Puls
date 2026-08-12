import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puls/app/puls_app_state.dart';
import 'package:puls/core/theme/app_theme.dart';
import 'package:puls/core/widgets/puls_loader.dart';
import 'package:puls/data/mock/mock_market_repository.dart';

Widget _host(Widget child, {bool reduceMotion = false}) {
  final appState = PulsAppState(mockRepo: MockMarketRepository());
  appState.reduceMotionOverride = reduceMotion;
  return PulsStateScope(
    notifier: appState,
    child: MaterialApp(
      theme: PulsTheme.dark(),
      home: Scaffold(
        body: Center(
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('spins (CircularProgressIndicator) under normal motion',
      (tester) async {
    await tester.pumpWidget(_host(const PulsLoader()));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('no spinner under reduce-motion and settles', (tester) async {
    await tester.pumpWidget(
        _host(const PulsLoader(label: 'Loading…'), reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Loading…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
