import 'package:cloud_firestore/cloud_firestore.dart';

/// An admin-published safety message surfaced in the Alerts page.
///
/// Distinct from scan-derived alerts (which live under each user's
/// `users/{uid}/checks/*`). Admin alerts are global reference data
/// stored in `admin_alerts/{alertId}` and read by every signed-in user.
///
/// Fields:
///   - id              string  — Firestore doc id, also surfaced as the
///                               dedupe key for "seen" state in
///                               SharedPreferences.
///   - titleEn/titleBn string  — short headline, ≤ 80 chars each.
///   - bodyEn/bodyBn   string  — full message, ≤ 500 chars each.
///   - severity        string  — "info" | "warning" | "critical"
///                               drives the card color.
///   - active          bool    — admin can disable without deleting.
///   - version         int     — schema version, bump on breaking changes.
///   - createdAt       server timestamp
class AdminAlert {
  /// Severity band drives the on-screen color. Info = brand-tinted
  /// card; warning = amber; critical = red (matches the rest of the
  /// app's risk palette in `AppTheme.riskHigh` / `riskCritical`).
  static const String severityInfo = 'info';
  static const String severityWarning = 'warning';
  static const String severityCritical = 'critical';

  /// Hard caps enforced both client- and server-side.
  static const int maxTitle = 80;
  static const int maxBody = 500;

  final String id;
  final String titleEn;
  final String titleBn;
  final String bodyEn;
  final String bodyBn;
  final String severity;
  final bool active;

  const AdminAlert({
    required this.id,
    required this.titleEn,
    required this.titleBn,
    required this.bodyEn,
    required this.bodyBn,
    required this.severity,
    this.active = true,
  });

  /// True when the severity string is one we know how to render.
  /// Used by [AdminAlertService] to drop malformed rows silently
  /// (same fail-soft philosophy as [ScamRuleService]).
  bool get hasValidSeverity =>
      severity == severityInfo ||
      severity == severityWarning ||
      severity == severityCritical;

  Map<String, dynamic> toFirestore() => {
        'titleEn': titleEn,
        'titleBn': titleBn,
        'bodyEn': bodyEn,
        'bodyBn': bodyBn,
        'severity': severity,
        'active': active,
        'version': 1,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// Parse a Firestore snapshot. Defensive against missing fields
  /// (e.g. an admin hand-deleted a key) so a single bad doc can't break
  /// the whole feed.
  factory AdminAlert.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AdminAlert(
      id: doc.id,
      titleEn: (data['titleEn'] as String?) ?? '',
      titleBn: (data['titleBn'] as String?) ?? '',
      bodyEn: (data['bodyEn'] as String?) ?? '',
      bodyBn: (data['bodyBn'] as String?) ?? '',
      severity: (data['severity'] as String?) ?? severityInfo,
      active: data['active'] as bool? ?? true,
    );
  }

  @override
  String toString() =>
      'AdminAlert(id: $id, severity: $severity, active: $active, '
      'titleEn: ${titleEn.length} chars)';
}