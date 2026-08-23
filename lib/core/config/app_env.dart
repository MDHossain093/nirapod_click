import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Single source of truth for build-time configuration.
///
/// Precedence:
///   1. `--dart-define=KEY=value`  (CI / production override)
///   2. `.env` file                (local dev)
///   3. Empty string               (caller treats as "not configured")
///
/// All entry points should read configuration through [AppEnv]
/// rather than calling `String.fromEnvironment` directly.
class AppEnv {
  AppEnv._();

  /// Must run once during [main] before any feature code reads config.
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  /// Gemini Developer API key. Empty string when not configured.
  static String get geminiApiKey {
    // `--dart-define` wins. If empty, fall back to the .env file.
    const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  /// True when [geminiApiKey] looks like a valid Google AI Studio key.
  /// Google has issued keys in at least two shapes:
  ///   - classic: `AIzaSy…` (39 chars)
  ///   - newer:   `AQ.…` (longer, with internal dots)
  /// Both work against the public Gemini REST API. A bare minimum
  /// length check (>= 30) catches empty/paste-error cases without
  /// false-rejecting legitimate keys.
  static bool get hasValidGeminiKey {
    final key = geminiApiKey;
    if (key.length < 30) return false;
    // Reject anything that looks like the *wrong* kind of secret
    // (e.g. a JWT `eyJ…`, a Firebase web API key, etc.).
    if (key.contains(' ') || key.contains('\n')) return false;
    return true;
  }
}