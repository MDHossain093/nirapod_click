import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/risk_result.dart';
import '../../services/checker_repository.dart';
import '../../services/hybrid_analyzer.dart';
import '../history/risk_result_page.dart';
import '../../widgets/ai_unavailable_banner.dart';
import '../../widgets/risk_disclaimer.dart';

/// Message Checker screen.
///
/// The user pastes a suspicious SMS / WhatsApp / email into the text box,
/// we run it through [RiskEngine.analyzeMessage], and render the result
/// inline. We also persist the check to Firestore so it shows up in the
/// History tab.
class MessageCheckerScreen extends StatefulWidget {
  const MessageCheckerScreen({super.key});

  @override
  State<MessageCheckerScreen> createState() => _MessageCheckerScreenState();
}

class _MessageCheckerScreenState extends State<MessageCheckerScreen> {
  final _ctrl = TextEditingController();
  final _analyzer = HybridAnalyzer();
  bool _busy = false;
  RiskResult? _result;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _busy = true;
      _result = null;
    });

    try {
      final result = await _analyzer.analyze(text);
      setState(() => _result = result);

      // Best-effort persist. A history-write hiccup should never block the
      // user from seeing their result.
      try {
        await CheckerRepository().save(result, text);
      } catch (_) {
        // ignored
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openDetail() {
    final result = _result;
    if (result == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RiskResultPage(result: result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('messageChecker.title')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.brandHeaderGradient),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.message_outlined,
                        color: AppTheme.secondary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('messageChecker.wording'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: t('messageChecker.hint'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_result != null)
                _buildResult(_result!)
              else
                ElevatedButton.icon(
                  onPressed: _busy ? null : _analyze,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.white,
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                  label: Text(t('messageChecker.analyze')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Inline result card. Tapping it opens the full [RiskResultPage].
  ///
  /// Shows category + confidence in addition to the score + verdict the
  /// previous prototype rendered.
  Widget _buildResult(RiskResult result) {
    final style = RiskStyle.of(result.level);
    final t = AppLocaleScope.of(context).tr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.aiWasUnavailable) ...[
          AiUnavailableBanner(text: t('result.aiUnavailable')),
          const SizedBox(height: 12),
        ],
        InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          onTap: _openDetail,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: AppTheme.tintSurface),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: style.color.withValues(alpha: AppTheme.tintBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(style.icon, color: style.color, size: 26),
                    const SizedBox(width: 8),
                    Text(
                      style.badge,
                      style: TextStyle(
                        color: style.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      t('messageChecker.scoreLabel').replaceAll(
                        '{score}',
                        result.score.toString(),
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  t('messageChecker.categoryLabel').replaceAll(
                    '{category}',
                    result.category,
                  ),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t('messageChecker.confidenceLabel').replaceAll(
                    '{value}',
                    (result.confidence * 100).toStringAsFixed(0),
                  ),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (result.usedAi) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t('messageChecker.aiBadge'),
                      style: const TextStyle(
                        color: AppTheme.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.touch_app_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(t('messageChecker.tapForDetails')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () {
                  setState(() => _result = null);
                  _ctrl.clear();
                },
          icon: const Icon(Icons.refresh),
          label: Text(t('messageChecker.checkAnother')),
        ),
        const SizedBox(height: 12),
        RiskDisclaimer(text: t('result.disclaimer')),
      ],
    );
  }
}

/// "Copy report" helper used by [RiskResultPage] - kept here so the result
/// screen stays free of formatting code.
class ReportClipboard {
  /// Builds a plain-text summary of [result] suitable for pasting into
  /// chat apps or email. Replaces the old `ReportFormatter.full(...)`.
  static String full(RiskResult result) {
    final buffer = StringBuffer()
      ..writeln('NirapodClick Risk Report')
      ..writeln('Level: ${result.level.name.toUpperCase()}')
      ..writeln('Score: ${result.score}/100')
      ..writeln('Category: ${result.category}')
      ..writeln(
        'Confidence: ${(result.confidence * 100).toStringAsFixed(0)}%',
      );

    if (result.reasons.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Signals:');
      for (final r in result.reasons) {
        buffer.writeln(' - $r');
      }
    }

    if (result.recommendations.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Recommendations:');
      for (final r in result.recommendations) {
        buffer.writeln(' - $r');
      }
    }

    return buffer.toString();
  }
}
