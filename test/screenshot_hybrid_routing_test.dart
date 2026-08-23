import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nirapod_click/models/risk_result.dart';
import 'package:nirapod_click/services/ai_service.dart';
import 'package:nirapod_click/services/screenshot_analyzer.dart';
import 'package:nirapod_click/services/screenshot_hybrid_analyzer.dart';

/// Routing + AI-fallback sanity checks for the Screenshot Scanner.
///
/// Mirrors `test/url_hybrid_routing_test.dart` shape:
///   * The routing gate's rule-engine side (low vs high confidence)
///   * The AI success / AI exception / AI-never-invoked paths
///   * A mocked HTTP round-trip for `AiService.analyzeScreenshot`
///
/// We test the *routing outcome* rather than the wire format — the
/// latter is covered by `test/ai_service_test.dart`.
void main() {
  final localEngine = ScreenshotAnalyzer();

  group('ScreenshotHybridAnalyzer routing gate (rule-engine side only)', () {
    test('clean chat OCR → message confidence low → AI path', () {
      const text = 'Hi, are we still on for lunch tomorrow at noon?';
      final r = localEngine.analyze(text);

      expect(r.messageResult.confidence, lessThan(0.80),
          reason: 'plain chat produces a low-confidence local verdict, '
              'so Gemini should be asked');
      expect(r.urlResults, isEmpty);
    });

    test('multi-vector scam (OTP + payment + prize) → confidence ≥ 0.80 '
        '→ local only', () {
      const text = 'Congratulations! You won 50,000 taka. To claim your '
          'prize please send 500 taka processing fee to bKash 01712345678 '
          'and share the OTP 4521 we just sent you. Act now, offer ends '
          'in 10 minutes!';

      final r = localEngine.analyze(text);

      expect(r.messageResult.score, greaterThanOrEqualTo(80));
      expect(r.messageResult.confidence, greaterThanOrEqualTo(0.80),
          reason: 'multi-vector + combos must hit the gate so Gemini '
              'is skipped');
      expect(r.messageResult.usedAi, isFalse);
    });

    test('embedded phishing link → URL score raises the verdict, gate '
        'still depends on message confidence', () {
      const text = 'Your Nagad account will be suspended. Verify now: '
          'http://bit.ly/nagad-verify-bd';

      final r = localEngine.analyze(text);

      expect(r.urlResults, isNotEmpty);
      expect(
        r.score,
        greaterThanOrEqualTo(r.messageResult.score),
        reason: 'the URL side should bump the combined score',
      );
    });
  });

  group('ScreenshotHybridAnalyzer AI paths', () {
    /// Same test-local duplicate as the URL hybrid test — keeps
    /// production code free of seams that exist only for tests.
    Future<ScreenshotAnalysis> runHybridWith(
      Future<ScreenshotAnalysis> Function() aiCall,
      String text,
    ) async {
      final local = ScreenshotAnalyzer().analyze(text);
      if (local.messageResult.confidence >= 0.80) return local;
      try {
        return await aiCall();
      } catch (_) {
        return local;
      }
    }

    test('low-confidence local → AI verdict returned when AI succeeds',
        () async {
      final ai = ScreenshotAnalysis(
        messageResult: const RiskResult(
          level: RiskLevel.high,
          score: 72,
          confidence: 0.9,
          reasons: ['AI flagged multi-vector scam pattern'],
          recommendations: ['Do not engage'],
          category: 'Credential Theft',
          usedAi: true,
        ),
        urlResults: const [],
        score: 72,
        category: 'Credential Theft',
        reasons: ['AI flagged multi-vector scam pattern'],
        recommendations: ['Do not engage'],
      );
      Future<ScreenshotAnalysis> callAi() async => ai;

      const text = 'Hi, are we still on for lunch tomorrow at noon?';
      final out = await runHybridWith(callAi, text);

      expect(out.messageResult.usedAi, isTrue);
      expect(out.score, 72);
    });

    test('AI exception → graceful fallback to local verdict', () async {
      Future<ScreenshotAnalysis> callAi() async =>
          throw StateError('rate limited');

      const text = 'Hi, are we still on for lunch tomorrow at noon?';
      final local = localEngine.analyze(text);
      final out = await runHybridWith(callAi, text);

      expect(out.messageResult.usedAi, isFalse,
          reason: 'fallback uses the local verdict; AI flag stays false');
      expect(out.score, local.score);
      expect(out.category, local.category);
      expect(out.reasons, local.reasons);
    });

    test('high-confidence local → AI is never invoked', () async {
      var aiCallCount = 0;
      Future<ScreenshotAnalysis> callAi() async {
        aiCallCount++;
        return ScreenshotAnalysis(
          messageResult: const RiskResult(
            level: RiskLevel.safe,
            score: 0,
            confidence: 1.0,
            reasons: [],
            recommendations: [],
            category: 'General',
            usedAi: true,
          ),
          urlResults: const [],
          score: 0,
          category: 'General',
          reasons: const [],
          recommendations: const [],
        );
      }

      const text = 'Congratulations! You won 50,000 taka. To claim your '
          'prize please send 500 taka processing fee to bKash 01712345678 '
          'and share the OTP 4521 we just sent you. Act now, offer ends '
          'in 10 minutes!';

      final out = await runHybridWith(callAi, text);

      expect(aiCallCount, 0,
          reason: 'high-confidence local short-circuits the AI call');
      expect(out.messageResult.usedAi, isFalse);
    });
  });

  group('ScreenshotHybridAnalyzer (real hybrid analyzer) AI fallback', () {
    test('ScreenshotHybridAnalyzer injects a fake AiService that throws '
        '→ returns the local verdict', () async {
      final throwingAi = _ThrowingAiService();
      final hybrid = ScreenshotHybridAnalyzer(aiService: throwingAi);

      const text = 'Hi, are we still on for lunch tomorrow at noon?';

      final out = await hybrid.analyze(text);

      expect(throwingAi.callCount, 1,
          reason: 'low confidence should have routed to the AI');
      expect(out.messageResult.usedAi, isFalse,
          reason: 'on AI failure, the local verdict is returned with '
              'usedAi = false');
    });
  });

  group('AiService.analyzeScreenshot (live Gemini call mocked)', () {
    test('parses a typical Gemini screenshot envelope', () async {
      final inner = jsonEncode({
        'risk_score': 88,
        'risk_level': 'HIGH',
        'category': 'Credential Theft',
        'reasons': ['requests OTP', 'creates urgency'],
        'recommendations': ["don't send OTP", 'verify officially'],
        'urls': [
          {
            'url': 'http://bit.ly/nagad-verify-bd',
            'risk_score': 65,
            'risk_level': 'HIGH',
            'category': 'Phishing',
            'reasons': ['impersonates Nagad', 'shortened link'],
            'recommendations': ['open the official Nagad app instead'],
          },
        ],
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

      final out = await svc.analyzeScreenshot('any ocr text');

      expect(out.score, 88);
      expect(out.category, 'Credential Theft');
      expect(out.messageResult.usedAi, isTrue);
      expect(out.urlResults, hasLength(1));
      expect(out.urlResults.first.url, 'http://bit.ly/nagad-verify-bd');
      expect(out.urlResults.first.usedAi, isTrue);
      expect(
        out.reasons.any((r) => r.startsWith('Link:')),
        isTrue,
        reason: 'URL reasons should be surfaced in the combined '
            'reasons list with a "Link: " prefix',
      );
    });

    test('empty urls array → no urlResults, no Link: prefix', () async {
      final inner = jsonEncode({
        'risk_score': 5,
        'risk_level': 'SAFE',
        'category': 'General',
        'reasons': <String>[],
        'recommendations': <String>[],
        'urls': <Map<String, dynamic>>[],
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

      final out = await svc.analyzeScreenshot('clean text');

      expect(out.urlResults, isEmpty);
      expect(
        out.reasons.any((r) => r.startsWith('Link:')),
        isFalse,
      );
    });
  });
}

class _ThrowingAiService implements AiService {
  int callCount = 0;

  @override
  Future<ScreenshotAnalysis> analyzeScreenshot(String text) async {
    callCount++;
    throw StateError('rate limited');
  }

  // Unused members of the AiService contract — the analyzer under test
  // only ever calls `analyzeScreenshot`. Throw on any accidental call
  // so a regression doesn't silently bypass the fallback path.
  @override
  noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_ThrowingAiService has no implementation for ${invocation.memberName}',
    );
  }
}
