import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/default_url_scam_rules.dart';
import '../models/url_scam_rule.dart';

/// Loads the active URL-rule bundle from Firestore with bundled
/// fallback.
///
/// Contract:
///   - Returns Firestore rules if the collection has any docs.
///   - If Firestore is empty, returns [defaultUrlScamRules] WITHOUT
///     auto-seeding (see note below).
///   - On any error (offline, permission, timeout), returns
///     [defaultUrlScamRules] silently — same detection as today, no
///     user-visible failure.
///
/// `loadRules` is wrapped in a 4-second timeout to avoid blocking
/// `main()` forever when the network is dead. Tests can swap the
/// singleton via [instance] to inject a fake.
///
/// Admin-only writes: this service never writes to Firestore from the
/// client. Unlike [ScamRuleService], it does **not** auto-seed on an
/// empty collection — `firestore.rules` denies all client writes to
/// `url_scam_rules` (and to `scam_patterns`), so the seed call would
/// silently fail. Admin edits go through the Firebase Console.
class UrlScamRuleService {
  /// Hard timeout on every Firestore round-trip in this service.
  /// Keeps `main()` from hanging on a dead network — the bundled
  /// fallback kicks in after this many seconds at most.
  static const Duration _timeout = Duration(seconds: 4);

  /// Cached rules. Null until [loadRules] has run at least once.
  /// [rules] returns the bundled defaults until then so callers never
  /// have to null-check.
  List<UrlScamRule>? _cached;

  /// Returns the active rules. Never null — falls back to
  /// [defaultUrlScamRules] if [loadRules] hasn't been called yet.
  List<UrlScamRule> get rules => _cached ?? defaultUrlScamRules;

  /// Fetch the rule bundle from Firestore, with offline-first
  /// fallback. Safe to call multiple times — the second call returns
  /// the cached list.
  ///
  /// Empty-collection path is intentionally seed-less: returning the
  /// bundled defaults is the correct behaviour because the admin
  /// panel edits `url_scam_rules` via the Firebase Console, not the
  /// client. A failed seed write would just emit a misleading
  /// permission error in logs.
  Future<List<UrlScamRule>> loadRules() async {
    if (_cached != null) return _cached!;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('url_scam_rules')
          .limit(200) // hard cap — we ship ~70 today, leave headroom
          .get()
          .timeout(_timeout);

      if (snapshot.docs.isEmpty) {
        // Empty collection — admin hasn't populated Firestore yet (or
        // the project is brand-new). Detection still works because
        // we ship [defaultUrlScamRules] in the APK.
        debugPrint('[UrlScamRuleService] Collection empty, '
            'using bundled defaults (${defaultUrlScamRules.length} rules).');
        _cached = defaultUrlScamRules;
        return _cached!;
      }

      _cached = snapshot.docs
          .where((d) => (d.data()['active'] as bool? ?? true))
          .map(UrlScamRule.fromFirestore)
          .toList(growable: false);
      return _cached!;
    } catch (e) {
      // Offline, permission denied, timeout, malformed doc — every
      // failure mode falls back to the bundled defaults silently.
      // Surfacing the error to the UI would add no value: the
      // detection math is identical either way.
      debugPrint('[UrlScamRuleService] Firestore unavailable, '
          'using bundled defaults: $e');
      _cached = defaultUrlScamRules;
      return _cached!;
    }
  }

  // ─────────────── Singleton ───────────────
  //
  // The service is held as a process-wide singleton so analyzers
  // (which are constructed eagerly inside the checker screens) can
  // reach the loaded rule bundle without a constructor-injection
  // chain through every widget. Tests override [instance] in setUp.

  static UrlScamRuleService? _instance;

  /// Default-constructing accessor. Safe to read before [loadRules]
  /// has been called — [rules] will return the bundled defaults.
  static UrlScamRuleService get instance =>
      _instance ??= UrlScamRuleService();

  /// Override hook (primarily for tests; see [setUp] in
  /// `test/widgets/...` if added later).
  static set instance(UrlScamRuleService value) => _instance = value;
}
