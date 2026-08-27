import 'package:flutter_test/flutter_test.dart';
import 'package:nirapod_click/models/url_risk_result.dart';
import 'package:nirapod_click/services/url_risk_engine.dart';

void main() {
  final engine = UrlRiskEngine();

  group('UrlRiskEngine.analyze', () {
    test('clean https URL is safe', () {
      const url = 'https://www.google.com/search?q=flutter';
      final r = engine.analyze(url);

      expect(r.score, lessThan(15),
          reason: 'clean https URL should not score above safe tier');
      expect(r.level, anyOf(UrlRiskLevel.safe, UrlRiskLevel.low));
      expect(r.usedAi, isFalse);
      expect(r.url, url);
    });

    test('http-only URL adds an insecure-transport signal', () {
      const url = 'http://example.com/article';
      final r = engine.analyze(url);

      expect(
        r.reasons,
        contains('The website does not use HTTPS.'),
        reason: 'the insecure-scheme rule should fire on plain http',
      );
      expect(r.score, greaterThanOrEqualTo(10));
    });

    test('IP-literal host is treated as suspicious', () {
      const url = 'http://192.168.0.1/login';
      final r = engine.analyze(url);

      expect(
        r.reasons,
        contains(
          'The link uses an IP address instead of a normal domain.',
        ),
      );
      expect(r.score, greaterThanOrEqualTo(20));
      expect(r.category, anyOf('Suspicious URL', 'Phishing'));
    });

    test('URL shortener hides the destination', () {
      const url = 'https://bit.ly/3xQ7Z';
      final r = engine.analyze(url);

      expect(
        r.reasons,
        contains('Uses a URL shortening service.'),
      );
      expect(r.level, isNot(UrlRiskLevel.critical),
          reason: 'a shortener alone should not be critical');
    });

    test('bKash impersonation + login keyword + http is medium+', () {
      const url =
          'http://login-verify-bkash-example.com/account/update';
      final r = engine.analyze(url);

      expect(r.score, greaterThanOrEqualTo(35),
          reason: 'multi-vector impersonation should land in medium+');
      expect(r.level,
          anyOf(UrlRiskLevel.medium, UrlRiskLevel.high, UrlRiskLevel.critical));
      expect(
        r.reasons
            .where((s) => s.toLowerCase().contains('brand'))
            .toList(),
        isNotEmpty,
        reason: 'a brand-mention reason should appear',
      );
    });

    test('excessive subdomains trigger a structure signal', () {
      const url = 'https://login.verify.update.secure.example.com/';
      final r = engine.analyze(url);

      expect(
        r.reasons
            .where((s) => s.toLowerCase().contains('subdomain'))
            .toList(),
        isNotEmpty,
        reason: 'deep subdomain chains should be flagged',
      );
    });

    test('suspicious-length URL is flagged', () {
      final url = 'https://example.com/${'abcde' * 20}';
      final r = engine.analyze(url);

      expect(
        r.reasons,
        contains('The URL is unusually long.'),
      );
    });

    test('@-symbol in URL is flagged as suspicious', () {
      const url = 'https://safe-bank.com@evil.example.tk/login';
      final r = engine.analyze(url);

      expect(
        r.reasons,
        contains(
          'Contains an @ symbol that can hide the actual destination.',
        ),
      );
      expect(r.score, greaterThanOrEqualTo(20));
    });

    test('single keyword hit alone is "potentially suspicious" (<high)', () {
      const url = 'https://example.com/login';
      final r = engine.analyze(url);

      expect(r.score, lessThan(60),
          reason: 'a single keyword hit must not be high/critical');
      expect(r.level,
          anyOf(UrlRiskLevel.safe, UrlRiskLevel.low, UrlRiskLevel.medium));
    });

    test('score is clamped to the 0..100 range', () {
      const url =
          'http://bkash-secure-login-verify-update.example.tk/x.apk'
          '?reward=claim&free=gift&prize=bonus';
      final r = engine.analyze(url);

      expect(r.score, greaterThanOrEqualTo(0));
      expect(r.score, lessThanOrEqualTo(100));
    });

    test('confidence reflects number of independent signals', () {
      const cleanUrl = 'https://example.com';
      const dirtyUrl =
          'http://192.168.0.1/login?verify=true&reward=free&id=apk';

      final clean = engine.analyze(cleanUrl);
      final dirty = engine.analyze(dirtyUrl);

      expect(dirty.confidence, greaterThan(clean.confidence),
          reason: 'more signals should bump confidence');
    });

    test('empty URL returns a helpful Invalid card', () {
      final r = engine.analyze('');
      expect(r.level, UrlRiskLevel.safe);
      expect(r.category, 'Invalid');
      expect(r.reasons, contains('No URL was provided.'));
      expect(r.url, '');
    });

    test('suspicious TLD (.tk) is flagged as a known abuse zone', () {
      const url = 'https://verify-login.bkash-account.tk/update';
      final r = engine.analyze(url);

      expect(
        r.reasons,
        contains(
          matches(RegExp(r'frequently-abused top-level domain.*\.tk')),
        ),
        reason: '.tk must surface as a suspicious-TLD signal',
      );
      expect(r.category, anyOf('Suspicious Domain', 'Phishing', 'Impersonation'));
    });

    test('dangerous file extension (.apk) is flagged', () {
      const url = 'http://bkash-reward.example.top/BkashUpdate.apk';
      final r = engine.analyze(url);

      expect(
        r.reasons,
        contains(
          matches(RegExp(r'downloadable executable file.*\.apk')),
        ),
        reason: '.apk in the path must trip the dangerous-extension rule',
      );
      expect(r.score, greaterThanOrEqualTo(20));
    });
  });

  // ─── Newly added list coverage ─────────────────────────────────────
  //
  // Guards the BD rule-engine strengthening change. Each test exercises
  // ONE of the four extended hardcoded lists in `url_risk_engine.dart`
  // so a future refactor cannot silently drop the new entries.

  group('newly added URL list coverage', () {
    test('dangerous extension .pdf is flagged', () {
      const url = 'http://bkash-claim.example.top/invoice.pdf';
      final r = engine.analyze(url);

      expect(
        r.reasons,
        contains(
          matches(RegExp(r'downloadable executable file.*\.pdf')),
        ),
        reason: '.pdf must trip the dangerous-extension rule',
      );
      expect(r.score, greaterThanOrEqualTo(20));
    });

    test('dangerous extension .doc is flagged', () {
      const url = 'http://verify-account.example.top/KYC_Form.doc';
      final r = engine.analyze(url);

      expect(
        r.reasons,
        contains(
          matches(RegExp(r'downloadable executable file.*\.doc')),
        ),
        reason: '.doc must trip the dangerous-extension rule (macro vector)',
      );
    });

    test('suspicious TLD .work is flagged', () {
      const url = 'https://easy-money-claim.example.work/login';
      final r = engine.analyze(url);

      expect(
        r.reasons,
        contains(
          matches(RegExp(r'frequently-abused top-level domain.*\.work')),
        ),
        reason: '.work must surface as a suspicious-TLD signal',
      );
      expect(r.score, greaterThanOrEqualTo(15));
    });

    test('suspicious TLD .loan is flagged', () {
      const url = 'https://quick-loan.example.loan/apply';
      final r = engine.analyze(url);

      expect(
        r.reasons,
        contains(
          matches(RegExp(r'frequently-abused top-level domain.*\.loan')),
        ),
        reason: '.loan must surface as a suspicious-TLD signal',
      );
    });

    test('Bangla phishing keyword লগইন is flagged', () {
      const url = 'https://example.com/লগইন';
      final r = engine.analyze(url);

      expect(
        r.reasons
            .where((s) =>
                s.toLowerCase().contains('phishing-related') ||
                s.toLowerCase().contains('sensitive'))
            .toList(),
        isNotEmpty,
        reason: 'Bangla login keyword must trip the phishing-keyword rule',
      );
      expect(r.score, greaterThanOrEqualTo(15));
    });

    test('BD bank IBL brand impersonation is flagged', () {
      const url = 'http://verify-account.example.tk/ibl-login';
      final r = engine.analyze(url);

      expect(
        r.reasons
            .where((s) => s.toLowerCase().contains('brand'))
            .toList(),
        isNotEmpty,
        reason: 'ibl bank name should trip the brand-impersonation rule',
      );
    });

    test('BD bank EBL brand impersonation is flagged', () {
      const url = 'http://secure-update.example.tk/ebl-verify';
      final r = engine.analyze(url);

      expect(
        r.reasons
            .where((s) => s.toLowerCase().contains('brand'))
            .toList(),
        isNotEmpty,
        reason: 'ebl bank name should trip the brand-impersonation rule',
      );
    });

    test('foreign scam TLD (.ng) soft penalty fires only with another signal',
        () {
      // Bare .ng alone must NOT fire the offshore penalty (legitimate
      // diaspora use case). Pair it with a phishing keyword so the
      // soft-penalty clause activates.
      const legitNg = 'https://example.ng';
      const dirtyNg = 'https://example.ng/login';

      final legit = engine.analyze(legitNg);
      final dirty = engine.analyze(dirtyNg);

      expect(
        legit.reasons.any((s) => s.toLowerCase().contains('offshore')),
        isFalse,
        reason: 'plain .ng alone must not trip the offshore penalty',
      );
      expect(
        dirty.reasons.any((s) => s.toLowerCase().contains('offshore')),
        isTrue,
        reason: '.ng + phishing keyword must trip the offshore penalty',
      );
    });
  });

  // ─── Confidence gate ───────────────────────────────────────────────
  //
  // Mirrors the message-engine gate: a single high-impact signal at
  // score ≥ 80 (critical tier) with at least one reason must clear
  // the 0.80 AI gate so obvious scam URLs resolve locally.

  group('confidence gate', () {
    test('critical-tier URL clears the AI gate (confidence >= 0.80)', () {
      // Stack enough signals to push the score into the critical band:
      //   - http://          (+10  Security)
      //   - .tk TLD          (+15  Suspicious Domain)
      //   - .apk extension   (+20  Suspicious URL)
      //   - login keyword    (+15  Phishing)
      //   - bkash brand      (+10  Impersonation)
      //   - phishing+brand   (+15  Impersonation combo)
      //   = 85 → critical
      const url =
          'http://bkash-login-verify.example.tk/account.apk?reward=claim';
      final r = engine.analyze(url);

      expect(r.level, UrlRiskLevel.critical);
      expect(r.score, greaterThanOrEqualTo(80));
      expect(
        r.confidence,
        greaterThanOrEqualTo(0.80),
        reason: 'critical-tier URL must clear the 0.80 AI gate locally',
      );
    });

    test('single low-signal URL stays below the AI gate', () {
      // A clean https URL with only a single keyword hit must NOT
      // auto-pass — should keep going to AI for confirmation.
      const url = 'https://example.com/login';
      final r = engine.analyze(url);

      if (r.score < 80) {
        expect(
          r.confidence,
          lessThan(0.80),
          reason: 'single-signal URL must NOT auto-pass the AI gate',
        );
      }
    });
  });
}
