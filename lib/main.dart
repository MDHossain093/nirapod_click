import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_env.dart';
import 'core/locale/app_locale.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'services/subscription_service.dart';

/// SharedPreferences key under which the last selected [AppLocale] is
/// persisted. Reading the key returns the enum index as a string.
const String _kLocalePrefKey = 'app.locale';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env BEFORE Firebase / feature code so any service that reads
  // AppEnv.geminiApiKey (e.g. AiService) sees the loaded value.
  await AppEnv.load();

  // Startup diagnostic: warn loudly if the configured key is the wrong
  // shape. A bad key (e.g. an Azure SAS token pasted by mistake) would
  // otherwise produce a silent fallback later in the AI path.
  final key = AppEnv.geminiApiKey;
  if (key.isEmpty) {
    // ignore: avoid_print
    print('[AppEnv] GEMINI_API_KEY not set. '
        'Add it to .env or pass --dart-define=GEMINI_API_KEY=...');
  } else if (!AppEnv.hasValidGeminiKey) {
    // ignore: avoid_print
    print('[AppEnv] WARNING: GEMINI_API_KEY looks invalid '
        '(prefix=${key.length < 4 ? "?" : key.substring(0, 4)}). '
        'Real keys are non-empty, at least 30 chars, and contain no spaces.');
  } else {
    // ignore: avoid_print
    print('[AppEnv] GEMINI_API_KEY loaded (length=${key.length}).');
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Restore the last user-selected language before the first frame so
  // every screen renders in the right locale on cold start.
  final prefs = await SharedPreferences.getInstance();
  final savedIndex = prefs.getInt(_kLocalePrefKey);
  final initialLocale = (savedIndex != null &&
          savedIndex >= 0 &&
          savedIndex < AppLocale.values.length)
      ? AppLocale.values[savedIndex]
      : AppLocale.english;

  runApp(NirapodClickApp(initialLocale: initialLocale));
}

class NirapodClickApp extends StatefulWidget {
  const NirapodClickApp({super.key, this.initialLocale = AppLocale.english});

  final AppLocale initialLocale;

  @override
  State<NirapodClickApp> createState() => _NirapodClickAppState();
}

class _NirapodClickAppState extends State<NirapodClickApp> {
  late AppLocale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
  }

  Future<void> _setLocale(AppLocale next) async {
    if (next == _locale) return;
    setState(() => _locale = next);
    // Fire-and-forget persist. A failed write shouldn't block the UI
    // toggle; the next launch will simply fall back to the previous
    // stored value (or English if nothing was ever saved).
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLocalePrefKey, next.index);
    } catch (_) {
      // ignored — best effort persistence.
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLocaleScope(
      locale: _locale,
      onChanged: _setLocale,
      child: SubscriptionScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'NirapodClick',
          theme: AppTheme.lightTheme,
          // AuthGate listens to Firebase's auth state:
          //   - while the cached session rehydrates, shows a branded splash
          //   - resolves to HomePage when signed in (persistent login)
          //   - resolves to LoginPage when signed out
          home: const AuthGate(),
        ),
      ),
    );
  }
}