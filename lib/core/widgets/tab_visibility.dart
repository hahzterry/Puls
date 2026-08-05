import 'package:flutter/widgets.dart';

/// Global tab/window visibility flag so polling timers can skip work while
/// the page is hidden or unfocused instead of firing in the background.
///
/// Call [ensureListening] from any state that runs periodic polling; the
/// underlying binding observer is registered only once per app lifetime.
class TabVisibility {
  TabVisibility._();

  static bool _visible = true;
  static bool _listening = false;

  static bool get visible => _visible;

  static void ensureListening() {
    if (_listening) return;
    _listening = true;
    WidgetsBinding.instance.addObserver(_TabObserver());
  }
}

class _TabObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    TabVisibility._visible = state != AppLifecycleState.hidden &&
        state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused;
  }
}
