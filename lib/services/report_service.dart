import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Community reporting service backed by Firestore.
///
/// Firestore layout (MVP, single-collection):
///
/// ```text
/// reports/{auto-id}
///   ├── phone: "01712345678"   (normalized BD mobile)
///   ├── type: "scam"           (scam | payment | otp | job | harassment | other)
///   ├── description: "..."     (free text, optional)
///   ├── userId: <uid>          (Firebase Auth UID)
///   └── createdAt: <timestamp>
/// ```
///
/// To avoid maintaining a separate `phone_reports/{phone}` summary
/// doc — which would require a trusted backend / Cloud Function to
/// keep counts honest — this service reads by querying
/// `reports where phone == X` and aggregating counts client-side.
/// That keeps the system fully inside the Spark (free) tier.
///
/// Counts are exposed to the UI via [PhoneReportCounts], which is
/// shaped to slot directly into [PhoneRiskEngine.analyze].
class ReportService {
  ReportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Reports a phone number. The caller must be signed in.
  ///
  /// We never store the reporter's name, contact, NID, or any other
  /// personal data — only their Firebase Auth UID, which is required
  /// for moderation down the line.
  Future<void> submitPhoneReport({
    required String phone,
    required String type,
    String description = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to submit a report.');
    }

    final normalizedPhone = normalize(phone);
    if (!_looksLikeBangladeshMobile(normalizedPhone)) {
      throw Exception('Phone number is not a valid Bangladesh mobile.');
    }

    await _firestore.collection('reports').add({
      'phone': normalizedPhone,
      'type': type,
      'description': description.trim(),
      'userId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reads all reports for [phone] and aggregates counts by type.
  ///
  /// Returns zero counts when there are no reports. Never throws on
  /// a "not found" / empty result — the caller just sees zeros.
  /// Network errors do bubble up so the UI can show a snackbar.
  Future<PhoneReportCounts> getPhoneReportCounts(String phone) async {
    final normalizedPhone = normalize(phone);

    final snapshot = await _firestore
        .collection('reports')
        .where('phone', isEqualTo: normalizedPhone)
        .get();

    var total = 0;
    final byType = <String, int>{
      'scam': 0,
      'payment': 0,
      'otp': 0,
      'job': 0,
      'harassment': 0,
      'other': 0,
    };

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final type = (data['type'] as String?)?.toLowerCase() ?? 'other';
      total += 1;
      byType[type] = (byType[type] ?? 0) + 1;
    }

    final reportTypes = <String>[];
    byType.forEach((type, typeCount) {
      if (typeCount > 0) reportTypes.add(type);
    });

    return PhoneReportCounts(
      total: total,
      byType: byType,
      reportTypes: reportTypes,
    );
  }

  /// Normalizes a user-typed phone number to the canonical
  /// `01XXXXXXXXX` (11-digit BD mobile) form used as the Firestore
  /// key for the `phone` field.
  ///
  /// Exposed publicly so callers (e.g. tests) can use it without
  /// touching Firestore.
  static String normalize(String input) {
    var phone = input.replaceAll(RegExp(r'[\s\-()]'), '');

    if (phone.startsWith('+88')) {
      phone = phone.substring(3);
    } else if (phone.startsWith('88') && phone.length == 13) {
      phone = phone.substring(2);
    }

    return phone;
  }

  /// Light validation helper — checks the normalized form is a
  /// plausible BD mobile (matches the same shape the engine uses).
  static bool _looksLikeBangladeshMobile(String phone) {
    return RegExp(r'^01[3-9]\d{8}$').hasMatch(phone);
  }
}

/// Aggregated community-report data for a single phone number.
class PhoneReportCounts {
  const PhoneReportCounts({
    required this.total,
    required this.byType,
    required this.reportTypes,
  });

  /// Total number of reports, regardless of type.
  final int total;

  /// Map of report type → count. Keys are lowercase canonical
  /// values (`scam`, `payment`, `otp`, `job`, `harassment`, `other`).
  final Map<String, int> byType;

  /// Distinct types that have at least one report. Already in the
  /// shape that [PhoneRiskEngine.analyze] expects for `reportTypes`.
  final List<String> reportTypes;
}
