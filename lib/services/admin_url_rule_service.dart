import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/url_scam_rule.dart';

/// Admin-side read of the `url_scam_rules` collection.
///
/// Used **only** by the admin preview screen, never by the URL
/// checker at scan time. The checker consumes [UrlScamRuleService],
/// which caches the rule list once at startup; this service is a
/// pull-on-demand view so the admin can see what the live Firestore
/// bundle looks like right now (without restarting the app).
///
/// Contract:
///   - Public read (per `firestore.rules`); no client writes.
///   - 4-second timeout so a dead network never blocks the screen.
///   - On any error returns `[]` — the screen shows "no rules yet"
///     rather than spinning forever.
///   - Returns **all** docs (active + inactive) so the admin can see
///     what's been disabled without re-enabling it first.
class AdminUrlRuleService {
  /// Hard timeout on every Firestore round-trip in this service.
  static const Duration _timeout = Duration(seconds: 4);

  /// Cap on docs we read per refresh. We ship ~70 today; 100 leaves
  /// headroom without risking a runaway read.
  static const int _limit = 100;

  /// Cached rules. Null until the first refresh lands.
  List<UrlScamRule>? _cached;

  /// Process-scoped singleton so the admin screen can subscribe
  /// without a constructor-injection chain.
  static AdminUrlRuleService? _instance;
  static AdminUrlRuleService get instance =>
      _instance ??= AdminUrlRuleService();

  /// Override hook for tests.
  static set instance(AdminUrlRuleService value) => _instance = value;

  /// Most recent snapshot. Never null — returns `[]` until [refresh]
  /// has been called at least once.
  List<UrlScamRule> get lastRules => _cached ?? const <UrlScamRule>[];

  /// Fetch the current `url_scam_rules` bundle from Firestore. On any
  /// error path returns `[]` and caches that so the UI doesn't show
  /// a spinner forever.
  Future<List<UrlScamRule>> refresh() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('url_scam_rules')
          .limit(_limit)
          .get()
          .timeout(_timeout);

      final parsed = snapshot.docs
          .map(UrlScamRule.fromFirestore)
          .toList(growable: false)
          // Client-side sort by id. We no longer orderBy server-side
          // because the collection is small enough that a Firebase
          // Console diff is more useful when rows stay in id order
          // (admin edits a rule, the next refresh shows it in the
          // same position).
        ..sort((a, b) => a.id.compareTo(b.id));

      _cached = parsed;
      return parsed;
    } catch (e) {
      debugPrint('[AdminUrlRuleService] Firestore unavailable: $e');
      _cached = const <UrlScamRule>[];
      return _cached!;
    }
  }
}