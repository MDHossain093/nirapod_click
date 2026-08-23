import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/subscription.dart';
import '../../services/subscription_service.dart';
import 'premium_screen.dart';

/// Two-state card shown at the top of Profile.
///
///   • Active premium: shield + price + next renewal + Manage button
///   • Free:           shield + remaining scans        + Go Premium button
///
/// Rebuilds via [AnimatedBuilder] on the [SubscriptionService] so the
/// free ↔ active transition is live.
class SubscriptionStatusCard extends StatelessWidget {
  const SubscriptionStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SubscriptionScope.of(context);
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        return _CardBody(service: service);
      },
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({required this.service});

  final SubscriptionService service;

  @override
  Widget build(BuildContext context) {
    final state = service.state;
    return state.isPremium
        ? _ActiveCard(state: state, service: service)
        : _FreeCard(state: state);
  }
}

// --------------------------------------------------------------- ACTIVE

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.state, required this.service});

  final SubscriptionState state;
  final SubscriptionService service;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.secondary.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: AppTheme.secondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t('subscription.card.premiumTitle'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StatusRow(label: t('subscription.card.premiumStatus')),
          const SizedBox(height: 6),
          _StatusRow(label: t('subscription.card.premiumPrice')),
          const SizedBox(height: 6),
          _StatusRow(
            label: state.nextRenewalAt == null
                ? t('subscription.card.nextRenewalPending')
                : t('subscription.card.nextRenewal').replaceAll(
                    '{date}',
                    _formatDate(state.nextRenewalAt!),
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showManageSheet(context, service),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(
                  color: AppTheme.primary.withValues(alpha: 0.30),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                t('subscription.card.manageCta'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManageSheet(BuildContext context, SubscriptionService service) {
    final t = AppLocaleScope.of(context).tr;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t('subscription.card.manageCta'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  t('subscription.card.premiumPrice'),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      await service.cancel();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: const BorderSide(color: AppTheme.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      t('subscription.fineprint'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

// --------------------------------------------------------------- FREE

class _FreeCard extends StatelessWidget {
  const _FreeCard({required this.state});

  final SubscriptionState state;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;

    final shots = PlanLimits.format(state.limits.screenshotScansRemaining);
    final msgs = PlanLimits.format(state.limits.messageScansRemaining);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t('subscription.card.freeTitle'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _StatusRow(
            label: t('subscription.card.freeScreenshots')
                .replaceAll('{count}', shots),
          ),
          const SizedBox(height: 6),
          _StatusRow(
            label: t('subscription.card.freeMessages')
                .replaceAll('{count}', msgs),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PremiumScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                t('subscription.card.goPremiumCta'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- row

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppTheme.secondary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
