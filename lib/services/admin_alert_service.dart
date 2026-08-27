import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_alert.dart';

/// Loads admin-published alerts from the `admin_alerts` collection.
///
/// Mirrors the contract of [ScamRuleService]:
///   - Public read (per `firestore.rules`); no client writes.
///   - 4-second timeout so a dead network never blocks the badge.
///   - On any error (offline, permission, timeout) returns `[]` —
///     the Alerts page falls back to showing scan-derived alerts only,
///     same fail-soft philosophy as the rest of the app.
///
/// We snapshot via `.get()` on cold start and again every time
/// `refresh()` is called. There is no `live` subscription because the
/// badge increments need only fire when a brand-new alert appears,
/// and a 30-second poll while the app is foregrounded is enough for
/// the v1 admin workflow (low publish rate, internal audience).
class AdminAlertService {
  /// Hard timeout on every Firestore round-trip in this service.
  static const Duration _timeout = Duration(seconds: 4);

  /// Cap on docs we read per refresh. We ship ~0 today; 100 leaves
  /// generous headroom without risking a runaway read.
  static const int _limit = 100;

  /// Cached alerts. Null until the first refresh lands.
  List<AdminAlert>? _cached;

  /// Process-scoped singleton so [AlertService] can subscribe without
  /// a constructor-injection chain.
  static AdminAlertService? _instance;
  static AdminAlertService get instance => _instance ??= AdminAlertService();

  /// Override hook for tests.
  static set instance(AdminAlertService value) => _instance = value;

  /// Most recent snapshot. Never null — returns `[]` until [refresh]
  /// has been called at least once.
  List<AdminAlert> get lastAlerts => _cached ?? const <AdminAlert>[];

  /// Fetch the active admin_alerts bundle from Firestore. On any
  /// error path returns `[]` and caches that so the UI doesn't show
  /// a spinner forever.
  Future<List<AdminAlert>> refresh() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_alerts')
          .where('active', isEqualTo: true)
          .limit(_limit)
          .get()
          .timeout(_timeout);

      final parsed = snapshot.docs
          .map(AdminAlert.fromFirestore)
          // Drop malformed rows rather than crashing the feed. We keep
          // a doc even if titleEn is empty so Bangla-only alerts (which
          // the user just typed `titleBn`) still surface.
          .where((a) => a.hasValidSeverity &&
              (a.titleEn.isNotEmpty || a.titleBn.isNotEmpty))
          .toList(growable: false)
          // Client-side sort newest first. We no longer orderBy server-side
          // because the `active == true AND orderBy updatedAt desc` combo
          // requires a composite index; sorting here keeps the same UX
          // without the index dependency.
        ..sort((a, b) => b.id.compareTo(a.id));

      _cached = parsed;
      return parsed;
    } catch (e) {
      debugPrint('[AdminAlertService] Firestore unavailable: $e');
      // Cache an empty list so [lastAlerts] doesn't return stale
      // admin alerts after the user has disabled them.
      _cached = const <AdminAlert>[];
      return _cached!;
    }
  }
}