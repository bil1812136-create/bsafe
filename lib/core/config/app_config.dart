/// Application-level configuration constants.
/// Sensitive keys should be injected via --dart-define at build time.
class AppConfig {
  AppConfig._();

  // ── Supabase ────────────────────────────────────────────────
  static const String supabaseUrl = 'https://mvywylhlmktejvsmcqkk.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im12eXd5bGhsbWt0ZWp2c21jcWtrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxMTk1NzYsImV4cCI6MjA5MDY5NTU3Nn0'
      '.qv1mqv8FW83Z_btolYWYEN5fGTXMW8-V08ZphvO3Dv8';

  static bool get isSupabaseConfigured =>
      supabaseUrl != 'https://YOUR_PROJECT_ID.supabase.co' &&
      supabaseAnonKey != 'YOUR_ANON_KEY';

  // ── Gemini AI ───────────────────────────────────────────────
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String geminiModel = 'gemini-2.5-flash';
  static const String geminiApiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ── Supabase Storage Buckets ────────────────────────────────
  static const String reportImagesBucket = 'report-images';
  static const String floorPlansBucket = 'floor-plans';

  // ── Realtime Polling ────────────────────────────────────────
  static const Duration realtimePollInterval = Duration(seconds: 5);
  static const Duration dashboardRefreshInterval = Duration(seconds: 15);
}
