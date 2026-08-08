// lib/config/app_config.dart
// Compile-time flag that decides which product this build is: the
// Academia platform (open to independent students everywhere) or a
// specific school's white-labeled app (Green Hill, or any future
// client) built off the same codebase. Set at build time via
// --dart-define=APP_MODE=school -- never changes at runtime, so nav
// gating based on this is a real compile-time boundary, not a toggle a
// user could flip.
//
// Paired with Branding (branding.dart), which is selected via a
// separate --dart-define=BRAND_ID=<id> and controls the *look*
// (name/colors/logo). AppConfig.mode controls *behavior* (which nav
// exists at all) -- kept as two separate flags rather than one because
// they're genuinely different axes: a future third client could want
// 'school' mode with its own brand, without adding a third mode value.
class AppConfig {
  AppConfig._();

  static const String mode =
      String.fromEnvironment('APP_MODE', defaultValue: 'platform');

  static bool get isSchoolMode => mode == 'school';
  static bool get isPlatformMode => mode == 'platform';
}
