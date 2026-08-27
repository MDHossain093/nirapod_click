import 'package:flutter/material.dart';

import '../core/locale/app_locale.dart';
import '../core/theme/app_theme.dart';
import '../screens/subscription/premium_screen.dart';
import '../services/free_quota_service.dart';

/// Shared UI for "you've used up your free checks" moments.
///
/// Used by every scanner when [FreeQuotaService.canConsume] returns
/// false. Shows a bottom sheet with:
///   - the "Free check limit reached" headline
///   - the "you've used all 5 free checks this month" body
///   - a CTA that pushes [PremiumScreen]
///   - a dismissable Close action
///
/// Centralising this keeps the four scanners focused on their own
/// flow and guarantees the upgrade messaging is identical everywhere.
/// If the copy or layout changes, one edit propagates to all four.
class QuotaExhaustedSheet {
  /// Convenience entry point — looks up [FreeQuotaScope] for the
  /// caller and shows the standard sheet. Returns the `Future` that
  /// resolves when the user dismisses.
  static Future<void> show(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final quota = FreeQuotaScope.of(context);

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        // Re-resolve t inside the sheet context so the locale lookup
        // uses the sheet's tree (defensive — sheet shares the locale
        // scope with the page, but if a future refactor wraps the
        // sheet in a fresh locale, this stays correct).
        final sheetT = AppLocaleScope.of(sheetContext).tr;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusHero),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: AnimatedBuilder(
              animation: quota,
              builder: (context, _) {
                final total = quota.monthlyBudget;
                final used = quota.used;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag handle. Visual affordance only — the sheet
                    // itself isn't draggable, so this is a hint that
                    // matches the platform pattern.
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.borderSubtle,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Headline + icon row. The icon is the same ⓘ
                    // shape used elsewhere on warning surfaces to keep
                    // the visual language consistent.
                    Row(
                      children: [
                        Container(
                          width: AppTheme.tileIconSm,
                          height: AppTheme.tileIconSm,
                          decoration: BoxDecoration(
                            color: AppTheme.warning
                                .withValues(alpha: AppTheme.tintSurface),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: const Icon(
                            Icons.lock_clock_rounded,
                            color: AppTheme.warning,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            sheetT('quota.exhaustedTitle'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      // Body interpolates {total} so the sheet stays
                      // accurate if the budget is ever changed.
                      sheetT('quota.exhaustedBody')
                          .replaceAll('{total}', total.toString()),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // "Used X / 5 — Resets on <date>" recap. Pulls
                    // through the locale-aware digit formatter so
                    // Bangla users see ১/৫.
                    _UsageSummary(
                      used: used,
                      total: total,
                      resetsOn: quota.resetsOn,
                      usedLabel: t('quota.spent'),
                      resetsOnKey: 'quota.resetsOn',
                    ),
                    const SizedBox(height: 18),
                    // CTA — full-width brand gradient so the
                    // upgrade option reads as the primary action.
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: AppTheme.headerGradient,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppTheme.primary.withValues(alpha: 0.30),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PremiumScreen(),
                              ),
                            );
                          },
                          child: Center(
                            child: Text(
                              sheetT('quota.upgradeCta'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(t('common.cancel')),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _UsageSummary extends StatelessWidget {
  const _UsageSummary({
    required this.used,
    required this.total,
    required this.resetsOn,
    required this.usedLabel,
    required this.resetsOnKey,
  });

  final int used;
  final int total;
  final DateTime resetsOn;
  final String usedLabel;
  final String resetsOnKey;

  String _formatDate(BuildContext context) {
    final locale = AppLocaleScope.of(context).locale;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    // Render month name in English by default; for Bangla we keep
    // the numerals localised and fall back to the English month
    // short-name. A dedicated Bangla calendar formatter is overkill
    // for a single date string.
    final formatted = '${months[resetsOn.month - 1]} ${resetsOn.day}';
    return locale == AppLocale.bangla
        ? formatted
            .replaceAll('0', '০')
            .replaceAll('1', '১')
            .replaceAll('2', '২')
            .replaceAll('3', '৩')
            .replaceAll('4', '৪')
            .replaceAll('5', '৫')
            .replaceAll('6', '৬')
            .replaceAll('7', '৭')
            .replaceAll('8', '৮')
            .replaceAll('9', '৯')
        : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final fmtNum = AppLocaleScope.of(context).formatNumber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: AppTheme.tintSurface),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.warning.withValues(alpha: AppTheme.tintBorder),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$usedLabel ${fmtNum(used)} / ${fmtNum(total)}'
              '  ·  ${t(resetsOnKey).replaceAll('{date}', _formatDate(context))}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
