import 'package:flutter/foundation.dart';

import 'ai_service.dart';
import 'screenshot_analyzer.dart';

/// Local-first, AI-fallback analyzer for screenshot OCR text.
///
/// Behaviour mirrors [UrlHybridAnalyzer] (used for plain URLs):
///   1. Run the local [ScreenshotAnalyzer] (message engine + URL engine
///      blended with the `0.65 / 0.35` weights) on the input.
///   2. If the local verdict carries high confidence (≥ 0.80), return it
///      with `usedAi = false` so the UI shows the "local-only" badge.
///   3. Otherwise call [AiService.analyzeScreenshot] and return the
///      AI result with `usedAi = true`.
///   4. On any AI exception, fall back to the local verdict silently.
///
/// `AiService` is injected so unit tests can swap a fake. The local
/// pipeline is pure-Dart so we construct it eagerly.
class ScreenshotHybridAnalyzer {
  ScreenshotHybridAnalyzer({AiService? aiService})
      : _aiService = aiService ?? AiService();

  final AiService _aiService;
  final ScreenshotAnalyzer _local = ScreenshotAnalyzer();

  Future<ScreenshotAnalysis> analyze(String text) async {
    final local = _local.analyze(text);

    if (local.messageResult.confidence >= 0.80) {
      debugPrint(
        '[Hybrid-Screenshot] Local verdict kept (confidence '
        '${(local.messageResult.confidence * 100).toStringAsFixed(0)}%).',
      );
      return local;
    }

    debugPrint(
      '[Hybrid-Screenshot] Local confidence '
      '${(local.messageResult.confidence * 100).toStringAsFixed(0)}% — '
      'asking Gemini for a second opinion.',
    );

    try {
      final ai = await _aiService.analyzeScreenshot(text);
      return ai;
    } catch (e, st) {
      debugPrint(
        '[Hybrid-Screenshot] Gemini call failed, returning local '
        'fallback: $e',
      );
      debugPrintStack(stackTrace: st, maxFrames: 4);
      // Re-package the local verdict so the UI can show a
      // "AI analysis unavailable" banner alongside the result.
      return ScreenshotAnalysis(
        messageResult: local.messageResult,
        urlResults: local.urlResults,
        score: local.score,
        category: local.category,
        reasons: local.reasons,
        recommendations: local.recommendations,
        aiWasUnavailable: true,
      );
    }
  }
}
