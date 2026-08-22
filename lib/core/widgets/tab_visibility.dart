import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Global tab/window visibility flag so polling timers can skip work while
/// the page is hidden or unfocused instead of firing in the background.
///
/// Call [ensureListening] from any state that runs periodic polling; the
/// underlying binding observer is registered only once per app lifetime.
///
/// Also exposes [listenable] (a `ValueListenable<bool>`) so animation
/// infrastructure (see `pulse_governor.dart`) can pause all tickers the moment
/// the tab loses visibility and resume on return.
class TabVisibility {
  TabVisibility._();

  static final ValueNotifier<bool> _notifier = ValueNotifier<bool>(true);
  static bool _listening = false;

  /// Whether the browser tab / window is currently visible.
  static bool get visible => _notifier.value;

  /// Change-notifying view of [visible]. Emits only on actual flips.
  static ValueListenable<bool> get listenable => _notifier;

  static void ensureListening() {
    if (_listening) return;
    _listening = true;
    WidgetsBinding.instance.addObserver(_TabObserver());
  }
}

class _TabObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    TabVisibility._notifier.value = state != AppLifecycleState.hidden &&
        state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused;
  }
}
