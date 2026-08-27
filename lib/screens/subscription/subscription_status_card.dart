import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/subscription.dart';
import '../../services/subscription_service.dart';
import 'premium_screen.dart';

/// Profile-screen subscription summary card.
///
/// Two visual states, both rendered as **white cards** with a
/// coloured "hero strip" at the top and `radiusXxl` corners — matching
/// the `_ProfileHeader` and result-card vocabulary used everywhere
/// else in the app. The free ↔ active swap is driven through an
/// [AnimatedSwitcher] so the transition reads as an intentional state
/// change, not a hard rebuild.
///
///   • **Free** — top hero strip is a brand-gradient with a
///     `workspace_premium` icon disc + "NirapodClick Free" + plan
///     subtitle. Body is a "What you get" feature row with three
///     check-marked highlights. Bottom CTA is a full-width
///     gradient "Go Premium" button.
///
///   • **Active** — top hero strip is the green `riskLow` family
///     with a `workspace_premium` icon disc + "NirapodClick
///     Premium" + an "Active" status pill. Body is a 2-up info
///     tile strip (price / next renewal) and a benefits list.
///     Bottom CTA is a ghost "Manage Subscription" outline button.
///
/// Per-kind remaining counts live on Home, so the Free card stays a
/// clean upsell with no quota tiles.
class SubscriptionStatusCard extends StatelessWidget {
  const SubscriptionStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final service = SubscriptionScope.of(context);
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        final state = service.state;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(state.status),
            child: state.isPremium
                ? _ActiveCard(state: state, service: service)
                : _FreeCard(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────── ACTIVE

/// Premium (active) state — white card with a green hero strip +
/// Active pill + 2-up info tiles + benefits list + ghost manage CTA.
class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.state, required this.service});

  final SubscriptionState state;
  final SubscriptionService service;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    // Green family — same `riskLow` token used by safe verdicts so
    // "active premium" reads as the same positive, all-clear signal.
    final accent = AppTheme.riskLow;
    return _SurfaceCard(
      hero: _HeroStrip(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.92),
            AppTheme.riskLow,
          ],
        ),
        iconBgAlpha: 0.22,
        icon: Icons.workspace_premium_rounded,
        title: t('subscription.card.premiumTitle'),
        trailing: _StatusPill(
          label: t('subscription.card.premiumStatus'),
          background: Colors.white,
          foreground: accent,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.payments_rounded,
                  iconColor: AppTheme.primary,
                  label: t('subscription.card.premiumPriceLabel'),
                  value: t('subscription.card.premiumPrice'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoTile(
                  icon: Icons.event_repeat_rounded,
                  iconColor: AppTheme.secondary,
                  label: t('subscription.card.nextRenewalLabel'),
                  value: state.nextRenewalAt == null
                      ? t('subscription.card.nextRenewalPending')
                      : t('subscription.card.nextRenewal').replaceAll(
                          '{date}',
                          _formatDate(state.nextRenewalAt!),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _BenefitsRow(keys: const [
            'subscription.benefit.unlimitedMessages',
            'subscription.benefit.advancedAi',
            'subscription.benefit.detailedReports',
          ]),
        ],
      ),
      cta: _GhostButton(
        label: t('subscription.card.manageCta'),
        icon: Icons.tune_rounded,
        onPressed: () => _showManageSheet(context, service),
      ),
    );
  }

  void _showManageSheet(BuildContext context, SubscriptionService service) {
    final t = AppLocaleScope.of(context).tr;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusHero),
        ),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

// ───────────────────────────────────────────────────────────────────── FREE

/// Free state — white card with brand-gradient hero strip + premium
/// disc + a "What you get" feature preview + a full-width gradient
/// "Go Premium" CTA.
class _FreeCard extends StatelessWidget {
  const _FreeCard();

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return _SurfaceCard(
      hero: _HeroStrip(
        gradient: AppTheme.headerGradient,
        iconBgAlpha: 0.22,
        icon: Icons.workspace_premium_rounded,
        title: t('subscription.card.freeTitle'),
        subtitle: t('subscription.card.freeSubtitle'),
      ),
      body: _BenefitsRow(keys: const [
        'subscription.benefit.unlimitedMessages',
        'subscription.benefit.advancedAi',
        'subscription.benefit.moreScreenshots',
      ]),
      cta: _PrimaryCta(
        label: t('subscription.card.goPremiumCta'),
        icon: Icons.arrow_forward_rounded,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PremiumScreen(),
            ),
          );
        },
      ),
    );
  }
}

// ───────────────────────────────────────────────────────── SHARED PIECES

/// White rounded surface card used by both states. Wraps a [hero]
/// gradient strip on top of a [body] content slot + a [cta] at the
/// bottom — same shape as `_ProfileHeader` so the two top-of-screen
/// cards on Profile read as siblings.
class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.hero,
    required this.body,
    required this.cta,
  });

  final Widget hero;
  final Widget body;
  final Widget cta;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          hero,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: body,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: cta,
          ),
        ],
      ),
    );
  }
}

/// Top section of [_SurfaceCard] — full-width gradient strip that
/// hosts the icon disc, the title, and (optionally) a subtitle and
/// a trailing slot used for the active card's status pill.
class _HeroStrip extends StatelessWidget {
  const _HeroStrip({
    required this.gradient,
    required this.iconBgAlpha,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final Gradient gradient;
  final double iconBgAlpha;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradient),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: iconBgAlpha),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Pill shown on the active hero — small, white-background,
/// coloured text. Renders the localised "Active" status word in
/// the same rounded-capsule vocabulary as the scan-type chips on
/// the history page.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Muted info tile used by the active card's body — 40×40 coloured
/// icon disc on the left + label + value stack on the right. White
/// surface + `borderSubtle` so it doesn't fight the green hero
/// strip above for attention.
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: AppTheme.tintSurface),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact 3-row "what you get" preview / reminder. Each row pairs
/// a tinted check-disc with the localised benefit text — same
/// vocabulary as the Premium screen's `_BenefitRow` so the upsell
/// language is consistent across screens.
class _BenefitsRow extends StatelessWidget {
  const _BenefitsRow({required this.keys});

  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final accent = AppTheme.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: AppTheme.tintPanel),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: accent.withValues(alpha: AppTheme.tintBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < keys.length; i++) ...[
            _BenefitLine(label: t(keys[i])),
            if (i < keys.length - 1) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _BenefitLine extends StatelessWidget {
  const _BenefitLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.success;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: AppTheme.tintSurface),
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.check_rounded,
            color: accent,
            size: 14,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width brand-gradient CTA used at the bottom of the Free
/// card. Same `Container + Material + InkWell + gradient + radiusXs
/// + 48 px` pattern as the URL checker Check CTA and the message
/// checker Analyze CTA — so the "primary action" on a card reads
/// the same across the app.
class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusXs),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary CTA used for the Active card's "Manage
/// Subscription" button. Same radius / height as [_PrimaryCta] so
/// the two states align visually.
class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          side: BorderSide(color: AppTheme.borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}