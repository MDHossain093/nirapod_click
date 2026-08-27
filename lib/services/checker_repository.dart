import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/risk_result.dart';
import '../models/scan_type.dart';
import 'subscription_service.dart';

/// Re-export so existing callers (which historically imported
/// `ScanType` from this file) keep compiling without a sweeping
/// import-path edit. New code should import from
/// `package:nirapod_click/models/scan_type.dart` directly.
export '../models/scan_type.dart' show ScanType;

/// Limits that match `firestore.rules`. Kept in one place so the client
/// and the server agree on what's valid.
class CheckLimits {
  static const int maxOriginalText = 5000;
  static const int maxReasons = 25;
  static const int maxReasonLength = 200;
  static const int maxCategoryLength = 64;
}

/// Pure helpers — kept top-level so they're unit-testable without Firebase.
Map<String, dynamic> serializeCheck(
  RiskResult result,
  String originalText, {
  ScanType type = ScanType.message,
}) {
  final clampedText = originalText.length > CheckLimits.maxOriginalText
      ? originalText.substring(0, CheckLimits.maxOriginalText)
      : originalText;

  final reasons = <String>[];
  for (final r in result.reasons.take(CheckLimits.maxReasons)) {
    final cut = r.length > CheckLimits.maxReasonLength
        ? r.substring(0, CheckLimits.maxReasonLength)
        : r;
    reasons.add(cut);
  }

  final category = result.category.length > CheckLimits.maxCategoryLength
      ? result.category.substring(0, CheckLimits.maxCategoryLength)
      : result.category;

  return {
    'originalText': clampedText,
    'score': result.score.clamp(0, 100),
    'level': result.level.name,
    'category': category,
    'confidence': result.confidence.clamp(0.0, 1.0),
    'reasons': reasons,
    // Scan-type metadata. Older message-only docs without this field still
    // deserialize cleanly (the history UI treats missing/null as 'message').
    'type': type.wire,
    // Surfaces "AI analysis unavailable" in the history detail UI when the
    // original verdict came from the local fallback path. Older docs without
    // this field deserialize cleanly (treated as `false`).
    'aiWasUnavailable': result.aiWasUnavailable,
    // The server replaces this with serverTimestamp() on write; for
    // round-tripping via [deserializeCheck] outside of Firestore we use a
    // sentinel that means "now".
    'createdAt': _Sentinel.createdAtNow,
  };
}

RiskResult deserializeCheck(Map<String, dynamic> data) {
  final reasons = (data['reasons'] as List? ?? [])
      .map((e) => e.toString())
      .toList();

  return RiskResult(
    score: (data['score'] as num).toInt(),
    level: RiskLevel.values.firstWhere(
      (l) => l.name == data['level'],
      orElse: () => RiskLevel.low,
    ),
    category: data['category'] as String? ?? 'General',
    confidence: (data['confidence'] as num? ?? 0.5).toDouble(),
    reasons: reasons,
    recommendations: const [],
    usedAi: false,
    // Older docs (and unit tests that bypass Firestore) won't have this
    // field set; default to `false` so they render as normal verdicts.
    aiWasUnavailable: (data['aiWasUnavailable'] as bool?) ?? false,
  );
}

/// Sentinel so we don't write a real Timestamp from pure-Dart code paths
/// (tests, etc.). The repository replaces it with FieldValue.serverTimestamp
/// at write time.
class _Sentinel {
  static const Object createdAtNow = Object();
}

/// Parses the optional `type` field back to [ScanType]. Returns [ScanType.message]
/// for unknown / missing values so legacy docs from before this field was
/// added keep rendering.
ScanType parseScanType(Object? raw) {
  if (raw is String) {
    for (final t in ScanType.values) {
      if (t.wire == raw) return t;
    }
  }
  return ScanType.message;
}

/// Saves user scans to Firestore and lists them back as [HistoryEntry]s.
///
/// Schema (per scan):
///   users/{uid}/checks/{autoId}
///     - originalText: string (<= 5000)
///     - score: int (0..100)
///     - level: "safe" | "low" | "medium" | "high" | "critical"
///     - category: string (<= 64)
///     - confidence: double (0..1)
///     - reasons: [string, ...] (<= 25, each <= 200)
///     - type: "message" | "url" | "screenshot" | "phone" (optional, default 'message')
///     - createdAt: serverTimestamp
class CheckerRepository {
  final FirebaseFirestore _db;
  final String? _uid;

  CheckerRepository({FirebaseFirestore? db, String? uid})
      : _db = db ?? FirebaseFirestore.instance,
        // Resolved lazily so the repository is safe to construct BEFORE a
        // user has signed in (e.g. from `main()` while AuthGate is still
        // deciding between the cached-session splash and LoginPage).
        // Any call that actually needs the uid — save / watch / clear —
        // re-reads `currentUser` at invocation time, which throws the
        // same helpful "no user" StateError as the old `!` would, but
        // only for the operation that needs a user rather than blocking
        // the entire app launch.
        _uid = uid ?? FirebaseAuth.instance.currentUser?.uid {
    // Defensive: log the uid the repository will query under so we can
    // diagnose "permission-denied" on Firestore reads — the most common
    // cause is a stale ID token from a previous sign-in. The watcher
    // below forces a token refresh on auth state changes, which cures
    // the failure mode where the Flutter SDK kept a pre-revocation
    // cached token (reads fail with `permission-denied` until the
    // token is refreshed, which the SDK normally does lazily).
    debugPrint('[CheckerRepository] uid=$_uid');
  }

  /// Resolves the uid on demand — falls back to the constructor-time
  /// snapshot, but re-reads `currentUser` if that was null at construction.
  /// Throws if no user is signed in at call time (the only way to make a
  /// Firestore call under `users/{uid}/...` is to have a uid).
  String get _resolvedUid {
    final live = FirebaseAuth.instance.currentUser?.uid;
    final uid = live ?? _uid;
    if (uid == null) {
      throw StateError(
        'CheckerRepository requires a signed-in user. '
        'Construct it after FirebaseAuth.instance.currentUser is non-null '
        '(e.g. inside an auth-state listener) or pass `uid` explicitly.',
      );
    }
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _checks =>
      _db.collection('users').doc(_resolvedUid).collection('checks');

  /// Save a scan from the message / SMS checker (the only caller that used
  /// to write). Kept as a thin alias for [saveScan] so older call sites keep
  /// compiling.
  Future<void> save(RiskResult result, String originalText) {
    return saveScan(result: result, originalText: originalText);
  }

  /// Save any scan. [type] defaults to [ScanType.message].
  Future<void> saveScan({
    required RiskResult result,
    required String originalText,
    ScanType type = ScanType.message,
  }) async {
    final payload = serializeCheck(result, originalText, type: type);
    payload['createdAt'] = FieldValue.serverTimestamp();
    await _checks.add(payload);
  }

  /// Newest-first stream of this user's checks, capped at [limit].
  Stream<List<HistoryEntry>> watchRecent({int limit = 50}) {
    return _checks
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  /// Delete every check this user has ever saved. Used by the
  /// "Clear history" action on the history page. Batched in chunks of 450
  /// because of Firestore's 500-op per-batch ceiling.
  ///
  /// Also refunds the per-kind quota counter on the SubscriptionService
  /// for every deleted doc so the Profile card's "X scans left" matches
  /// the freshly-cleared history. We look up each doc's `type` field
  /// before deleting so the refund targets the right counter; docs
  /// without a `type` field (very old entries) fall back to `message`
  /// — matching `parseScanType`'s default, so we're at least
  /// internally consistent.
  Future<int> clearAll() async {
    final snap = await _checks.get();
    if (snap.docs.isEmpty) return 0;

    // Capture the type before delete (Firestore hands us an immutable
    // snapshot, so we can read `data` even after the doc is gone).
    final typeById = <String, ScanType>{};
    for (final doc in snap.docs) {
      typeById[doc.id] = parseScanType(doc.data()['type']);
    }

    const chunkSize = 450;
    var deleted = 0;
    for (var i = 0; i < snap.docs.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, snap.docs.length);
      final batch = _db.batch();
      for (final doc in snap.docs.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += end - i;
    }
    // Refund after the deletes commit so a refund that races an
    // in-flight save (delete -> save -> refund) doesn't push the
    // counter above the cap.
    for (final t in typeById.values) {
      await SubscriptionService.instance.refundScan(t);
    }
    return deleted;
  }

  /// Delete a single check by its document id. No-op if the doc doesn't
  /// exist (Firestore treats `.delete()` on a missing doc as a no-op).
  /// The home / history subscribers are Firestore snapshots streams so
  /// they rebuild automatically once the delete commits.
  Future<void> deleteOne(String checkId) async {
    // Snapshot first so we know the type for the refund.
    final doc = await _checks.doc(checkId).get();
    if (doc.exists) {
      await doc.reference.delete();
      await SubscriptionService.instance
          .refundScan(parseScanType(doc.data()?['type']));
    } else {
      await _checks.doc(checkId).delete();
    }
  }

  /// Delete a specific set of checks in batches of 450. Used by the
  /// "Select scans to delete" sheet on the Profile screen. Returns the
  /// number of docs that were issued for deletion — Firestore's
  /// `batch.commit()` doesn't distinguish "succeeded" from "no-op
  /// missing doc", so we count what the caller asked for.
  Future<int> deleteMany(Iterable<String> checkIds) async {
    final ids = checkIds.toList(growable: false);
    if (ids.isEmpty) return 0;

    // Snapshot the docs we plan to delete so we can refund the
    // correct kind for each. A `null` `get()` (already deleted by
    // another path) is silently skipped — the refund is best-effort.
    final typeById = <String, ScanType>{};
    for (final id in ids) {
      final doc = await _checks.doc(id).get();
      if (doc.exists) {
        typeById[id] = parseScanType(doc.data()?['type']);
      }
    }

    const chunkSize = 450;
    var deleted = 0;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, ids.length);
      final batch = _db.batch();
      for (final id in ids.sublist(i, end)) {
        batch.delete(_checks.doc(id));
      }
      await batch.commit();
      deleted += end - i;
    }
    for (final t in typeById.values) {
      await SubscriptionService.instance.refundScan(t);
    }
    return deleted;
  }

  static HistoryEntry _fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    return HistoryEntry(
      // Firestore document id — used as a stable identity for cross-device
      // read-state (see AlertService.seenIds). Not persisted anywhere
      // outside the document itself.
      checkId: d.id,
      result: deserializeCheck(data),
      originalText: (data['originalText'] as String?) ?? '',
      createdAt: data['createdAt'] as Object?,
      type: parseScanType(data['type']),
    );
  }
}

/// One row in the history list - pairs the parsed [RiskResult] with the
/// original message text so the list and detail screens can render both.
/// `createdAt` is the raw Firestore timestamp object (a [Timestamp] when read
/// back from Firestore, or a server-sentinel when round-tripped locally).
class HistoryEntry {
  const HistoryEntry({
    required this.checkId,
    required this.result,
    required this.originalText,
    this.createdAt,
    this.type = ScanType.message,
  });

  /// Firestore document id (`users/{uid}/checks/{checkId}`). Stable for
  /// the lifetime of the document; used by the alert system to track
  /// read-state in SharedPreferences.
  final String checkId;
  final RiskResult result;
  final String originalText;
  final Object? createdAt;
  final ScanType type;
}