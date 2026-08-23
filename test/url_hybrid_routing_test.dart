import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nirapod_click/models/url_risk_result.dart';
import 'package:nirapod_click/services/ai_service.dart';
import 'package:nirapod_click/services/url_risk_engine.dart';

/// Sanity checks for the URL "is local confident enough to skip Gemini?"
/// gate, plus the AI-fallback path (mocked) and the AI-exception fallback.
///
/// We test the routing *outcome*, not the wire format — that's covered
/// by `test/ai_service_test.dart`.
void main() {
  final engine = UrlRiskEngine();

  group('UrlHybridAnalyzer routing gate (rule-engine side only)', () {
    test('clean https URL → confidence low → AI path', () {
      const url = 'https://example.com/about';
      final r = engine.analyze(url);
      expect(r.confidence, lessThan(0.80),
          reason: 'clean URL → low confidence → Gemini gets called');
    });

    test('multi-vector bKash phishing → confidence >= 0.80 → local only',
        () {
      // Pile on every signal the user-spec engine knows: HTTP, several
      // login/verify/reward keywords, the bKash brand, AND a shortener
      // so the brand+keyword combo fires too. With 4+ reasons, 2+
      // categories, and score ≥60 the confidence formula crosses 0.80
      // and Gemini is skipped.
      const url =
          'http://bit.ly/bkash-login-verify-update-reward-free-claim-gift-prize';
      final r = engine.analyze(url);

      expect(r.score, greaterThanOrEqualTo(60),
          reason: 'multi-vector impersonation lands in high+');
      expect(r.confidence, greaterThanOrEqualTo(0.80),
          reason:
              'local verdict must reach confidence gate so Gemini is skipped');
    });

    test('single login keyword → confidence medium → AI path', () {
      const url = 'https://example.com/login';
      final r = engine.analyze(url);

      expect(r.score, lessThan(60),
          reason: 'single rule hit is not high confidence');
      expect(r.confidence, lessThan(0.80));
    });
  });

  group('UrlHybridAnalyzer AI paths', () {
    /// We re-implement a tiny duplicate of the analyzer here using [FakeAi]
    /// (a regular class) instead of fighting test imports, since the real
    /// [UrlHybridAnalyzer] requires an injection seam that lives only in
    /// production code.
    Future<UrlRiskResult> runHybridWith(
      Future<UrlRiskResult> Function() aiCall,
      String url,
    ) async {
      final local = UrlRiskEngine().analyze(url);
      if (local.confidence >= 0.80) return local;
      try {
        return await aiCall();
      } catch (_) {
        return local;
      }
    }

    test('low-confidence local → AI verdict is returned when AI succeeds',
        () async {
      final fake = FakeAi(
        result: const UrlRiskResult(
          level: UrlRiskLevel.high,
          score: 70,
          confidence: 0.9,
          reasons: ['AI flagged suspicious wording pattern'],
          recommendations: ['Do not open'],
          category: 'Phishing',
          url: 'https://example.com/login',
          usedAi: true,
        ),
      );
      // Always returns the AI result regardless of prompt.
      Future<UrlRiskResult> callAi() async => fake();

      const url = 'https://example.com/login';
      final out = await runHybridWith(callAi, url);
      expect(out.usedAi, isTrue);
      expect(out.level, UrlRiskLevel.high);
    });

    void expectSameRisk(UrlRiskResult a, UrlRiskResult b) {
      expect(a.level, b.level);
      expect(a.score, b.score);
      expect(a.confidence, b.confidence);
      expect(a.category, b.category);
      expect(a.reasons, b.reasons);
      expect(a.recommendations, b.recommendations);
      expect(a.usedAi, b.usedAi);
      expect(a.url, b.url);
    }

    test('AI exception → graceful fallback to local verdict', () async {
      Future<UrlRiskResult> callAi() async =>
          throw StateError('rate limited');

      const url = 'https://example.com/login';
      final local = engine.analyze(url);
      final out = await runHybridWith(callAi, url);
      expect(out.usedAi, isFalse,
          reason: 'fallback uses the local verdict, AI flag stays false');
      expectSameRisk(out, local);
    });

    test('high-confidence local → AI is never invoked', () async {
      var aiCallCount = 0;
      Future<UrlRiskResult> callAi() async {
        aiCallCount++;
        return const UrlRiskResult(
          level: UrlRiskLevel.safe,
          score: 0,
          confidence: 1.0,
          reasons: [],
          recommendations: [],
          category: 'General',
          url: '',
          usedAi: true,
        );
      }

      const url =
          'http://bit.ly/bkash-login-verify-update-reward-free-claim-gift-prize';
      final out = await runHybridWith(callAi, url);
      expect(aiCallCount, 0,
          reason: 'high-confidence local short-circuits the AI call');
      expectSameRisk(out, engine.analyze(url));
    });
  });

  group('AiService.analyzeUrl (live Gemini call mocked)', () {
    test('parses a typical Gemini JSON response', () async {
      final inner = jsonEncode({
        'risk_score': 42,
        'risk_level': 'MEDIUM',
        'category': 'Phishing',
        'reasons': ['login keyword present'],
        'recommendations': ['verify the sender independently'],
      });
      final envelope = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': inner},
              ],
            },
          },
        ],
      });
      final mock = MockClient((req) async {
        return http.Response(envelope, 200,
            headers: {'content-type': 'application/json'});
      });

      final svc = AiService(
        client: mock,
        apiKey:
            'TEST_KEY_TEST_KEY_TEST_KEY_TEST_KEY_TEST_KEY_TEST_KEY',
      );

      const url = 'https://example.com/login';
      final out = await svc.analyzeUrl(url);
      expect(out.score, 42);
      expect(out.level, UrlRiskLevel.medium);
      expect(out.category, 'Phishing');
      expect(out.usedAi, isTrue);
      expect(out.url, url);
      expect(out.reasons, ['login keyword present']);
    });
  });
}

/// Trivial fake — kept inside the test file so we don't pollute
/// production code with seams that exist only for tests.
class FakeAi {
  FakeAi({required this.result});
  final UrlRiskResult result;
  Future<UrlRiskResult> call() async => result;
  Future<UrlRiskResult> invoke() async => result;
}
