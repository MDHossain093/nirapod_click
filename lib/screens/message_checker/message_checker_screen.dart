import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/risk_result.dart';
import '../../services/checker_repository.dart';
import '../../services/risk_engine.dart';
import '../history/risk_result_page.dart';

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
  final _engine = RiskEngine();
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
      final result = _engine.analyzeMessage(text);
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
                      'Paste the SMS, WhatsApp, or email below.',
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
                  decoration: const InputDecoration(
                    hintText:
                        'e.g. Your bKash account will be suspended. Send 5000 BDT to 017xx... to verify.',
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
                  label: const Text('Analyze'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _openDetail,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: style.color.withValues(alpha: 0.35)),
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
                      'Score ${result.score}/100',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Category: ${result.category}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${(result.confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    Icon(Icons.touch_app_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('Tap for full details'),
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
          label: const Text('Check another'),
        ),
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
