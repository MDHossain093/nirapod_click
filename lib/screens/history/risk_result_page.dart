import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale/app_locale.dart';
import '../../core/locale/localizer.dart';
import '../../core/theme/app_theme.dart';
import '../../models/risk_result.dart';
import '../message_checker/message_checker_screen.dart';
import '../../widgets/ai_unavailable_banner.dart';
import '../../widgets/risk_disclaimer.dart';

/// Full-detail page for a single [RiskResult].
///
/// Reached either from the Message Checker inline card or from the
/// History / Alerts list. Shows the verdict, category, confidence,
/// reasons, and level-keyed safety recommendations.
///
/// `originalText` is the raw input that produced [result]. It's
/// optional because the inline message-checker flow already has the
/// text on screen — there it's redundant. The history and alerts
/// entry points pass it in so users can review what they scanned
/// without going back to the source app.
///
/// Static labels (category / confidence / safety tips / app-bar /
/// buttons) come from `AppLocaleScope.of(context).tr(...)` — that's
/// the widget-tree-aware path. The verdict headline uses
/// [Localizer.instance.tr] because it depends only on the active
/// locale, not on any visible ancestor.
class RiskResultPage extends StatelessWidget {
  const RiskResultPage({
    super.key,
    required this.result,
    this.originalText,
  });
  final RiskResult result;

  /// The raw input that produced [result]. `null` means "don't render
  /// the original-text panel" (e.g. the inline message-checker flow
  /// where the text is already on the previous screen).
  final String? originalText;

  /// Headline shown under the level chip. Resolved via the context-free
  /// [Localizer] singleton so the page doesn't have to thread the locale
  /// down through every helper.
  String _headline(RiskLevel level) {
    final loc = Localizer.instance;
    switch (level) {
      case RiskLevel.safe:
        return loc.tr('level.safe');
      case RiskLevel.low:
        return loc.tr('level.low');
      case RiskLevel.medium:
        return loc.tr('level.medium');
      case RiskLevel.high:
        return loc.tr('level.high');
      case RiskLevel.critical:
        return loc.tr('level.critical');
    }
  }

  /// Localized badge label (SAFE / LOW RISK / etc). `RiskStyle.badge`
  /// is hardcoded English today; overriding it here lets the chip
  /// render in Bangla while every other consumer of [RiskStyle.badge]
  /// keeps working unchanged.
  String _localizedBadge(RiskLevel level) {
    final loc = Localizer.instance;
    switch (level) {
      case RiskLevel.safe:
        return loc.tr('badge.safe');
      case RiskLevel.low:
        return loc.tr('badge.low');
      case RiskLevel.medium:
        return loc.tr('badge.medium');
      case RiskLevel.high:
        return loc.tr('badge.high');
      case RiskLevel.critical:
        return loc.tr('badge.critical');
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = RiskStyle.of(result.level);
    final level = result.level;
    final locale = AppLocaleScope.of(context);
    final t = locale.tr;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('result.label.appBarTitle')),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (result.aiWasUnavailable) ...[
                AiUnavailableBanner(text: t('result.aiUnavailable')),
                const SizedBox(height: 16),
              ],

              // Verdict hero.
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      style.color,
                      style.color.withValues(alpha: 0.78),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(style.icon, size: 44, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _localizedBadge(level),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _headline(level),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.speed,
                              size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              t('result.label.score').replaceAll(
                                '{score}',
                                locale.formatNumber(result.score),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Category + confidence row.
              Row(
                children: [
                  Expanded(
                    child: _metaCard(
                      icon: Icons.category_outlined,
                      label: t('result.label.category'),
                      value: result.category,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metaCard(
                      icon: Icons.verified_outlined,
                      label: t('result.label.confidence'),
                      value: locale.formatPercent(result.confidence),
                    ),
                  ),
                ],
              ),
              if (result.usedAi) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: AppTheme.tintSurface),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                    border: Border.all(
                      color: AppTheme.secondary.withValues(alpha: AppTheme.tintSurface + 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t('result.label.aiBadge'),
                        style: const TextStyle(
                          color: AppTheme.secondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Original input (only when the caller passed it in).
              // Renders above the reasons so the user can re-read what
              // they scanned before reading the verdict's explanation.
              if (originalText != null && originalText!.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.subject_rounded,
                      color: AppTheme.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t('result.originalHeader'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Text(
                    originalText!,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Reasons.
              if (result.reasons.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.flag_outlined, color: style.color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      t('result.label.whatWeFound').replaceAll(
                        '{count}',
                        locale.formatNumber(result.reasons.length),
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...result.reasons.map(
                  (r) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.fiber_manual_record,
                            size: 8, color: style.color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            r,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.riskLow.withValues(alpha: AppTheme.tintSubtle),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border:
                        Border.all(color: AppTheme.riskLow.withValues(alpha: AppTheme.tintBorder)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined,
                          color: AppTheme.riskLow, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t('result.label.noSignals'),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 18),

              // Recommendations.
              if (result.recommendations.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: AppTheme.tintSurface),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border:
                        Border.all(color: AppTheme.accent.withValues(alpha: AppTheme.tintBorder)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tips_and_updates_outlined,
                              color: AppTheme.accent),
                          const SizedBox(width: 8),
                          Text(
                            t('result.label.safetyTips'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...result.recommendations.map(
                        (tip) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '\u2022 ',
                                style: TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  tip,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(t('result.label.back')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: ReportClipboard.full(result)),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t('result.label.copied')),
                            backgroundColor: AppTheme.secondary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: Text(t('result.label.copy')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              RiskDisclaimer(text: t('result.disclaimer')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.secondary),
              const SizedBox(width: 6),
              // Localized labels (especially Bangla) can grow longer
              // than the icon + 6px gap leaves room for — without an
              // Expanded + ellipsis here the row overflows by N pixels.
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}