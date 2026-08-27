import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/default_scam_rules.dart';
import '../models/scam_rule.dart';

/// Loads the active scam-rule bundle from Firestore with bundled
/// fallback.
///
/// Contract:
///   - Returns Firestore rules if the collection has any docs.
///   - If Firestore is empty, seeds [defaultScamRules] and returns them.
///   - On any error (offline, permission, timeout), returns
///     [defaultScamRules] silently — same detection as today, no
///     user-visible failure.
///
/// `loadRules` is wrapped in a 4-second timeout to avoid blocking
/// `main()` forever when the network is dead. Tests can swap the
/// singleton via [instance] to inject a fake.
///
/// Admin-only writes: this service never writes to Firestore from the
/// client except for the one-time auto-seed, which uses
/// `SetOptions(merge: true)` so it can never overwrite an admin edit.
class ScamRuleService {
  /// Hard timeout on every Firestore round-trip in this service.
  /// Keeps `main()` from hanging on a dead network — the bundled
  /// fallback kicks in after this many seconds at most.
  static const Duration _timeout = Duration(seconds: 4);

  /// Cached rules. Null until [loadRules] has run at least once.
  /// [rules] returns the bundled defaults until then so callers never
  /// have to null-check.
  List<ScamRule>? _cached;

  /// Returns the active rules. Never null — falls back to
  /// [defaultScamRules] if [loadRules] hasn't been called yet.
  List<ScamRule> get rules => _cached ?? defaultScamRules;

  /// Fetch the rule bundle from Firestore, with offline-first
  /// fallback. Safe to call multiple times — the second call returns
  /// the cached list.
  Future<List<ScamRule>> loadRules() async {
    if (_cached != null) return _cached!;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('scam_patterns')
          .limit(200) // hard cap — we ship 6 today, leave headroom
          .get()
          .timeout(_timeout);

      if (snapshot.docs.isEmpty) {
        // First launch with an empty database. Seed the bundled rules
        // so the admin panel has something to edit on next visit.
        await _seedDefaults();
        _cached = defaultScamRules;
        return _cached!;
      }

      _cached = snapshot.docs
          .where((d) => (d.data()['active'] as bool? ?? true))
          .map(ScamRule.fromFirestore)
          .toList(growable: false);
      return _cached!;
    } catch (e) {
      // Offline, permission denied, timeout, malformed doc — every
      // failure mode falls back to the bundled defaults silently.
      // Surfacing the error to the UI would add no value: the
      // detection math is identical either way.
      debugPrint('[ScamRuleService] Firestore unavailable, '
          'using bundled defaults: $e');
      _cached = defaultScamRules;
      return _cached!;
    }
  }

  /// Batched write of [defaultScamRules] into `scam_patterns/{id}` and
  /// bumps `scam_config/current.version`. Uses `SetOptions(merge: true)`
  /// so re-running the seed is idempotent and never stomps an admin
  /// edit on the same doc id.
  Future<void> _seedDefaults() async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    for (final rule in defaultScamRules) {
      batch.set(
        firestore.collection('scam_patterns').doc(rule.id),
        rule.toFirestore(),
        SetOptions(merge: true),
      );
    }

    await batch.commit().timeout(_timeout);

    // Bump the global version + activePatternCount so the admin panel
    // sees a fresh timestamp on the seed event.
    await firestore.collection('scam_config').doc('current').set(
      {
        'version': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
        'activePatternCount': defaultScamRules.length,
      },
      SetOptions(merge: true),
    );
  }

  // ─────────────── Singleton ───────────────
  //
  // The service is held as a process-wide singleton so analyzers
  // (which are constructed eagerly inside the checker screens) can
  // reach the loaded rule bundle without a constructor-injection
  // chain through every widget. Tests override [instance] in setUp.

  static ScamRuleService? _instance;

  /// Default-constructing accessor. Safe to read before [loadRules]
  /// has been called — [rules] will return the bundled defaults.
  static ScamRuleService get instance =>
      _instance ??= ScamRuleService();

  /// Override hook (primarily for tests; see [setUp] in
  /// `test/widgets/...` if added later).
  static set instance(ScamRuleService value) => _instance = value;
}
