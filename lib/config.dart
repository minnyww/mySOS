/// App-wide configuration constants.
///
/// LINE_OA_URL: the "add friend" URL of your LINE Official Account, e.g.
///   https://line.me/R/ti/p/@your-oa-id
/// Find it in LINE Developers console > Messaging API > Official Account
/// settings (or LINE OA Manager > โปรไฟล์). Leave empty to hide the button.
class AppConfig {
  AppConfig._();

  static const String appName = 'MySOS';

  /// Deep-link scheme used by the home-screen widgets: mysos://fire, mysos://pair/<code>
  static const String deepLinkScheme = 'mysos';

  /// LINE Official Account add-friend URL (see file docs above).
  static const String lineOaUrl = '';

  /// Pairing code lifetime.
  static const Duration pairCodeTtl = Duration(minutes: 10);

  /// Countdown before an in-app SOS fires (gives a chance to cancel).
  static const Duration sosCountdown = Duration(seconds: 3);

  /// Cooldown enforced server-side between two SOS alerts.
  static const Duration sosCooldown = Duration(seconds: 60);
}
