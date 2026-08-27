import '../models/risk_result.dart';
import 'ai_service.dart';
import 'risk_engine.dart';
import 'scam_rule_service.dart';

class HybridAnalyzer {
  HybridAnalyzer({AiService? aiService})
      : _aiService = aiService ?? AiService();

  final AiService _aiService;

  Future<RiskResult> analyze(String message) async {
    // Resolve the rule bundle lazily on every analyze call so that
    // hot-restart and code-push scenarios where [ScamRuleService] is
    // re-seeded mid-session still pick up the latest bundle.
    // The getter is O(1) (cache hit after first load).
    final ruleResult = RiskEngine(
      rules: ScamRuleService.instance.rules,
    ).analyzeMessage(message);

    // Clear result → don't use Gemini
    if (ruleResult.confidence >= 0.80) {
      // ignore: avoid_print
      print(
        '[Hybrid] Local verdict kept (confidence '
        '${(ruleResult.confidence * 100).toStringAsFixed(0)}%).',
      );
      return ruleResult;
    }

    // Ambiguous result → use Gemini
    // ignore: avoid_print
    print(
      '[Hybrid] Local confidence '
      '${(ruleResult.confidence * 100).toStringAsFixed(0)}% '
      '< 80% → calling Gemini.',
    );
    try {
      final aiResult = await _aiService.analyzeMessage(
        message,
      );
      // ignore: avoid_print
      print(
        '[Hybrid] Gemini returned '
        '${aiResult.level.name} (${aiResult.score}/100).',
      );
      return aiResult;
    } catch (e) {
      // ignore: avoid_print
      print(
        '[Hybrid] Gemini failed ($e) → falling back to local.',
      );
      // Re-package the local verdict so the UI can show a
      // "AI analysis unavailable" banner alongside the result.
      return RiskResult(
        level: ruleResult.level,
        score: ruleResult.score,
        confidence: ruleResult.confidence,
        reasons: ruleResult.reasons,
        recommendations: ruleResult.recommendations,
        category: ruleResult.category,
        usedAi: false,
        aiWasUnavailable: true,
      );
    }
  }
}