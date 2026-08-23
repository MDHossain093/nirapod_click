import '../models/url_risk_result.dart';

class UrlRiskEngine {
  UrlRiskResult analyze(String input) {
    final url = input.trim();

    int score = 0;
    final reasons = <String>[];
    final categories = <String>[];

    if (url.isEmpty) {
      return UrlRiskResult(
        level: UrlRiskLevel.safe,
        score: 0,
        confidence: 0.99,
        category: 'Invalid',
        url: url,
        reasons: ['No URL was provided.'],
        recommendations: [
          'Enter a valid website URL.',
        ],
      );
    }

    // Lower-case copy used by most rules below. Declared once, up
    // front, so the keyword / shortener / TLD / extension rules
    // don't each pay the toLowerCase() cost on the same input.
    final lowerUrl = url.toLowerCase();

    // HTTPS
    if (lowerUrl.startsWith('http://')) {
      score += 10;
      reasons.add('The website does not use HTTPS.');
      categories.add('Security');
    }

    // URL length
    if (url.length > 100) {
      score += 10;
      reasons.add('The URL is unusually long.');
      categories.add('Suspicious URL');
    }

    // IP address instead of domain
    final ipRegex = RegExp(
      r'^(https?:\/\/)?'
      r'(\d{1,3}\.){3}\d{1,3}',
    );

    if (ipRegex.hasMatch(url)) {
      score += 25;
      reasons.add(
        'The link uses an IP address instead of a normal domain.',
      );
      categories.add('Suspicious URL');
    }

    // Suspicious top-level domains (cheap / abuse-prone TLDs).
    // A TLD match is weighted like a "Suspicious URL" rule but does
    // not by itself push the URL into Phishing territory — combined
    // with brand/keyword hits the combo rules will lift it further.
    const suspiciousTlds = <String>[
      '.tk', // Tokelau — historically one of the highest-abuse TLDs
      '.ml', // Mali — same pattern as .tk (Freenom legacy)
      '.cf', // Central African Republic — Freenom legacy
      '.gq', // Equatorial Guinea — Freenom legacy
      '.top', // generic .top — heavily abused in 2024–2025 phishing
      '.xyz', // generic .xyz — high abuse rate, mixed legit
      '.click', // punycode-like, almost exclusively phishing
      '.country',
    ];

    final tldHit = suspiciousTlds.firstWhere(
      (tld) => lowerUrl.endsWith(tld) ||
          lowerUrl.contains('$tld/') ||
          lowerUrl.contains('$tld?') ||
          lowerUrl.contains('$tld#'),
      orElse: () => '',
    );

    if (tldHit.isNotEmpty) {
      score += 15;
      reasons.add(
        "Uses a frequently-abused top-level domain ($tldHit).",
      );
      categories.add('Suspicious Domain');
    }

    // Dangerous file extensions served from a URL. Phishing kits
    // commonly push .apk (fake banking apps), .exe (trojans), .zip /
    // .scr (packed malware). Match anywhere in the path so query
    // strings like "file.apk?download=1" still trip it.
    const dangerousExtensions = <String>[
      '.apk',
      '.exe',
      '.zip',
      '.scr',
      '.bat',
      '.cmd',
      '.jar',
      '.iso',
    ];

    final extHit = dangerousExtensions.firstWhere(
      (ext) => lowerUrl.contains(ext),
      orElse: () => '',
    );

    if (extHit.isNotEmpty) {
      score += 20;
      reasons.add(
        'Links directly to a downloadable executable file ($extHit).',
      );
      categories.add('Suspicious URL');
    }

    // Suspicious keywords
    final suspiciousKeywords = [
      'login',
      'verify',
      'verification',
      'secure',
      'account',
      'update',
      'confirm',
      'password',
      'signin',
      'wallet',
      'claim',
      'reward',
      'prize',
      'free',
      'login',
      'ভেরিফাই',
      'অ্যাকাউন্ট',
      'পুরস্কার',
    ];

    final matchedKeywords = suspiciousKeywords
        .where(lowerUrl.contains)
        .toList();

    if (matchedKeywords.isNotEmpty) {
      score += 15;

      reasons.add(
        'Contains potentially sensitive or phishing-related terms.',
      );

      categories.add('Phishing');
    }

    // URL shorteners
    final shorteners = [
      'bit.ly',
      'tinyurl.com',
      't.co',
      'goo.gl',
      'is.gd',
      'cutt.ly',
      'shorturl.at',
    ];

    if (shorteners.any(lowerUrl.contains)) {
      score += 20;

      reasons.add(
        'Uses a URL shortening service.',
      );

      categories.add('Shortened URL');
    }

    // Excessive subdomains
    final domain = _extractDomain(url);

    if (domain != null) {
      final dotCount = '.'.allMatches(domain).length;

      if (dotCount >= 3) {
        score += 15;

        reasons.add(
          'The domain contains an unusually large number of subdomains.',
        );

        categories.add('Suspicious Domain');
      }
    }

    // Suspicious characters
    if (url.contains('@')) {
      score += 25;

      reasons.add(
        'Contains an @ symbol that can hide the actual destination.',
      );

      categories.add('Suspicious URL');
    }

    // Double slash after domain
    if (url.contains('//', 8)) {
      score += 10;

      reasons.add(
        'Contains an unusual URL structure.',
      );

      categories.add('Suspicious URL');
    }

    // Brand impersonation patterns
    final brands = [
      'bkash',
      'nagad',
      'rocket',
      'brac',
      'dbbl',
      'bank',
      'paypal',
      'facebook',
      'google',
      'microsoft',
    ];

    final brandMatched = brands.where(
      lowerUrl.contains,
    ).toList();

    if (brandMatched.isNotEmpty) {
      score += 10;

      reasons.add(
        'The URL contains a recognizable brand or service name.',
      );

      categories.add('Possible Impersonation');
    }

    // Suspicious combinations
    if (matchedKeywords.isNotEmpty &&
        brandMatched.isNotEmpty) {
      score += 15;

      reasons.add(
        'A brand name appears together with phishing-related terms.',
      );

      categories.add('Possible Impersonation');
    }

    if (shorteners.any(lowerUrl.contains) &&
        matchedKeywords.isNotEmpty) {
      score += 15;

      reasons.add(
        'A shortened URL contains sensitive or phishing-related terms.',
      );

      categories.add('Phishing');
    }

    score = score.clamp(0, 100);

    final level = _getLevel(score);

    final confidence = _calculateConfidence(
      score,
      reasons.length,
      categories.length,
    );

    return UrlRiskResult(
      level: level,
      score: score,
      confidence: confidence,
      category: _getCategory(categories),
      url: url,
      reasons: reasons,
      recommendations: _getRecommendations(level),
    );
  }

  String? _extractDomain(String url) {
    try {
      var normalized = url;

      if (!normalized.startsWith('http://') &&
          !normalized.startsWith('https://')) {
        normalized = 'https://$normalized';
      }

      final uri = Uri.parse(normalized);

      return uri.host.isEmpty ? null : uri.host;
    } catch (_) {
      return null;
    }
  }

  UrlRiskLevel _getLevel(int score) {
    if (score >= 80) {
      return UrlRiskLevel.critical;
    }

    if (score >= 60) {
      return UrlRiskLevel.high;
    }

    if (score >= 35) {
      return UrlRiskLevel.medium;
    }

    if (score >= 15) {
      return UrlRiskLevel.low;
    }

    return UrlRiskLevel.safe;
  }

  double _calculateConfidence(
    int score,
    int reasonCount,
    int categoryCount,
  ) {
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

    if (score >= 60) {
      confidence += 0.10;
    }

    if (score >= 80) {
      confidence += 0.05;
    }

    return confidence.clamp(0.0, 0.99);
  }

  String _getCategory(List<String> categories) {
    if (categories.contains('Phishing')) {
      return 'Phishing';
    }

    if (categories.contains('Possible Impersonation')) {
      return 'Impersonation';
    }

    if (categories.contains('Suspicious Domain')) {
      return 'Suspicious Domain';
    }

    if (categories.contains('Shortened URL')) {
      return 'Shortened URL';
    }

    if (categories.isEmpty) {
      return 'General';
    }

    return categories.first;
  }

  List<String> _getRecommendations(
    UrlRiskLevel level,
  ) {
    switch (level) {
      case UrlRiskLevel.critical:
        return [
          'Do not open this link.',
          'Do not enter your password or OTP.',
          'Do not provide payment information.',
          'Verify the website through an official source.',
        ];

      case UrlRiskLevel.high:
        return [
          'Avoid opening this link.',
          'Do not enter sensitive information.',
          'Verify the domain independently.',
        ];

      case UrlRiskLevel.medium:
        return [
          'Proceed carefully.',
          'Check the domain before entering information.',
          'Avoid providing sensitive information.',
        ];

      case UrlRiskLevel.low:
        return [
          'The URL has some warning signs.',
          'Verify the website before continuing.',
        ];

      case UrlRiskLevel.safe:
        return [
          'No major warning signs were detected.',
          'Always verify important websites independently.',
        ];
    }
  }
}
