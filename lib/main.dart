import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/app_env.dart';
import 'core/locale/app_locale.dart';
import 'core/locale/localizer.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_gate.dart';
import 'services/alert_service.dart';
import 'services/free_quota_service.dart';
import 'services/notifications_prefs_service.dart';
import 'services/scam_rule_service.dart';
import 'services/share_intent_service.dart';
import 'services/subscription_service.dart';
import 'services/url_scam_rule_service.dart';

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

  // Load the scam-rule bundle BEFORE first frame so the very first
  // scan uses the latest Firestore rules if the network is reachable.
  // [ScamRuleService.loadRules] never throws — it falls back to the
  // bundled defaults on any error (offline, permission, timeout) so
  // app launch is never blocked by Firestore.
  final rules = await ScamRuleService().loadRules();
  // ignore: avoid_print
  print('[ScamRuleService] Loaded ${rules.length} patterns.');

  // Same posture for the URL checker: Firestore-first with a bundled
  // fallback. Both loads run in parallel-safe sequence here because
  // they share no state and each has its own 4s timeout.
  final urlRules = await UrlScamRuleService().loadRules();
  // ignore: avoid_print
  print('[UrlScamRuleService] Loaded ${urlRules.length} patterns.');

  // Open the alert pipeline so the home-bell badge has data ready
  // when Home loads — without this, the bell would subscribe lazily
  // on Home build, briefly showing `0` and then flickering to the
  // real count. `ensureStarted` is idempotent and the singleton
  // shares one Firestore subscription across the bell + alerts page.
  await AlertService.instance.ensureStarted();

  // Load the Profile → Settings → Notifications toggle's persisted state
  // before the first frame so the SwitchListTile renders the user's
  // stored choice synchronously (no flicker from default-true to whatever
  // was persisted).
  await NotificationsPrefsService.instance.load();

  // Rehydrate the per-kind quota counters ("X message scans left" /
  // "Y screenshot scans left") from SharedPreferences so the Profile
  // card renders the correct values on first frame instead of
  // flashing the static defaults. We do this BEFORE the first frame
  // for the same reason as the other `load()` calls above — without
  // it the user would see "5 of 5 left" on app launch even after
  // running 3 scans in a previous session.
  await SubscriptionService.instance.rehydrate();

  // Restore the last user-selected language before the first frame so
  // every screen renders in the right locale on cold start.
  final prefs = await SharedPreferences.getInstance();
  final savedIndex = prefs.getInt(_kLocalePrefKey);
  final initialLocale = (savedIndex != null &&
          savedIndex >= 0 &&
          savedIndex < AppLocale.values.length)
      ? AppLocale.values[savedIndex]
      : AppLocale.english;

  // Seed the context-free Localizer singleton up front so the very
  // first engine call (e.g. Gemini prompt construction during the
  // AI startup path, or any eager analyzers) renders in the right
  // locale instead of falling back to English. AppLocaleScope will
  // call setLocale again on the first frame via updateShouldNotify,
  // so this is just an early bootstrap, not a divergence.
  Localizer.instance.setLocale(initialLocale);

  // Arm the Android share-intent handler. This subscribes to the
  // warm-start event channel and, synchronously-enough, reads any
  // cold-start share that launched the app via ACTION_SEND.
  // Awaiting it before `runApp` means a cold-start share is already
  // in the queue by the time MainScreen's first build runs — the
  // router sees it immediately rather than on the next frame.
  await ShareIntentService.instance.start();

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
    // FreeQuotaService is constructed once per app lifetime so its
    // quota counter survives the root widget rebuilding (e.g. locale
    // change rebuilds the tree). We attach it to the SubscriptionService
    // singleton below via [_ensureQuotaAttached] so the pill flips to
    // "Unlimited checks · Premium" instantly for premium users instead
    // of briefly rendering "X of 5 free" on cold start.
    final quotaService = _ensureQuotaAttached();

    return AppLocaleScope(
      locale: _locale,
      onChanged: _setLocale,
      child: SubscriptionScope(
        // FreeQuotaScope must be a descendant of SubscriptionScope
        // so the quota service can listen for premium-state
        // transitions. We grab the same SubscriptionService singleton
        // here that FreeQuotaScope's descendants will see.
        child: Builder(
          builder: (context) {
            // Make sure the quota service has the (now-built)
            // subscription service in hand before any descendant
            // tries to consume a check.
            quotaService.attachSubscription(SubscriptionScope.of(context));
            return FreeQuotaScope(
              service: quotaService,
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
            );
          },
        ),
      ),
    );
  }

  // Module-level singleton for the quota service. Mirrors
  // `SubscriptionScope._default` — keeps a single instance across
  // rebuilds so quota counts aren't reset every time the root widget
  // rebuilds (which happens on locale change).
  static final FreeQuotaService _quotaSingleton = FreeQuotaService();

  FreeQuotaService _ensureQuotaAttached() => _quotaSingleton;
}