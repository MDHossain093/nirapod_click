import '../core/locale/localizer.dart';
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
  /// Convenience handle to the context-free Localizer singleton.
  /// The current locale is set by [AppLocaleScope.updateShouldNotify]
  /// whenever the user picks a language, so the engine picks up the
  /// right language on the next call without any explicit plumbing.
  static final Localizer _loc = Localizer.instance;

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
        operator: _loc.tr('phoneOperator.unknown'),
        level: PhoneRiskLevel.safe,
        score: 0,
        reportCount: reportCount,
        reasons: [
          _loc.tr('phoneReason.invalidNumber'),
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
      reasons.add(_loc.tr('phoneReason.oneReport'));
    }

    if (reportCount >= 3) {
      score += 15;
      reasons.add(_loc.tr('phoneReason.multipleReports'));
    }

    if (reportCount >= 10) {
      score += 20;
      reasons.add(_loc.tr('phoneReason.manyReports'));
    }

    // -- Report categories --
    if (reportTypes.contains('scam')) {
      score += 20;
      reasons.add(_loc.tr('phoneReason.scamReports'));
    }

    if (reportTypes.contains('payment')) {
      score += 20;
      reasons.add(_loc.tr('phoneReason.paymentReports'));
    }

    if (reportTypes.contains('otp')) {
      score += 25;
      reasons.add(_loc.tr('phoneReason.otpReports'));
    }

    if (reportTypes.contains('job')) {
      score += 15;
      reasons.add(_loc.tr('phoneReason.jobReports'));
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
  /// prefix. The remainder should be an 11-digit number starting with
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
  /// updated if BTRC reassigns blocks. Operator names stay in English
  /// because they're proper nouns (brand names) — same convention as
  /// the rest of the app for things like "bKash" / "Nagad".
  String _getOperator(String phone) {
    if (phone.length < 3) return _loc.tr('phoneOperator.unknown');

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

    return operators[prefix] ?? _loc.tr('phoneOperator.unknown');
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
        return [
          _loc.tr('rec.critical.phone.1'),
          _loc.tr('rec.critical.phone.2'),
          _loc.tr('rec.critical.phone.3'),
          _loc.tr('rec.critical.phone.4'),
        ];
      case PhoneRiskLevel.high:
        return [
          _loc.tr('rec.high.phone.1'),
          _loc.tr('rec.high.phone.2'),
          _loc.tr('rec.high.phone.3'),
        ];
      case PhoneRiskLevel.medium:
        return [
          _loc.tr('rec.medium.phone.1'),
          _loc.tr('rec.medium.phone.2'),
        ];
      case PhoneRiskLevel.low:
        return [
          _loc.tr('rec.low.phone.1'),
        ];
      case PhoneRiskLevel.safe:
        return [
          _loc.tr('rec.safe.phone.1'),
          _loc.tr('rec.safe.phone.2'),
        ];
    }
  }
}