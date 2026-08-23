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
}
