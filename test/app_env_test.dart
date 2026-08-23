import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/core/config/app_env.dart';

/// Tests the `.env` loader integration without actually hitting the
/// network. Loads the real `.env` from the project root, verifies that
/// [AppEnv] sees the same value Dart would at build time, and runs
/// the key-shape check so a paste-error key (e.g. an Azure SAS token
/// starting with `AQ.`) is caught before a wasted API call.
void main() {
  group('AppEnv', () {
    setUpAll(() async {
      await AppEnv.load();
    });

    test('loads GEMINI_API_KEY from .env', () {
      final key = AppEnv.geminiApiKey;
      // The .env shipped to your project has either an empty value
      // (waiting for you to paste a key) or a real key. Either way
      // the loader should not throw.
      expect(key, isA<String>());

      // ignore: avoid_print
      print('AppEnv sees key length=${key.length}, '
          'startsWith=${key.isEmpty ? "(empty)" : key.substring(0, 4)}');

      if (key.isNotEmpty) {
        // If you ever paste a non-Google key, this fails fast with a
        // useful message instead of a silent Gemini 400.
        expect(
          AppEnv.hasValidGeminiKey,
          isTrue,
          reason:
              'Loaded key does not look like a Google AI Studio key. '
              'Real keys are at least 30 chars and contain no spaces. '
              'Did you paste an Azure SAS token or JWT by accident?',
        );
      }
    });

    test('--dart-define wins over .env', () {
      const fromDefine = String.fromEnvironment('GEMINI_API_KEY');
      if (fromDefine.isEmpty) {
        // skip: nothing to compare against
        return;
      }
      expect(AppEnv.geminiApiKey, fromDefine);
    });
  });
}