import '../core/locale/localizer.dart';
import '../data/default_url_scam_rules.dart';
import '../models/url_risk_result.dart';
import '../models/url_scam_rule.dart';

class UrlRiskEngine {
  /// Convenience handle to the context-free Localizer singleton.
  /// The current locale is set by [AppLocaleScope.updateShouldNotify]
  /// whenever the user picks a language, so the engine picks up the
  /// right language on the next call without any explicit plumbing.
  static final Localizer _loc = Localizer.instance;

  /// Active rule bundle. Defaults to the bundled
  /// [defaultUrlScamRules]; the analyzer wires in the Firestore-loaded
  /// bundle from [UrlScamRuleService] at construction time.
  ///
  /// The engine is intentionally **not** a singleton — the analyzer
  /// rebuilds it per `analyzeUrl()` call so rule edits pushed via the
  /// Firebase Console take effect on the very next scan, without
  /// needing an app restart.
  ///
  /// (The raw list is bucketed once into [_byType] in the constructor
  /// and not referenced directly after that — we don't store the
  /// original list because every matcher path only needs its
  /// type-specific bucket.)

  /// Cached bucket view of the rule bundle keyed by [UrlScamRuleType].
  /// Built once per engine instance so each analyze() call doesn't
  /// have to re-filter the full list. With ~70 default rules this is a
  /// few hundred bytes — negligible.
  final Map<UrlScamRuleType, List<UrlScamRule>> _byType;

  /// Construct an engine with an explicit rule bundle. Pass `null` to
  /// use the bundled defaults — useful for tests that want to bypass
  /// [UrlScamRuleService].
  UrlRiskEngine({List<UrlScamRule>? rules})
      : _byType = _bucketByType(rules ?? defaultUrlScamRules);

  /// Empty bucket for [UrlScamRuleType]s with no rules. Declared once
  /// so the matcher paths below can use `?? _emptyBucket` without
  /// each call site paying a `const <UrlScamRule>[]` literal cost or
  /// widening the inferred type to `List<dynamic>` (which would then
  /// make `rule.score` resolve to `num` instead of `int`).
  static const List<UrlScamRule> _emptyBucket = <UrlScamRule>[];

  /// Group rules by their [UrlScamRuleType] so the matcher paths below
  /// can iterate only the rules they care about. `active == false`
  /// rules are dropped here so the engine never sees them.
  static Map<UrlScamRuleType, List<UrlScamRule>> _bucketByType(
    List<UrlScamRule> rules,
  ) {
    final out = <UrlScamRuleType, List<UrlScamRule>>{};
    for (final r in rules) {
      if (!r.active) continue;
      out.putIfAbsent(r.type, () => <UrlScamRule>[]).add(r);
    }
    return out;
  }

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
        category: _loc.tr('category.invalid'),
        url: url,
        reasons: [_loc.tr('urlReason.noUrl')],
        recommendations: [
          _loc.tr('urlRec.invalid.1'),
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
      reasons.add(_loc.tr('urlReason.notHttps'));
      categories.add('Security');
    }

    // URL length
    if (url.length > 100) {
      score += 10;
      reasons.add(_loc.tr('urlReason.longUrl'));
      categories.add('Suspicious URL');
    }

    // IP address instead of domain
    final ipRegex = RegExp(
      r'^(https?:\/\/)?'
      r'(\d{1,3}\.){3}\d{1,3}',
    );

    if (ipRegex.hasMatch(url)) {
      score += 25;
      reasons.add(_loc.tr('urlReason.ipAddress'));
      categories.add('Suspicious URL');
    }

    // Suspicious top-level domains (cheap / abuse-prone TLDs).
    // A TLD match is weighted like a "Suspicious URL" rule but does
    // not by itself push the URL into Phishing territory — combined
    // with brand/keyword hits the combo rules will lift it further.
    //
    // The patterns themselves live in [defaultUrlScamRules] /
    // Firestore `url_scam_rules`. Each pattern is matched as a suffix
    // (with `tld/`, `tld?`, `tld#` for path/query/fragment contexts)
    // so `example.tk/foo` matches `.tk`.
    String? tldHit;
    for (final rule in (_byType[UrlScamRuleType.tld] ?? _emptyBucket)) {
      final tld = rule.pattern;
      if (lowerUrl.endsWith(tld) ||
          lowerUrl.contains('$tld/') ||
          lowerUrl.contains('$tld?') ||
          lowerUrl.contains('$tld#')) {
        tldHit = tld;
        break;
      }
    }

    if (tldHit != null) {
      score += _scoreFor(_byType[UrlScamRuleType.tld]!, tldHit, defaultScore: 15);
      reasons.add('${_loc.tr('urlReason.abuseTld')} ($tldHit)');
      categories.add('Suspicious Domain');
    }

    // Dangerous file extensions served from a URL. Phishing kits
    // commonly push .apk (fake banking apps), .exe (trojans), .zip /
    // .scr (packed malware). Match anywhere in the path so query
    // strings like "file.apk?download=1" still trip it.
    //
    // Patterns from [defaultUrlScamRules] / Firestore `url_scam_rules`.
    String? extHit;
    for (final rule in (_byType[UrlScamRuleType.extension] ?? _emptyBucket)) {
      if (lowerUrl.contains(rule.pattern)) {
        extHit = rule.pattern;
        break;
      }
    }

    if (extHit != null) {
      score += _scoreFor(
        _byType[UrlScamRuleType.extension]!,
        extHit,
        defaultScore: 20,
      );
      reasons.add('${_loc.tr('urlReason.dangerousExt')} ($extHit)');
      categories.add('Suspicious URL');
    }

    // Suspicious keywords — substring match against the lower-cased
    // URL. Both English and Bangla patterns live in
    // [defaultUrlScamRules] / Firestore `url_scam_rules` so admins
    // can add BD phishing terms without an app release.
    final matchedKeywords = <String>[];
    int matchedKeywordScore = 0;
    for (final rule in (_byType[UrlScamRuleType.keyword] ?? _emptyBucket)) {
      if (lowerUrl.contains(rule.pattern)) {
        matchedKeywords.add(rule.pattern);
        matchedKeywordScore += rule.score;
      }
    }

    if (matchedKeywords.isNotEmpty) {
      // Sum each matched rule's score. Admin-tuned scores override
      // the historical flat 15 — typical values are still 15 per
      // rule, but a high-confidence phrase like "otp" can be priced
      // higher by an admin.
      score += matchedKeywordScore;

      reasons.add(_loc.tr('urlReason.phishingTerms'));

      categories.add('Phishing');
    }

    // Foreign-TLD soft penalty: country-code TLDs (.ru, .cn, .ng)
    // are heavily used by offshore scam operations but also by
    // legitimate users (e.g. .ng for Nigerian diaspora). Penalise
    // only when *combined with* another signal — this is what
    // differentiates "user typing `example.ng`" from "scam-kit
    // landing on .ng". Positioned AFTER the keyword/extension checks
    // so `reasons` is already populated when we read it.
    final foreignTlds = _byType[UrlScamRuleType.foreignTld] ?? _emptyBucket;
    UrlScamRule? matchedForeignTld;
    for (final r in foreignTlds) {
      if (lowerUrl.endsWith(r.pattern) ||
          lowerUrl.contains('${r.pattern}/') ||
          lowerUrl.contains('${r.pattern}?') ||
          lowerUrl.contains('${r.pattern}#')) {
        matchedForeignTld = r;
        break;
      }
    }
    if (matchedForeignTld != null && reasons.isNotEmpty) {
      score += matchedForeignTld.score;
      reasons.add(_loc.tr('urlReason.foreignTld'));
      categories.add('Suspicious Domain');
    }

    // URL shorteners. Substring match against the lower-cased URL.
    final shorteners = _byType[UrlScamRuleType.shortener] ?? _emptyBucket;
    UrlScamRule? matchedShortener;
    for (final r in shorteners) {
      if (lowerUrl.contains(r.pattern)) {
        matchedShortener = r;
        break;
      }
    }
    if (matchedShortener != null) {
      score += matchedShortener.score;
      reasons.add(_loc.tr('urlReason.shortener'));
      categories.add('Shortened URL');
    }

    // Excessive subdomains
    final domain = _extractDomain(url);

    if (domain != null) {
      final dotCount = '.'.allMatches(domain).length;

      if (dotCount >= 3) {
        score += 15;

        reasons.add(_loc.tr('urlReason.manySubdomains'));

        categories.add('Suspicious Domain');
      }
    }

    // Suspicious characters
    if (url.contains('@')) {
      score += 25;

      reasons.add(_loc.tr('urlReason.atSymbol'));

      categories.add('Suspicious URL');
    }

    // Double slash after domain
    if (url.contains('//', 8)) {
      score += 10;

      reasons.add(_loc.tr('urlReason.unusualStructure'));

      categories.add('Suspicious URL');
    }

    // Brand impersonation patterns. Each entry from
    // [defaultUrlScamRules] / Firestore `url_scam_rules`.
    final brands = _byType[UrlScamRuleType.brand] ?? _emptyBucket;
    final brandMatched = <String>[];
    int brandMatchedScore = 0;
    for (final r in brands) {
      if (lowerUrl.contains(r.pattern)) {
        brandMatched.add(r.pattern);
        brandMatchedScore += r.score;
      }
    }

    if (brandMatched.isNotEmpty) {
      score += brandMatchedScore;
      reasons.add(_loc.tr('urlReason.brandName'));
      categories.add('Possible Impersonation');
    }

    // Suspicious combinations
    if (matchedKeywords.isNotEmpty &&
        brandMatched.isNotEmpty) {
      score += 15;

      reasons.add(_loc.tr('urlReason.brandPlusPhishing'));

      categories.add('Possible Impersonation');
    }

    if (matchedShortener != null &&
        matchedKeywords.isNotEmpty) {
      score += 15;

      reasons.add(_loc.tr('urlReason.shortenerPlusPhishing'));

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

  /// Find the score the admin/Firestore assigned to a rule whose
  /// pattern equals [matchedPattern]. Falls back to [defaultScore]
  /// when no rule has that pattern — defensive against a future where
  /// an admin deletes a doc but the bundled defaults still ship it.
  static int _scoreFor(
    List<UrlScamRule> bucket,
    String matchedPattern, {
    required int defaultScore,
  }) {
    for (final r in bucket) {
      if (r.pattern == matchedPattern) return r.score;
    }
    return defaultScore;
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
      // Strong-score boost: critical-tier URLs (≥80) with at least one
      // other reason reach the 0.80 AI gate without calling Gemini.
      // Single-signal criticals also clear the gate on score alone.
      confidence += 0.20;
    }

    return confidence.clamp(0.0, 0.99);
  }

  String _getCategory(List<String> categories) {
    if (categories.contains('Phishing')) {
      return _loc.tr('category.phishing');
    }

    if (categories.contains('Possible Impersonation')) {
      return _loc.tr('category.impersonation');
    }

    if (categories.contains('Suspicious Domain')) {
      return _loc.tr('category.suspiciousDomain');
    }

    if (categories.contains('Shortened URL')) {
      return _loc.tr('category.shortenedLink');
    }

    if (categories.isEmpty) {
      return _loc.tr('category.general');
    }

    return categories.first;
  }

  List<String> _getRecommendations(
    UrlRiskLevel level,
  ) {
    switch (level) {
      case UrlRiskLevel.critical:
        return [
          _loc.tr('rec.critical.url.1'),
          _loc.tr('rec.critical.url.2'),
          _loc.tr('rec.critical.url.3'),
          _loc.tr('rec.critical.url.4'),
        ];

      case UrlRiskLevel.high:
        return [
          _loc.tr('rec.high.url.1'),
          _loc.tr('rec.high.url.2'),
          _loc.tr('rec.high.url.3'),
        ];

      case UrlRiskLevel.medium:
        return [
          _loc.tr('rec.medium.url.1'),
          _loc.tr('rec.medium.url.2'),
          _loc.tr('rec.medium.url.3'),
        ];

      case UrlRiskLevel.low:
        return [
          _loc.tr('rec.low.url.1'),
          _loc.tr('rec.low.url.2'),
        ];

      case UrlRiskLevel.safe:
        return [
          _loc.tr('rec.safe.url.1'),
          _loc.tr('rec.safe.url.2'),
        ];
    }
  }
}