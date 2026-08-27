import 'package:flutter/foundation.dart';

import '../models/url_risk_result.dart';
import 'ai_service.dart';
import 'url_risk_engine.dart';
import 'url_scam_rule_service.dart';

/// Local-first, AI-fallback analyzer for URLs.
///
/// Behaviour mirrors [HybridAnalyzer] (used for messages):
///   1. Run the local [UrlRiskEngine] on the input.
///   2. If the local verdict carries high confidence (≥ 0.80), return it.
///   3. Otherwise call [AiService.analyzeUrl] and return the AI result.
///   4. On any AI exception, fall back to the local verdict silently.
///
/// `AiService` is injected so unit tests can swap a fake. The engine
/// is cheap (pure-Dart) and we construct it **lazily inside each
/// analyzeUrl() call** so a rule-bundle reload from
/// [UrlScamRuleService] takes effect on the very next scan without an
/// app restart.
class UrlHybridAnalyzer {
  UrlHybridAnalyzer({AiService? aiService})
      : _aiService = aiService ?? AiService();

  final AiService _aiService;

  Future<UrlRiskResult> analyzeUrl(String url) async {
    // Resolve the rule bundle lazily on every analyze call so that
    // hot-restart and code-push scenarios where [UrlScamRuleService]
    // is re-seeded mid-session still pick up the latest bundle. The
    // getter is O(1) (cache hit after first load).
    final local = UrlRiskEngine(
      rules: UrlScamRuleService.instance.rules,
    ).analyze(url);

    if (local.confidence >= 0.80) {
      debugPrint(
        '[Hybrid-URL] Local verdict kept (confidence '
        '${(local.confidence * 100).toStringAsFixed(0)}%).',
      );
      return local;
    }

    debugPrint(
      '[Hybrid-URL] Local confidence '
      '${(local.confidence * 100).toStringAsFixed(0)}% < 80% '
      '— calling Gemini.',
    );

    try {
      final ai = await _aiService.analyzeUrl(url);
      debugPrint(
        '[Hybrid-URL] Gemini returned '
        '${ai.level.name} (${ai.score}/100).',
      );
      return ai;
    } catch (e, st) {
      debugPrint(
        '[Hybrid-URL] Gemini call failed, returning local fallback: $e',
      );
      debugPrintStack(stackTrace: st, maxFrames: 4);
      // Re-package the local verdict so the UI can show a
      // "AI analysis unavailable" banner alongside the result.
      return UrlRiskResult(
        level: local.level,
        score: local.score,
        confidence: local.confidence,
        category: local.category,
        url: local.url,
        reasons: local.reasons,
        recommendations: local.recommendations,
        usedAi: false,
        aiWasUnavailable: true,
      );
    }
  }
}