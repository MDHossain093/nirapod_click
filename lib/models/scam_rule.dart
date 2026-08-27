import 'package:cloud_firestore/cloud_firestore.dart';

/// A flat, data-driven scam rule consumed by the rule engine.
///
/// Stored in Firestore at `scam_patterns/{id}`. If Firestore is empty
/// on first launch, [defaultScamRules] from
/// `lib/data/default_scam_rules.dart` is seeded as the initial set so
/// detection still works before the admin panel has edited anything.
///
/// Schema versioning is tracked via the `version` field on the doc
/// and the matching `scam_config/current.version` counter — a future
/// migration script can decide which docs to ignore by checking
/// `version` against the app's compiled-in schema version.
class ScamRule {
  /// Stable identifier used as the Firestore doc id. Also the join key
  /// if/when we add analytics or per-rule admin controls.
  final String id;

  /// Free-form category label that ends up in the UI today. Examples:
  /// `'Urgency'`, `'Payment Scam'`, `'Credential Theft'`.
  ///
  /// This is intentionally NOT an enum so the admin panel can introduce
  /// new categories without a code change.
  final String category;

  /// Lower-cased substrings checked against the normalized message
  /// text. A match on ANY keyword fires the rule.
  final List<String> keywords;

  /// Score points to add when this rule fires. The engine sums scores
  /// across all matching rules and clamps to `[0, 100]`.
  final int score;

  /// Set to `false` from the admin panel to disable a rule without
  /// deleting the doc (preserves history). Defaults to `true`.
  final bool active;

  const ScamRule({
    required this.id,
    required this.category,
    required this.keywords,
    required this.score,
    this.active = true,
  });

  /// Serialise for Firestore. Doc id is the rule id; we deliberately
  /// do NOT store `id` inside the document body so renames are safe.
  ///
  /// `updatedAt` uses the server clock (not `DateTime.now()`) so the
  /// admin panel can sort by real write time regardless of client
  /// clock skew.
  Map<String, dynamic> toFirestore() => {
        'category': category,
        'keywords': keywords,
        'score': score,
        'active': active,
        'version': 1, // schema version — bump on backwards-incompatible changes
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Parse a Firestore snapshot into a [ScamRule]. Defensive against
  /// missing fields (e.g. an admin hand-deleted a key) — `active`
  /// defaults to `true` because the natural state is "rule fires".
  factory ScamRule.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return ScamRule(
      id: doc.id,
      category: (data['category'] as String?) ?? 'General',
      keywords: List<String>.from(data['keywords'] as List? ?? const []),
      score: (data['score'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? true,
    );
  }

  @override
  String toString() =>
      'ScamRule(id: $id, category: $category, score: $score, active: $active, '
      'keywords: ${keywords.length})';
}