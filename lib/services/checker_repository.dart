import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/risk_result.dart';

/// Limits that match `firestore.rules`. Kept in one place so the client
/// and the server agree on what's valid.
class CheckLimits {
  static const int maxOriginalText = 5000;
  static const int maxReasons = 25;
  static const int maxReasonLength = 200;
  static const int maxCategoryLength = 64;
}

/// Pure helpers — kept top-level so they're unit-testable without Firebase.
Map<String, dynamic> serializeCheck(RiskResult result, String originalText) {
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
  );
}

/// Sentinel so we don't write a real Timestamp from pure-Dart code paths
/// (tests, etc.). The repository replaces it with FieldValue.serverTimestamp
/// at write time.
class _Sentinel {
  static const Object createdAtNow = Object();
}

/// Saves user scans to Firestore and lists them back as [RiskResult]s.
///
/// Schema (per scan):
///   users/{uid}/checks/{autoId}
///     - originalText: string (<= 5000)
///     - score: int (0..100)
///     - level: "safe" | "low" | "medium" | "high" | "critical"
///     - category: string (<= 64)
///     - confidence: double (0..1)
///     - reasons: [string, ...] (<= 25, each <= 200)
///     - createdAt: serverTimestamp
class CheckerRepository {
  final FirebaseFirestore _db;
  final String _uid;

  CheckerRepository({FirebaseFirestore? db, String? uid})
      : _db = db ?? FirebaseFirestore.instance,
        _uid = uid ?? FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _checks =>
      _db.collection('users').doc(_uid).collection('checks');

  Future<void> save(RiskResult result, String originalText) async {
    final payload = serializeCheck(result, originalText);
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

  static HistoryEntry _fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    return HistoryEntry(
      result: deserializeCheck(data),
      originalText: (data['originalText'] as String?) ?? '',
      createdAt: data['createdAt'] as Object?,
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
  });
  final RiskResult result;
  final String originalText;
  final Object? createdAt;
}