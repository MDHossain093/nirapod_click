import '../core/locale/localizer.dart';
import '../data/default_scam_rules.dart';
import '../models/risk_result.dart';
import '../models/scam_rule.dart';

class RiskEngine {
  /// Construct an engine with an optional rule bundle.
  ///
  /// Defaults to [defaultScamRules] (the 6 rules bundled with the APK)
  /// so existing callers — `RiskEngine()` and the eager
  /// `_riskEngine = RiskEngine()` inside [HybridAnalyzer] — keep
  /// working without any change to their constructor.
  ///
  /// Production code should pass the rules loaded by
  /// [ScamRuleService] (Firestore with bundled fallback).
  RiskEngine({List<ScamRule>? rules})
      : _rules = rules ?? defaultScamRules;

  /// Active rule bundle. The order doesn't matter — each rule is
  /// independent — but we iterate it on every message so we keep it
  /// small (≤ ~50 rules expected for v1).
  final List<ScamRule> _rules;

  /// Convenience handle to the context-free Localizer singleton.
  /// The current locale is set by [AppLocaleScope.updateShouldNotify]
  /// whenever the user picks a language, so the engine picks up the
  /// right language on the next call without any explicit plumbing.
  static final Localizer _loc = Localizer.instance;

  RiskResult analyzeMessage(String message) {
    final text = _normalize(message);

    int score = 0;
    final reasons = <String>[];
    final categories = <String>[];

    // ─────────────────────────────────────
    // 1–6. DATA-DRIVEN RULES
    // ─────────────────────────────────────
    //
    // Replaces the six separate keyword arrays that used to live
    // here. The keyword lists, scores, categories, and human-readable
    // reasons now live in [defaultScamRules] / Firestore
    // `scam_patterns/{id}` and can be updated without rebuilding the
    // app. The combinator rules further down still reference the
    // matched categories by name, so the wiring is unchanged.
    //
    // We collect matched categories into a `Set` first and then copy
    // them to the ordered `categories` list so the priority order in
    // `_getCategory` (Credential Theft > Phishing > Payment Scam >
    // Prize Scam > Job Scam > first non-empty) keeps working
    // identically when a future ScamRule adds a new category.

    final matchedCategories = <String>{};
    for (final rule in _rules) {
      if (!rule.active) continue;
      if (rule.keywords.any(text.contains)) {
        score += rule.score;
        reasons.add(_reasonFor(rule.category));
        matchedCategories.add(rule.category);
      }
    }
    categories.addAll(matchedCategories);

    // ─────────────────────────────────────
    // 7. URL DETECTION
    // ─────────────────────────────────────

    final urls = _extractUrls(text);

    if (urls.isNotEmpty) {
      score += 15;
      reasons.add(_loc.tr('reason.containsLink'));
      categories.add('Suspicious Link');
    }

    // ─────────────────────────────────────
    // 8. SUSPICIOUS URL PATTERNS
    // ─────────────────────────────────────

    if (_hasSuspiciousUrl(text)) {
      score += 20;
      reasons.add(_loc.tr('reason.suspiciousUrlPatterns'));
      categories.add('Phishing');
    }

    // ─────────────────────────────────────
    // 9. PHONE NUMBER
    // ─────────────────────────────────────

    final phoneNumbers = _extractBangladeshPhones(text);

    if (phoneNumbers.isNotEmpty) {
      reasons.add(_loc.tr('reason.bdPhoneNumber'));
    }

    // ─────────────────────────────────────
    // 10. IMPERSONATION
    // ─────────────────────────────────────

    final organizationPatterns = [
      'bank',
      'bkash',
      'nagad',
      'rocket',
      'government',
      'police',
      'court',
      'brac',
      'visa',
      'tax',
      'বাংলাদেশ ব্যা�ক',
      'সরকার',
      'পুলিশ',
      'ব্যাংক',
    ];

    if (_containsAny(text, organizationPatterns)) {
      if (urls.isNotEmpty ||
          matchedCategories.contains('Credential Theft') ||
          matchedCategories.contains('Payment Scam')) {
        score += 15;

        reasons.add(_loc.tr('reason.orgImpersonation'));

        categories.add('Impersonation');
      }
    }

    // ─────────────────────────────────────
    // 11. COMBINATION RULES
    // ─────────────────────────────────────
    //
    // Combinators check the matched `categories` set populated by the
    // data-driven loop above. This is the right seam: the combo fires
    // when the corresponding ScamRules fired, regardless of how the
    // admin reworded or rewrote the keywords.

    final hasPayment = matchedCategories.contains('Payment Scam');
    final hasSensitive = matchedCategories.contains('Credential Theft');
    final hasUrgency = matchedCategories.contains('Urgency');
    final hasPrize = matchedCategories.contains('Prize Scam');

    // Payment + sensitive information
    if (hasPayment && hasSensitive) {
      score += 15;

      reasons.add(_loc.tr('reason.paymentPlusSensitive'));
    }

    // Urgency + URL
    if (hasUrgency && urls.isNotEmpty) {
      score += 10;

      reasons.add(_loc.tr('reason.urgencyPlusUrl'));
    }

    // Prize + payment
    if (hasPrize && hasPayment) {
      score += 15;

      reasons.add(_loc.tr('reason.prizePlusPayment'));
    }

    score = score.clamp(0, 100);

    final level = _getLevel(score);

    final confidence = _calculateConfidence(
      score: score,
      reasonCount: reasons.length,
      categoryCount: categories.length,
    );

    return RiskResult(
      level: level,
      score: score,
      confidence: confidence,
      reasons: reasons,
      recommendations: _getRecommendations(level),
      category: _getCategory(categories),
      usedAi: false,
    );
  }

  // ─────────────────────────────────────────
  // NORMALIZE
  // ─────────────────────────────────────────

  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ─────────────────────────────────────────
  // REASON LOOKUP
  // ─────────────────────────────────────────
  //
  // Resolves the rule's `category` to a localized reason string via
  // the context-free [Localizer] singleton. All entries live in
  // `lib/core/locale/localizer.dart` under `reason.*`; English is
  // the source of truth and Bangla falls back to English.
  String _reasonFor(String category) {
    switch (category) {
      case 'Urgency':
        return _loc.tr('reason.urgency');
      case 'Payment Scam':
        return _loc.tr('reason.paymentScam');
      case 'Credential Theft':
        return _loc.tr('reason.credentialTheft');
      case 'Prize Scam':
        return _loc.tr('reason.prizeScam');
      case 'Account Scam':
        return _loc.tr('reason.accountScam');
      case 'Job Scam':
        return _loc.tr('reason.jobScam');
      // -- Bangladesh-specific categories (see default_scam_rules.dart).
      // Each gets its own reason so the alert/history UI can explain
      // exactly which signal tripped, instead of falling back to the
      // generic "Matches a known scam pattern" string.
      case 'KYC Update':
        return _loc.tr('reason.kycUpdate');
      case 'SIM Block Threat':
        return _loc.tr('reason.simBlockThreat');
      case 'Fake Courier':
        return _loc.tr('reason.fakeCourier');
      case 'Utility Bill':
        return _loc.tr('reason.utilityBill');
      case 'Govt Subsidy':
        return _loc.tr('reason.govtSubsidy');
      case 'Police Threat':
        return _loc.tr('reason.policeThreat');
      case 'Family Impersonation':
        return _loc.tr('reason.familyImpersonation');
      case 'Crypto Investment':
        return _loc.tr('reason.cryptoInvestment');
      case 'Romance':
        return _loc.tr('reason.romance');
      case 'Cashback Bonus':
        return _loc.tr('reason.cashbackBonus');
      case 'Freelance Job':
        return _loc.tr('reason.freelanceJob');
      case 'Microcredit Loan':
        return _loc.tr('reason.microcreditLoan');
      case 'E-commerce Refund':
        return _loc.tr('reason.ecommerceRefund');
      case 'Device Bait':
        return _loc.tr('reason.deviceBait');
      case 'OTP Share Request':
        return _loc.tr('reason.otpShareRequest');
      default:
        return _loc.tr('reason.genericMatch');
    }
  }

  // ─────────────────────────────────────────
  // KEYWORD MATCH
  // ─────────────────────────────────────────

  bool _containsAny(
    String text,
    List<String> patterns,
  ) {
    return patterns.any(text.contains);
  }

  // ─────────────────────────────────────────
  // URL EXTRACTION
  // ─────────────────────────────────────────

  List<String> _extractUrls(String text) {
    final regex = RegExp(
      r'((https?:\/\/|www\.)[^\s]+)',
      caseSensitive: false,
    );

    return regex
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList();
  }

  // ─────────────────────────────────────────
  // SUSPICIOUS URL
  // ─────────────────────────────────────────

  bool _hasSuspiciousUrl(String text) {
    final urls = _extractUrls(text);

    for (final url in urls) {
      if (_isSuspiciousUrl(url)) {
        return true;
      }
    }

    return false;
  }

  bool _isSuspiciousUrl(String url) {
    final suspiciousPatterns = [
      'login-',
      'verify-',
      'verification',
      'secure-',
      'account-',
      'update-',
      'free-',
      'claim-',
      'prize-',
      'reward-',
      'bit.ly',
      'tinyurl',
      't.co/',
    ];

    return suspiciousPatterns.any(
      url.toLowerCase().contains,
    );
  }

  // ─────────────────────────────────────────
  // BANGLADESH PHONE NUMBERS
  // ─────────────────────────────────────────

  List<String> _extractBangladeshPhones(
    String text,
  ) {
    final regex = RegExp(
      r'(?<!\d)(?:\+?88)?01[3-9]\d{8}(?!\d)',
    );

    return regex
        .allMatches(text)
        .map((match) => match.group(0)!)
        .toList();
  }

  // ─────────────────────────────────────────
  // RISK LEVEL
  // ─────────────────────────────────────────

  RiskLevel _getLevel(int score) {
    if (score >= 80) {
      return RiskLevel.critical;
    }

    if (score >= 60) {
      return RiskLevel.high;
    }

    if (score >= 35) {
      return RiskLevel.medium;
    }

    if (score >= 15) {
      return RiskLevel.low;
    }

    return RiskLevel.safe;
  }

  // ─────────────────────────────────────────
  // CONFIDENCE
  // ─────────────────────────────────────────

  double _calculateConfidence({
    required int score,
    required int reasonCount,
    required int categoryCount,
  }) {
    double confidence = 0.50;

    if (reasonCount >= 2) {
      confidence += 0.15;
    }

    if (reasonCount >= 4) {
      confidence += 0.10;
    }

    if (categoryCount >= 2) {
      confidence += 0.10;
    }

    if (score >= 70) {
      confidence += 0.10;
    }

    if (score >= 85) {
      // Strong-score boost: a single critical-tier signal at score=85
      // now lands at 0.80 (0.50 base + 0.10 [≥70] + 0.20) — exactly the
      // AI gate threshold, so obvious scams resolve locally instead of
      // hitting Gemini. Was +0.05 before this change, which left
      // single-signal criticals at 0.65 → AI fallback unnecessarily.
      confidence += 0.20;
    }

    return confidence.clamp(0.0, 0.99);
  }

  // ─────────────────────────────────────────
  // CATEGORY
  // ─────────────────────────────────────────

  String _getCategory(List<String> categories) {
    if (categories.isEmpty) {
      return _loc.tr('category.general');
    }

    if (categories.contains('Credential Theft')) {
      return _loc.tr('category.credentialTheft');
    }

    if (categories.contains('Phishing')) {
      return _loc.tr('category.phishing');
    }

    if (categories.contains('Payment Scam')) {
      return _loc.tr('category.paymentScam');
    }

    if (categories.contains('Prize Scam')) {
      return _loc.tr('category.prizeScam');
    }

    if (categories.contains('Job Scam')) {
      return _loc.tr('category.jobScam');
    }

    return categories.first;
  }

  // ─────────────────────────────────────────
  // RECOMMENDATIONS
  // ─────────────────────────────────────────

  List<String> _getRecommendations(
    RiskLevel level,
  ) {
    switch (level) {
      case RiskLevel.critical:
        return [
          _loc.tr('rec.critical.1'),
          _loc.tr('rec.critical.2'),
          _loc.tr('rec.critical.3'),
          _loc.tr('rec.critical.4'),
        ];

      case RiskLevel.high:
        return [
          _loc.tr('rec.high.msg.1'),
          _loc.tr('rec.high.msg.2'),
          _loc.tr('rec.high.msg.3'),
        ];

      case RiskLevel.medium:
        return [
          _loc.tr('rec.medium.msg.1'),
          _loc.tr('rec.medium.msg.2'),
          _loc.tr('rec.medium.msg.3'),
        ];

      case RiskLevel.low:
        return [
          _loc.tr('rec.low.msg.1'),
          _loc.tr('rec.low.msg.2'),
        ];

      case RiskLevel.safe:
        return [
          _loc.tr('rec.safe.msg.1'),
          _loc.tr('rec.safe.msg.2'),
        ];
    }
  }
}
