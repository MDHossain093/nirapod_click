import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/locale/localizer.dart';
import '../../core/theme/app_theme.dart';
import '../../models/risk_result.dart';
import '../../services/checker_repository.dart';
import '../../services/free_quota_service.dart';
import '../../services/hybrid_analyzer.dart';
import '../../services/subscription_service.dart';
import '../history/risk_result_page.dart';
import '../../widgets/ai_unavailable_banner.dart';
import '../../widgets/quota_exhausted_dialog.dart';
import '../../widgets/risk_disclaimer.dart';

/// Message Checker screen.
///
/// The user pastes a suspicious SMS / WhatsApp / email into the text box,
/// we run it through [HybridAnalyzer.analyze], and render the result
/// inline. We also persist the check to Firestore so it shows up in the
/// History tab.
///
/// Layout (post-redesign):
///   - Hero strip (24-px heading + 14-px subheading) — matches the URL /
///     phone / screenshot checker siblings.
///   - White input card (radiusXxl + borderSubtle) wrapping the TextField.
///   - 52-px brand gradient CTA — slightly taller than the URL checker
///     CTA (48-px) because message checks are the primary user action.
///   - Inline verdict card on result — full-bleed white + radiusXxl +
///     risk-color @ 0.25 border + 72×72 icon disc + 22-px verdict title +
///     30-px score + category + confidence + source badge + "Why?" +
///     "What should you do?" sections, mirroring `url_checker_screen.dart`.
///   - Tap on the verdict card opens `RiskResultPage` for the full report.
///   - Safety notice always shown below the verdict card.
class MessageCheckerScreen extends StatefulWidget {
  const MessageCheckerScreen({super.key, this.initialValue});

  /// Optional text to pre-fill the input field with on first build.
  ///
  /// Used by the QR checker screen to drop the decoded payload into
  /// the text field after the user scans a non-URL / non-phone QR.
  /// The user can edit or clear before tapping "Check", so a
  /// pre-fill never auto-runs the analyzer — it just spares the user
  /// a paste.
  final String? initialValue;

  @override
  State<MessageCheckerScreen> createState() => _MessageCheckerScreenState();
}

class _MessageCheckerScreenState extends State<MessageCheckerScreen> {
  late final TextEditingController _ctrl;
  final _analyzer = HybridAnalyzer();
  bool _busy = false;
  RiskResult? _result;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    // Capture both scope services synchronously (before any awaits)
    // so we don't trip the `use_build_context_synchronously` lint
    // when calling `QuotaExhaustedSheet.show(context)` after the
    // per-kind gate await.
    final quota = FreeQuotaScope.of(context);
    final subscription = SubscriptionScope.of(context);

    // Free-tier gate: free users get 5 checks per month. Premium
    // users always pass through. The consume() call is awaited even
    // on failure so the in-memory counter stays in sync — the
    // Firestore history write happens after the result comes back so
    // we don't waste quota on a result we're about to throw away.
    final allowed = await quota.consume();
    if (!allowed) {
      if (!mounted) return;
      await QuotaExhaustedSheet.show(context);
      return;
    }

    // Per-kind gate: the Profile card's "X message scans left"
    // counter. Independent of the monthly 5 — a free user can run
    // 5 message scans in a month, but if they only use messages
    // we'll refuse the 6th even if the monthly quota is fine. We
    // check BEFORE running the analyzer so an exhausted budget
    // doesn't burn a Gemini call.
    final kindAllowed =
        await subscription.recordScan(ScanType.message);
    if (!kindAllowed) {
      if (!mounted) return;
      await QuotaExhaustedSheet.show(context);
      return;
    }

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

  String _tr(String key) => AppLocaleScope.of(context).tr(key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_tr('messageChecker.title')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero strip — heading + subheading. Matches the
              // URL / phone / screenshot checker siblings so the four
              // checkers read as a coherent family.
              Text(
                _tr('messageChecker.heading'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _tr('messageChecker.subheading'),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Input card — white surface + radiusXxl + borderSubtle
              // wrapping the TextField. Matches the visual vocabulary
              // of the home header + URL / phone / screenshot inputs.
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
                  border: Border.all(color: AppTheme.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _ctrl,
                    maxLines: 5,
                    minLines: 4,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: _tr('messageChecker.hint'),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 4, right: 8),
                        child: Icon(Icons.message_outlined),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // CTA — 52-px gradient button (taller than the URL
              // checker's 48-px CTA because message checks are the
              // app's primary user action; height signals
              // importance). Same brand gradient + primary@0.30
              // shadow as the Go Premium / Profile upsell buttons.
              _PrimaryCta(
                onTap: _busy ? null : _analyze,
                busy: _busy,
                label: _tr('messageChecker.analyze'),
              ),
              const SizedBox(height: 24),

              if (_result != null) _buildResult(context, _result!),
              const SizedBox(height: 24),
              _buildSafetyNotice(),
            ],
          ),
        ),
      ),
    );
  }

  /// Full-bleed verdict card. Mirrors `url_checker_screen.dart`'s
  /// inline result structure: white surface + radiusXxl + risk-color
  /// @ 0.25 border, 72×72 icon disc, 22-px title, 30-px score,
  /// category, confidence line, source badge (AI-assisted vs Local
  /// rules only), "Why?" reasons list, and "What should you do?"
  /// recommendations list. Tap on the card opens the full
  /// [RiskResultPage] (which holds the copy-report + disclaimer).
  Widget _buildResult(BuildContext context, RiskResult result) {
    final style = RiskStyle.of(result.level);

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
      onTap: _openDetail,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(
            color: style.color.withValues(alpha: AppTheme.tintBorder),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.aiWasUnavailable) ...[
              AiUnavailableBanner(text: _tr('result.aiUnavailable')),
              const SizedBox(height: 16),
            ],
            Center(
              child: Column(
                children: [
                  Container(
                    width: AppTheme.tileIconXl,
                    height: AppTheme.tileIconXl,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: AppTheme.tintSurface),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      style.icon,
                      color: style.color,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    result.level.localizedBadge,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: style.color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocaleScope.of(context).formatScore(result.score),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.category,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tr('messageChecker.confidenceLabel').replaceAll(
                      '{value}',
                      AppLocaleScope.of(context)
                          .formatNumber((result.confidence * 100).round()),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Provenance badge so the user can tell whether the
                  // verdict came from local rules or from Gemini.
                  _buildSourceBadge(result.usedAi),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // "Why?" — risk signals.
            Text(
              _tr('messageChecker.why'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (result.reasons.isEmpty)
              Text(
                _tr('messageChecker.noWarnings'),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                ),
              ),
            ...result.reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: style.color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reason,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // "What should you do?" — recommendations.
            Text(
              _tr('messageChecker.recommendations'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...result.recommendations.map(
              (recommendation) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 20,
                      color: AppTheme.secondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tap-for-details affordance so the user knows the whole
            // card opens the full report page.
            Row(
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _tr('messageChecker.tapForDetails'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Secondary "check another message" action so the user
            // can clear the verdict without leaving the screen.
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _result = null);
                      _ctrl.clear();
                    },
              icon: const Icon(Icons.refresh),
              label: Text(_tr('messageChecker.checkAnother')),
            ),

            const SizedBox(height: 12),
            RiskDisclaimer(text: _tr('result.disclaimer')),
          ],
        ),
      ),
    );
  }

  /// Provenance badge — tells the user whether the verdict came from
  /// local rules or from Gemini AI.
  Widget _buildSourceBadge(bool usedAi) {
    final key =
        usedAi ? 'messageChecker.aiAssisted' : 'messageChecker.localOnly';
    final color = usedAi ? AppTheme.primary : AppTheme.textSecondary;
    final icon = usedAi
        ? Icons.auto_awesome_rounded
        : Icons.bolt_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.tintSurface),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            _tr(key),
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Empty-state safety notice shown below the verdict card (and below
  /// the CTA when no result is on screen yet). Always-on reminder of
  /// the OTP/PIN safety rule. Mirrors the URL checker safety notice.
  Widget _buildSafetyNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(
          alpha: AppTheme.tintSurface,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _tr('messageChecker.safetyNotice'),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Brand-gradient CTA button used by the message checker.
///
/// 52-px tall (slightly taller than the URL checker's 48-px CTA so
/// the primary user action has visual weight). Same brand gradient
/// + primary@0.30 shadow pattern as the Go Premium + Profile upsell
/// buttons. Renders a spinner when [busy] is `true`.
class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.onTap,
    required this.busy,
    required this.label,
  });

  final VoidCallback? onTap;
  final bool busy;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        // Brand header gradient token — same `primary → secondary`
        // as the AppBar + Go Premium + Profile upsell CTAs.
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: AppTheme.tintBorderStrong),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: onTap,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// "Copy report" helper used by [RiskResultPage] - kept here so the result
/// screen stays free of formatting code.
class ReportClipboard {
  /// Builds a plain-text summary of [result] suitable for pasting into
  /// chat apps or email. Replaces the old `ReportFormatter.full(...)`.
  ///
  /// Resolves every label through the context-free [Localizer] so the
  /// report is rendered in the user's active locale (English or Bangla)
  /// regardless of which screen invoked it.
  static String full(RiskResult result) {
    final loc = Localizer.instance;
    final buffer = StringBuffer()
      ..writeln(loc.tr('clipboard.title'))
      ..writeln('${loc.tr('clipboard.level')}: '
          '${result.level.name.toUpperCase()}')
      ..writeln('${loc.tr('clipboard.score')}: '
          '${loc.formatScore(result.score)}')
      ..writeln('${loc.tr('clipboard.category')}: ${result.category}')
      ..writeln(
        '${loc.tr('clipboard.confidence')}: '
        '${loc.formatPercent(result.confidence)}',
      );

    if (result.reasons.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('${loc.tr('clipboard.signals')}:');
      for (final r in result.reasons) {
        buffer.writeln(' - $r');
      }
    }

    if (result.recommendations.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('${loc.tr('clipboard.recommendations')}:');
      for (final r in result.recommendations) {
        buffer.writeln(' - $r');
      }
    }

    return buffer.toString();
  }
}
