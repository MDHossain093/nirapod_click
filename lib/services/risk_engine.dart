import '../models/risk_result.dart';

class RiskEngine {
  RiskResult analyzeMessage(String message) {
    final text = _normalize(message);

    int score = 0;
    final reasons = <String>[];
    final categories = <String>[];

    // ─────────────────────────────────────
    // 1. URGENCY
    // ─────────────────────────────────────

    final urgencyPatterns = [
      'urgent',
      'immediately',
      'act now',
      'right now',
      'last chance',
      'জরুরি',
      'এখনই',
      'তাড়াতাড়ি',
      'অতি জরুরি',
      'আজকের মধ্যে',
    ];

    if (_containsAny(text, urgencyPatterns)) {
      score += 15;
      reasons.add('Creates a sense of urgency');
      categories.add('Urgency');
    }

    // ─────────────────────────────────────
    // 2. PAYMENT
    // ─────────────────────────────────────

    final paymentPatterns = [
      'send money',
      'send payment',
      'make payment',
      'pay now',
      'payment required',
      'registration fee',
      'processing fee',
      'টাকা পাঠান',
      'টাকা দিন',
      'পেমেন্ট করুন',
      'ফি দিন',
      'রেজিস্ট্রেশন ফি',
      'প্রসেসিং ফি',
    ];

    if (_containsAny(text, paymentPatterns)) {
      score += 25;
      reasons.add('Requests money or payment');
      categories.add('Payment Scam');
    }

    // ─────────────────────────────────────
    // 3. SENSITIVE INFORMATION
    // ─────────────────────────────────────

    final sensitivePatterns = [
      'otp',
      'one time password',
      'pin',
      'password',
      'verification code',
      'security code',
      'ওটিপি',
      'পিন',
      'পাসওয়ার্ড',
      'ভেরিফিকেশন কোড',
      'সিকিউরিটি কোড',
    ];

    if (_containsAny(text, sensitivePatterns)) {
      score += 30;
      reasons.add(
        'Requests sensitive authentication information',
      );
      categories.add('Credential Theft');
    }

    // ─────────────────────────────────────
    // 4. PRIZE / LOTTERY
    // ─────────────────────────────────────

    final prizePatterns = [
      'you won',
      'you have won',
      'winner',
      'lottery',
      'prize',
      'reward',
      'congratulations',
      'পুরস্কার',
      'লটারি',
      'আপনি জিতেছেন',
      'অভিনন্দন',
      'পুরস্কার পেয়েছেন',
    ];

    if (_containsAny(text, prizePatterns)) {
      score += 20;
      reasons.add(
        'Contains a prize or winning claim',
      );
      categories.add('Prize Scam');
    }

    // ─────────────────────────────────────
    // 5. ACCOUNT THREATS
    // ─────────────────────────────────────

    final accountPatterns = [
      'account blocked',
      'account suspended',
      'account will be closed',
      'account disabled',
      'verify your account',
      'অ্যাকাউন্ট বন্ধ',
      'অ্যাকাউন্ট ব্লক',
      'অ্যাকাউন্ট বাতিল',
      'অ্যাকাউন্ট স্থগিত',
      'অ্যাকাউন্ট ভেরিফাই',
    ];

    if (_containsAny(text, accountPatterns)) {
      score += 20;
      reasons.add(
        'Uses an account suspension or closure threat',
      );
      categories.add('Account Scam');
    }

    // ─────────────────────────────────────
    // 6. JOB SCAM
    // ─────────────────────────────────────

    final jobPatterns = [
      'work from home',
      'easy income',
      'earn money',
      'part time job',
      'online job',
      'job opportunity',
      'চাকরি',
      'জব',
      'ঘরে বসে আয়',
      'অনলাইন কাজ',
      'পার্ট টাইম',
      'নিয়োগ',
    ];

    if (_containsAny(text, jobPatterns)) {
      score += 15;
      reasons.add(
        'Contains possible job-offer scam indicators',
      );
      categories.add('Job Scam');
    }

    // ─────────────────────────────────────
    // 7. URL DETECTION
    // ─────────────────────────────────────

    final urls = _extractUrls(text);

    if (urls.isNotEmpty) {
      score += 15;
      reasons.add(
        'Contains a web link',
      );
      categories.add('Suspicious Link');
    }

    // ─────────────────────────────────────
    // 8. SUSPICIOUS URL PATTERNS
    // ─────────────────────────────────────

    if (_hasSuspiciousUrl(text)) {
      score += 20;
      reasons.add(
        'The link contains suspicious URL patterns',
      );
      categories.add('Phishing');
    }

    // ─────────────────────────────────────
    // 9. PHONE NUMBER
    // ─────────────────────────────────────

    final phoneNumbers = _extractBangladeshPhones(text);

    if (phoneNumbers.isNotEmpty) {
      reasons.add(
        'Contains a Bangladesh phone number',
      );
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
      'বাংলাদেশ ব্যাংক',
      'সরকার',
      'পুলিশ',
      'ব্যাংক',
    ];

    if (_containsAny(text, organizationPatterns)) {
      if (urls.isNotEmpty ||
          _containsAny(text, sensitivePatterns) ||
          _containsAny(text, paymentPatterns)) {
        score += 15;

        reasons.add(
          'May be impersonating an organization or service',
        );

        categories.add('Impersonation');
      }
    }

    // ─────────────────────────────────────
    // 11. COMBINATION RULES
    // ─────────────────────────────────────

    final hasPayment =
        _containsAny(text, paymentPatterns);

    final hasSensitive =
        _containsAny(text, sensitivePatterns);

    final hasUrgency =
        _containsAny(text, urgencyPatterns);

    final hasPrize =
        _containsAny(text, prizePatterns);

    // Payment + sensitive information
    if (hasPayment && hasSensitive) {
      score += 15;

      reasons.add(
        'Combines a payment request with sensitive information',
      );
    }

    // Urgency + URL
    if (hasUrgency && urls.isNotEmpty) {
      score += 10;

      reasons.add(
        'Uses urgency together with a web link',
      );
    }

    // Prize + payment
    if (hasPrize && hasPayment) {
      score += 15;

      reasons.add(
        'Requests payment related to a prize or reward',
      );
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
      confidence += 0.05;
    }

    return confidence.clamp(0.0, 0.99);
  }

  // ─────────────────────────────────────────
  // CATEGORY
  // ─────────────────────────────────────────

  String _getCategory(List<String> categories) {
    if (categories.isEmpty) {
      return 'General';
    }

    if (categories.contains('Credential Theft')) {
      return 'Credential Theft';
    }

    if (categories.contains('Phishing')) {
      return 'Phishing';
    }

    if (categories.contains('Payment Scam')) {
      return 'Payment Scam';
    }

    if (categories.contains('Prize Scam')) {
      return 'Prize Scam';
    }

    if (categories.contains('Job Scam')) {
      return 'Job Scam';
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
          'Do not click any links.',
          'Do not send money.',
          'Never share OTP, PIN, or passwords.',
          'Verify the claim through an official channel.',
        ];

      case RiskLevel.high:
        return [
          'Avoid clicking links in the message.',
          'Do not share sensitive information.',
          'Verify the sender independently.',
        ];

      case RiskLevel.medium:
        return [
          'Be careful before responding.',
          'Verify the sender or organization.',
          'Avoid sharing personal information.',
        ];

      case RiskLevel.low:
        return [
          'Stay cautious.',
          'Verify important claims before taking action.',
        ];

      case RiskLevel.safe:
        return [
          'No major warning signs were detected.',
          'Continue to avoid sharing sensitive information.',
        ];
    }
  }
}