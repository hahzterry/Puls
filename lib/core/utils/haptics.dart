// Haptic wrappers: haptic_kit has no web implementation, so every call on web
// throws "Plugin not registered on this platform" as an uncaught exception.
// Guard with kIsWeb so the web build never touches the missing plugin.
import 'package:flutter/foundation.dart';
import 'package:haptic_kit/haptic_kit.dart';

void hapticLight() {
  if (kIsWeb) return;
  Haptics.impact(HapticImpactStyle.light);
}

void hapticMedium() {
  if (kIsWeb) return;
  Haptics.impact(HapticImpactStyle.medium);
}

void hapticHeavy() {
  if (kIsWeb) return;
  Haptics.impact(HapticImpactStyle.heavy);
}

void hapticSuccess() {
  if (kIsWeb) return;
  Haptics.notification(HapticNotificationStyle.success);
}

void hapticError() {
  if (kIsWeb) return;
  Haptics.notification(HapticNotificationStyle.error);
}
