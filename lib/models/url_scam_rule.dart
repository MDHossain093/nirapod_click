import 'package:cloud_firestore/cloud_firestore.dart';

/// Flat, data-driven URL scam rule consumed by the URL rule engine.
///
/// Stored in Firestore at `url_scam_rules/{id}`. If Firestore is empty
/// on first launch, [defaultUrlScamRules] from
/// `lib/data/default_url_scam_rules.dart` is returned (no auto-seed —
/// see `UrlScamRuleService.loadRules` for the rationale; the message-side
/// `scam_patterns` collection denies client writes, so we don't try to
/// write the URL fallback on first launch either).
///
/// Schema versioning follows the same convention as [ScamRule]:
/// `version: 1` is a literal sentinel — bump on breaking changes.
/// The doc id is the rule id; renames stay safe.
class UrlScamRule {
  /// Stable identifier used as the Firestore doc id. Also the join key
  /// if/when we add analytics or per-rule admin controls.
  final String id;

  /// Type discriminator — picks the matcher the engine uses for this
  /// rule. Stored as a string in Firestore (`'tld' | 'extension' |
  /// 'keyword' | 'brand' | 'shortener' | 'foreign_tld'`) so admins
  /// can introduce new types only via an app release.
  final UrlScamRuleType type;

  /// Free-form output category the engine tags the URL with when this
  /// rule fires. Examples: `'Suspicious Domain'`, `'Phishing'`,
  /// `'Possible Impersonation'`, `'Shortened URL'`, `'Suspicious URL'`.
  ///
  /// Intentionally NOT an enum so admins can introduce new categories
  /// without a code change.
  final String category;

  /// Single substring/suffix to match. One entry per doc — admins add
  /// a new doc for each TLD, brand, keyword, etc. Storage cost is
  /// trivial at v1's expected scale (~70 docs).
  final String pattern;

  /// Score points added when this rule fires. The engine sums scores
  /// across all matching rules and clamps to `[0, 100]`.
  final int score;

  /// Set to `false` from the admin panel to disable a rule without
  /// deleting the doc (preserves history). Defaults to `true`.
  final bool active;

  const UrlScamRule({
    required this.id,
    required this.type,
    required this.category,
    required this.pattern,
    required this.score,
    this.active = true,
  });

  /// Serialise for Firestore. Doc id is the rule id; we deliberately
  /// do NOT store `id` inside the document body so renames are safe.
  ///
  /// `type` is stored as its `.name` ('tld', 'extension', …) so the doc
  /// stays human-readable in the Firebase Console.
  ///
  /// `updatedAt` uses the server clock (not `DateTime.now()`) so the
  /// admin panel can sort by real write time regardless of client
  /// clock skew.
  Map<String, dynamic> toFirestore() => {
        'type': type.name,
        'category': category,
        'pattern': pattern,
        'score': score,
        'active': active,
        'version': 1, // schema version — bump on backwards-incompatible changes
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Parse a Firestore snapshot into a [UrlScamRule]. Defensive against
  /// missing fields (e.g. an admin hand-deleted a key) — `active`
  /// defaults to `true` because the natural state is "rule fires", and
  /// `type` defaults to [UrlScamRuleType.keyword] as the most generic
  /// matcher (better than silently dropping the rule).
  factory UrlScamRule.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final typeName = data['type'] as String?;
    final type = UrlScamRuleType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => UrlScamRuleType.keyword,
    );
    return UrlScamRule(
      id: doc.id,
      type: type,
      category: (data['category'] as String?) ?? 'Suspicious URL',
      pattern: (data['pattern'] as String?) ?? '',
      score: (data['score'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? true,
    );
  }

  @override
  String toString() =>
      'UrlScamRule(id: $id, type: $type, category: $category, '
      'pattern: $pattern, score: $score, active: $active)';
}

/// Type discriminator for [UrlScamRule].
///
/// Each value maps to a specific matcher in [UrlRiskEngine]:
///   * [tld] — suffix match against the URL host (`.tk`, `.ml`, …).
///   * [foreignTld] — suffix match, soft penalty applied only when at
///     least one other rule has fired.
///   * [extension] — substring match anywhere in the URL path
///     (`.apk`, `.pdf`, …).
///   * [keyword] — substring match anywhere in the URL (English +
///     Bangla phishing terms).
///   * [shortener] — substring match against the full URL (`bit.ly`,
///     `tinyurl.com`, …).
///   * [brand] — substring match against the URL (bKash, Nagad, BD
///     bank names, …).
enum UrlScamRuleType {
  tld,
  foreignTld,
  extension,
  keyword,
  shortener,
  brand,
}
