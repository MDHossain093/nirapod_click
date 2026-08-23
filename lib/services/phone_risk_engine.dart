import '../models/phone_risk_result.dart';

/// Pure-Dart rule engine for the Phone Number Checker.
///
/// Takes a raw phone-number string, normalizes it, validates it as
/// a Bangladesh mobile number, looks up the operator, and produces
/// a [PhoneRiskResult].
///
/// For now the engine is **local-only**: it accepts community
/// `reportCount` + `reportTypes` as parameters (so the UI layer can
/// pass them in once Firestore is wired up) but doesn't reach out
/// to the network. That mirrors `RiskEngine` / `UrlRiskEngine` —
/// keep all rule logic in pure Dart so it stays testable and fast.
///
/// Score policy (max 100):
///   - 1 report           -> +20  ("reported by users")
///   - 3 reports          -> +15  ("multiple users")
///   - 10 reports         -> +20  ("many reports")
///   - scam reports       -> +20
///   - payment reports    -> +20
///   - otp reports        -> +25
///   - job reports        -> +15
///
/// Level buckets: 0-14 safe, 15-34 low, 35-59 medium, 60-79 high,
/// 80-100 critical.
class PhoneRiskEngine {
  PhoneRiskResult analyze(
    String input, {
    int reportCount = 0,
    List<String> reportTypes = const [],
  }) {
    final phone = _normalize(input);

    final reasons = <String>[];
    final recommendations = <String>[];

    if (!_isValidBangladeshNumber(phone)) {
      return PhoneRiskResult(
        phoneNumber: phone,
        isValid: false,
        operator: 'Unknown',
        level: PhoneRiskLevel.safe,
        score: 0,
        reportCount: reportCount,
        reasons: const [
          'This does not appear to be a valid Bangladesh mobile number.',
        ],
        recommendations: const [
          'Check the number and try again.',
        ],
      );
    }

    var score = 0;

    final operator = _getOperator(phone);

    // -- Community reports --
    if (reportCount >= 1) {
      score += 20;
      reasons.add('This number has been reported by users.');
    }

    if (reportCount >= 3) {
      score += 15;
      reasons.add('Multiple users have reported this number.');
    }

    if (reportCount >= 10) {
      score += 20;
      reasons.add('This number has received many reports.');
    }

    // -- Report categories --
    if (reportTypes.contains('scam')) {
      score += 20;
      reasons.add('Users have reported possible scam activity.');
    }

    if (reportTypes.contains('payment')) {
      score += 20;
      reasons.add('Users have reported payment-related activity.');
    }

    if (reportTypes.contains('otp')) {
      score += 25;
      reasons.add(
        'Users have reported requests for OTP or verification codes.',
      );
    }

    if (reportTypes.contains('job')) {
      score += 15;
      reasons.add('Users have reported suspicious job offers.');
    }

    score = score.clamp(0, 100);

    final level = _getLevel(score);

    recommendations.addAll(_getRecommendations(level));

    return PhoneRiskResult(
      phoneNumber: phone,
      isValid: true,
      operator: operator,
      level: level,
      score: score,
      reportCount: reportCount,
      reasons: reasons,
      recommendations: recommendations,
    );
  }

  /// Strips whitespace, dashes, parens, and the +88 / 88 country code
  /// prefix. The remainder should be a 11-digit number starting with
  /// `01` for [_isValidBangladeshNumber] to accept it.
  String _normalize(String input) {
    var phone = input.replaceAll(RegExp(r'[\s\-()]'), '');

    if (phone.startsWith('+88')) {
      phone = phone.substring(3);
    }

    if (phone.startsWith('88') && phone.length == 13) {
      phone = phone.substring(2);
    }

    return phone;
  }

  /// Bangladesh mobile numbers are 11 digits: `0` + `1` + `[3-9]`
  /// + 8 more digits. (Landlines and short codes are intentionally
  /// rejected for v1 — community reports only cover mobile.)
  bool _isValidBangladeshNumber(String phone) {
    return RegExp(r'^01[3-9]\d{8}$').hasMatch(phone);
  }

  /// Maps the 3-digit prefix to a brand. Centralized so it can be
  /// updated if BTRC reassigns blocks.
  String _getOperator(String phone) {
    if (phone.length < 3) return 'Unknown';

    final prefix = phone.substring(0, 3);

    const operators = {
      '013': 'Grameenphone',
      '017': 'Grameenphone',
      '019': 'Banglalink',
      '014': 'Banglalink',
      '016': 'Airtel',
      '018': 'Robi',
      '015': 'Teletalk',
    };

    return operators[prefix] ?? 'Unknown';
  }

  PhoneRiskLevel _getLevel(int score) {
    if (score >= 80) return PhoneRiskLevel.critical;
    if (score >= 60) return PhoneRiskLevel.high;
    if (score >= 35) return PhoneRiskLevel.medium;
    if (score >= 15) return PhoneRiskLevel.low;
    return PhoneRiskLevel.safe;
  }

  List<String> _getRecommendations(PhoneRiskLevel level) {
    switch (level) {
      case PhoneRiskLevel.critical:
        return const [
          'Do not send money to this number.',
          'Do not share OTP, PIN, or passwords.',
          'Avoid calling back if you do not know the caller.',
          'Consider blocking and reporting the number.',
        ];
      case PhoneRiskLevel.high:
        return const [
          'Be extremely careful when communicating.',
          'Do not share sensitive information.',
          'Verify the caller independently.',
        ];
      case PhoneRiskLevel.medium:
        return const [
          'Proceed with caution.',
          'Do not share financial or personal information.',
        ];
      case PhoneRiskLevel.low:
        return const [
          'Stay cautious if you do not recognize this number.',
        ];
      case PhoneRiskLevel.safe:
        return const [
          'No suspicious reports were found.',
          'Still avoid sharing OTP, PIN, or passwords.',
        ];
    }
  }
}
