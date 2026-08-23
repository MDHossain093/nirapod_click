import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/subscription.dart';
import '../../services/subscription_service.dart';

/// Marketing screen for NirapodClick Premium.
///
/// For now this is **frontend only** — the Subscribe button calls
/// [SubscriptionService.subscribe], which simulates the bdapps
/// round-trip with a short delay. Once the bdapps docs land we
/// swap the simulated delay for a real platform-channel call.
///
/// State machine (see [SubscriptionService]):
///   free / expired → tap Subscribe → subscribing (spinner)
///   subscribing    → success → active (button hides, CTA copy flips)
///   subscribing    → failure → free + lastError (Try Again banner)
///   active         → no-op on Subscribe (button is hidden)
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  // Six benefits, fixed order — matches the brief sketch.
  static const List<String> _benefitKeys = [
    'subscription.benefit.unlimitedMessages',
    'subscription.benefit.unlimitedUrls',
    'subscription.benefit.moreScreenshots',
    'subscription.benefit.advancedAi',
    'subscription.benefit.detailedReports',
    'subscription.benefit.priorityUpdates',
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(t('subscription.appBarTitle'))),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final service = SubscriptionScope.of(context);
            return AnimatedBuilder(
              animation: service,
              builder: (context, _) {
                final state = service.state;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(title: t('subscription.title')),
                      const SizedBox(height: 16),
                      Text(
                        t('subscription.tagline'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _BenefitsCard(keys: _benefitKeys),
                      const SizedBox(height: 20),
                      Text(
                        t('subscription.priceLine'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SubscribeButton(service: service, state: state, tr: t),
                      if (state.lastError != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(
                          title: t('subscription.errorTitle'),
                          detail: state.lastError!,
                          retryLabel: t('subscription.tryAgain'),
                          onRetry: () {
                            service.clearError();
                            service.subscribe();
                          },
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        t('subscription.fineprint'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- hero

class _Hero extends StatelessWidget {
  const _Hero({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.shield_rounded,
            size: 44,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- benefits

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard({required this.keys});
  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('subscription.benefitsHeader'),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          ...keys.map((k) => _BenefitRow(text: t(k))),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppTheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- CTA

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({
    required this.service,
    required this.state,
    required this.tr,
  });

  final SubscriptionService service;
  final SubscriptionState state;
  final String Function(String) tr;

  @override
  Widget build(BuildContext context) {
    final status = state.status;

    final isSubscribing = status == SubscriptionStatus.subscribing;
    final isActive = status == SubscriptionStatus.active;

    final label = isSubscribing
        ? tr('subscription.subscribing')
        : tr('subscription.subscribeCta');

    // Active users don't see the button — they're already in.
    if (isActive) {
      return _ActiveBadge(label: tr('subscription.card.premiumStatus'));
    }

    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isSubscribing ? null : () => service.subscribe(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppTheme.primary.withValues(alpha: 0.55),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isSubscribing
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.verified_rounded,
            color: AppTheme.secondary,
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- error

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.title,
    required this.detail,
    required this.retryLabel,
    required this.onRetry,
  });

  final String title;
  final String detail;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: AppTheme.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ),
        ],
      ),
    );
  }
}
