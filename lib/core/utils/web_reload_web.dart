// Web implementation — reloads the browser tab. Used by the production
// error fallback card so a user who hits a broken widget can recover with
// one tap instead of being stuck on a frozen screen.
import 'package:web/web.dart' as web;

void reloadApp() {
  web.window.location.reload();
}
