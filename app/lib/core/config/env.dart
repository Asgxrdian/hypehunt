/// Client-safe configuration only. (Technical Bible Rule 1.3:
/// the app binary may hold publishable values and nothing else.)
///
/// Provided at build time:
///   flutter run --dart-define-from-file=../.env
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
