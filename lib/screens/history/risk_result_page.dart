import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/risk_result.dart';
import '../message_checker/message_checker_screen.dart';
import '../../widgets/ai_unavailable_banner.dart';
import '../../widgets/risk_disclaimer.dart';

/// Full-detail page for a single [RiskResult].
///
/// Reached either from the Message Checker inline card or from the
/// History list. Shows the verdict, category, confidence, reasons, and
/// level-keyed safety recommendations.
class RiskResultPage extends StatelessWidget {
  const RiskResultPage({super.key, required this.result});
  final RiskResult result;

  String _headline(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return 'Looks safe';
      case RiskLevel.low:
        return 'Be cautious';
      case RiskLevel.medium:
        return 'Potentially suspicious';
      case RiskLevel.high:
        return 'High risk';
      case RiskLevel.critical:
        return 'Critical warning';
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = RiskStyle.of(result.level);
    final level = result.level;
    final t = AppLocaleScope.of(context).tr;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        flexibleSpace: Container(
          decoration:
              const BoxDecoration(gradient: AppTheme.brandHeaderGradient),
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
                  borderRadius: BorderRadius.circular(20),
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
                      style.badge,
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
                          Text(
                            'Risk score: ${result.score} / 100',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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
                      label: 'Category',
                      value: result.category,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metaCard(
                      icon: Icons.verified_outlined,
                      label: 'Confidence',
                      value:
                          '${(result.confidence * 100).toStringAsFixed(0)}%',
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\u2728 AI Analysis',
                        style: TextStyle(
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

              // Reasons.
              if (result.reasons.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.flag_outlined, color: style.color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'What we found (${result.reasons.length})',
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
                  child: const Row(
                    children: [
                      Icon(Icons.verified_outlined,
                          color: AppTheme.riskLow, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No scam signals were detected. Stay alert - always verify '
                          'unexpected payment or login requests.',
                          style: TextStyle(
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
                      const Row(
                        children: [
                          Icon(Icons.tips_and_updates_outlined,
                              color: AppTheme.accent),
                          SizedBox(width: 8),
                          Text(
                            'Safety tips',
                            style: TextStyle(
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
                                    height: 1.35,
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
                      label: const Text('Back'),
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
                            content: const Text('Report copied to clipboard'),
                            backgroundColor: AppTheme.secondary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: const Text('Copy report'),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5EAF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.secondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
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
