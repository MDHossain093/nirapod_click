import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/risk_result.dart';

/// What kind of scan produced this entry. Stored on the document so the
/// history list can render the right icon/label without sniffing text.
enum ScanType {
  message,
  url,
  screenshot,
  phone;

  /// Stable wire name used in Firestore payloads + rules whitelist.
  String get wire => name;
}

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
  final String _uid;

  CheckerRepository({FirebaseFirestore? db, String? uid})
      : _db = db ?? FirebaseFirestore.instance,
        _uid = uid ?? FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _checks =>
      _db.collection('users').doc(_uid).collection('checks');

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
  Future<int> clearAll() async {
    final snap = await _checks.get();
    if (snap.docs.isEmpty) return 0;

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
    return deleted;
  }

  static HistoryEntry _fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    return HistoryEntry(
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
    required this.result,
    required this.originalText,
    this.createdAt,
    this.type = ScanType.message,
  });
  final RiskResult result;
  final String originalText;
  final Object? createdAt;
  final ScanType type;
}