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
      appBar: AppBar(
        title: Text(t('subscription.appBarTitle')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
          ),
        ),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final service = SubscriptionScope.of(context);
            return AnimatedBuilder(
              animation: service,
              builder: (context, _) {
                final state = service.state;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(title: t('subscription.title')),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 16),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Real brand logo (same asset used by the splash) at the top
        // of the Premium screen, so the upsell reads as an intentional
        // brand moment instead of a tinted shield disc.
        //
        // Sized as a square (160×160) with `BoxFit.contain` so the
        // wordmark + Bangla tagline keep their natural proportions
        // regardless of the asset's actual aspect ratio — the previous
        // 200×180 box stretched wide logos horizontally and left a
        // visible gap before the title.
        SizedBox(
          width: 300,
          height: 200,
          child: Image.asset(
            'assets/logo_full.png',
            fit: BoxFit.contain,
            // Fallback to a shield mark if the asset isn't bundled on
            // a desktop flavor. Keeps the screen usable in every build.
            errorBuilder: (_, error, stack) {
              // ignore: avoid_print
              print('[PremiumScreen] logo asset missing: $error');
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: AppTheme.tintSurface),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  size: 56,
                  color: AppTheme.primary,
                ),
              );
            },
          ),
        ),
        
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
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
              letterSpacing: 0.8,
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
                height: 1.4,
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

    return Container(
      height: 52,
      decoration: BoxDecoration(
        // Brand header gradient token — same `primary → secondary` as the
        // AppBar, Go Premium banner, Profile upsell, and check tile
        // CTAs. Using the token keeps a future brand refresh in sync.
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
          onTap: isSubscribing ? null : () => service.subscribe(),
          child: Center(
            child: isSubscribing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
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
        color: AppTheme.secondary.withValues(alpha: AppTheme.tintPanelSoft),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
        // Use the danger-tinted surface token instead of an ad-hoc
        // hex; same role as [AiUnavailableBanner] (amber tint on
        // amberBannerBackground) — keeps "destructive/AI-fallback
        // banner" surface treatments on one scale.
        color: AppTheme.danger.withValues(alpha: AppTheme.tintSurface),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.danger.withValues(alpha: AppTheme.tintBorderStrong)),
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
