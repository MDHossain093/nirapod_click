import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/locale/localizer.dart';
import '../../core/safety_score.dart';
import '../../core/theme/app_theme.dart';
import '../../services/checker_repository.dart';
import '../../services/free_quota_service.dart';
import '../../services/subscription_service.dart';
import '../../widgets/alert_badge_bell.dart';
import '../../widgets/header_plan_toggle.dart';
import '../../widgets/language_toggle.dart';
import '../../widgets/pressable.dart';
import '../check/check_screen.dart';
import '../history/history_page.dart';
import '../learn/learn_screen.dart';
import '../subscription/premium_screen.dart';

/// NirapodClick post-login dashboard.
///
/// Designed to be a *dashboard*, not a navigation menu - the bottom nav
/// lives one level up in [MainScreen], so this widget just renders the
/// home tab body.
///
/// Layout (top -> bottom):
///   1. Greeting header   - `Good Morning, <name>` + tagline (big) +
///                          bell + EN/BN toggle + plan badge. The inline
///                          "X of 5 free checks" line under the tagline
///                          is itself tappable for free users and routes
///                          to PremiumScreen.
///   2. Hero CTA card     - "Is something suspicious?" -> CheckScreen.
///                          Stacked inside the gradient, so it never
///                          overflows on narrow screens. This is the
///                          primary entry point into the 4 scanners;
///                          the Check tab in the bottom nav is the
///                          second one, so we don't repeat the CTA
///                          further down the dashboard.
///   3. Safety Score card - 0-100 score for the last 30 days + 4-pill
///                          breakdown (critical/high/medium/safe). Tap
///                          routes to History.
///   4. Recent Scans      - last 3 entries from [HistoryService] with an
///                          inline "View all" link in the section header.
///   5. Learn tile        - secondary CTA into the Safety Learning Center.
///   6. Go Premium banner - amber gradient row (free users only).
///
/// Every user-facing string flows through `AppLocaleScope.tr(...)`.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppLocaleScope.of(context);
    final t = scope.tr;
    final user = FirebaseAuth.instance.currentUser;
    final hasDisplayName = user?.displayName?.isNotEmpty ?? false;
    final firstName = hasDisplayName
        ? user!.displayName!.split(' ').first
        : (user?.email ?? t('home.greetingFallback'))
            .split('@')
            .first;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeader(context, scope, firstName),
                  const SizedBox(height: 22),
                  _buildHeroCta(context),
                  const SizedBox(height: 24),
                  _buildSafetyScoreCard(context),
                  const SizedBox(height: 32),
                  _buildRecentScansHeader(context),
                  const SizedBox(height: 12),
                  _buildRecentScansList(context),
                  const SizedBox(height: 24),
                  _buildLearnTile(context),
                  const SizedBox(height: 16),
                  _buildGoPremiumBanner(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Header --

  Widget _buildHeader(
    BuildContext context,
    AppLocaleScope scope,
    String firstName,
  ) {
    final t = scope.tr;
    final subscription = SubscriptionScope.of(context);
    final quota = FreeQuotaScope.of(context);
    final now = DateTime.now();
    final hour = now.hour;
    // Time-of-day partition (24h):
    //   05–11  morning
    //   12–16  afternoon
    //   17–20  evening
    //   21–04  night
    // Boundaries chosen so the greeting matches user expectation
    // (early-evening/late-night users never see "Good Morning").
    final String greetingKey;
    final String greetingEmoji;
    if (hour >= 5 && hour <= 11) {
      greetingKey = 'home.greeting.morning';
      greetingEmoji = '🌅';
    } else if (hour >= 12 && hour <= 16) {
      greetingKey = 'home.greeting.afternoon';
      greetingEmoji = '☀️';
    } else if (hour >= 17 && hour <= 20) {
      greetingKey = 'home.greeting.evening';
      greetingEmoji = '🌇';
    } else {
      greetingKey = 'home.greeting.night';
      greetingEmoji = '🌙';
    }
    return Container(
      // Tinted hero strip behind the header — gives it depth without
      // a flat blue slab. Stays consistent with the gradient surfaces
      // elsewhere (Hero CTA, premium banner) but very faint, so the
      // bell + language toggle read on top of it unchanged.
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.headerTintStart,
            AppTheme.headerTintEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1 — bell + language toggle on the left, plan badge
          // pinned to the right corner. The plan badge mirrors the
          // language toggle visually so the two pills read as a
          // matching pair. Tapping the FREE badge routes to
          // PremiumScreen as a convenience for users who want to
          // upgrade; the PREMIUM badge has no tap action (you're
          // already in).
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AlertBadgeBell(),
              const SizedBox(width: 8),
              LanguageToggle(
                value: scope.locale == AppLocale.bangla
                    ? CopyLanguage.bangla
                    : CopyLanguage.english,
                onChanged: (next) {
                  scope.onChanged(
                    next == CopyLanguage.bangla
                        ? AppLocale.bangla
                        : AppLocale.english,
                  );
                },
              ),
              // Spacer pushes the plan badge to the right edge.
              const Spacer(),
              AnimatedBuilder(
                animation: subscription,
                builder: (context, _) {
                  final isPremium = subscription.state.isPremium;
                  return HeaderPlanBadge(
                    plan: isPremium
                        ? HeaderPlan.premium
                        : HeaderPlan.free,
                    // Free users can tap the badge to upgrade;
                    // premium users don't need a tap target here
                    // (the badge is purely informational).
                    onTap: isPremium
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PremiumScreen(),
                              ),
                            ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Row 2 — emoji + greeting line. Locale picks morning /
          // afternoon / evening / night so it never says "Good
          // Morning" past 11am.
          Row(
            children: [
              Text(
                greetingEmoji,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${t(greetingKey)} $firstName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 3 — tagline, slightly larger and tighter than before.
          Text(
            t('app.tagline'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              height: 1.1,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 10),
          // Row 4 — inline "X of 5 free checks used this month"
          // line. Sits below the tagline so the user sees both the
          // brand promise ("Stay safe online") and the concrete
          // remaining-budget number without having to scroll. The
          // text swaps to "Unlimited · Premium" when the user is
          // premium so the same slot serves both audiences without
          // a separate chip.
          AnimatedBuilder(
            animation: Listenable.merge([subscription, quota]),
            builder: (context, _) {
              final isPremium = subscription.state.isPremium;
              final fmt = AppLocaleScope.of(context).formatNumber;
              final String line;
              final Color lineColor;
              if (isPremium) {
                line = t('home.headerQuota.unlimited');
                lineColor = AppTheme.success;
              } else {
                final used = quota.used;
                line = t('home.headerQuota.inline')
                    .replaceAll('{used}', fmt(used));
                lineColor = used >= quota.monthlyBudget
                    ? AppTheme.danger
                    : AppTheme.textSecondary;
              }
              // Free users can tap the inline quota line to jump
              // straight to the Premium screen — it's the only
              // free-tier affordance on the home screen now that the
              // full-width quota pill has been removed, so it has to
              // both communicate the budget and route to the
              // upgrade surface. Premium users see the same line
              // but it's not pressable (they're already premium).
              final content = Row(
                children: [
                  Icon(
                    isPremium
                        ? Icons.verified_rounded
                        : Icons.event_available_rounded,
                    size: 14,
                    color: lineColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: lineColor,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (!isPremium) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: lineColor,
                    ),
                  ],
                ],
              );
              if (isPremium) return content;
              return Pressable(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PremiumScreen(),
                  ),
                ),
                child: content,
              );
            },
          ),
        ],
      ),
    );
  }

  // -- Hero CTA (stacked, never overflows) --

  Widget _buildHeroCta(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Pressable(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CheckScreen()),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          // Brand header gradient token — same `primary → secondary`
          // as the AppBar + Go Premium + Profile upsell + check CTAs.
          gradient: AppTheme.headerGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusHero),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: AppTheme.tintBorderStrong),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusHero),
          child: Stack(
            children: [
              // Decorative glow circles - purely cosmetic depth.
              Positioned(
                right: -50,
                top: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              // Stacked content - no Row means no horizontal overflow.
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      // Launcher icon mark — `assets/icon.png` is the
                      // icon-only brand mark (no wordmark), which fits
                      // the 48px corner slot without dominating the
                      // card. The full wordmark logo would be too busy
                      // here; the home header already shows the app
                      // name in the top bar. Falls back to a generic
                      // shield if the asset isn't bundled.
                      child: Image.asset(
                        'assets/icon.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.shield_rounded,
                          size: 26,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t('home.heroTitle'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t('home.heroSubtitle'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Full-width CTA so it's never clipped.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t('home.ctaCheckNow'),
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppTheme.primary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Safety Score card (post-redesign dashboard widget) --
  //
  // Replaced the 2x2 Quick Check grid. The home dashboard is now an
  // information surface — "here's how risky the things you've checked
  // have been" — instead of four duplicated entry points to the same
  // scanners. The 4 scanners are still one tap away via the hero CTA
  // above and the bottom-nav Check tab.
  //
  // The card reads from the same Firestore snapshots stream the
  // History page uses (`CheckerRepository.watchRecent`). It used to
  // be a `FutureBuilder` wrapped around a one-shot `getHistory()`
  // call — that worked on first load but never refreshed when the
  // user deleted scans from the History page, because `FutureBuilder`
  // only re-fires when its `future` argument changes identity. The
  // bug surfaced as "deleted scans still show on home until I close
  // and reopen the app". Switching to `StreamBuilder` ties the home
  // dashboard to the same live subscription the History page is on,
  // so any delete / save re-emits the snapshot and rebuilds both
  // views in lockstep.
  Widget _buildSafetyScoreCard(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final fmt = AppLocaleScope.of(context).formatNumber;
    return StreamBuilder<List<HistoryEntry>>(
      stream: CheckerRepository().watchRecent(limit: 50),
      builder: (context, snapshot) {
        // Loading state. Firestore snapshots streams report
        // `ConnectionState.active` once the listener is subscribed,
        // not `done`, so the old `!= done` check would have flashed
        // a spinner for every re-emission after the first. We show
        // the spinner only while genuinely waiting AND we don't yet
        // have data to render. Subsequent re-emissions keep the
        // previous data on screen while the new one settles — no
        // flicker.
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _ScoreCardShell(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 22,
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    t('home.safetyScoreCard.subtitle'),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // If the stream errored AND we don't have anything cached
        // yet (cold-start failure), fall through to the "no scans"
        // branch by treating the error as an empty entry list. Same
        // UX as the old FutureBuilder, which caught everything and
        // returned `[]`.
        final entries = (snapshot.hasError && !snapshot.hasData)
            ? const <HistoryEntry>[]
            : (snapshot.data ?? const <HistoryEntry>[]);
        final score = SafetyScore.compute(entries);

        if (score.status == SafetyStatus.noScans) {
          return _ScoreCardShell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CheckScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primary
                          .withValues(alpha: AppTheme.tintSubtle),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t('home.safetyScoreCard.emptyTitle'),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t('home.safetyScoreCard.emptyBody'),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }

        // Colour tokens keyed off the band. Re-using the AppTheme
        // risk palette so the card colour matches the per-row badges
        // in History / Result pages — same verdict reads the same
        // everywhere.
        final bandColor = _statusColor(score.status);
        final bandLabel = _statusLabel(score.status, t);

        return _ScoreCardShell(
          onTap: () {
            // Tap on the card routes to History so the user can see
            // which specific scans contributed to the score.
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryPage()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: title + status pill.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t('home.safetyScoreCard.title'),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: bandColor.withValues(
                          alpha: AppTheme.tintSurface,
                        ),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusXs),
                        border: Border.all(
                          color: bandColor.withValues(alpha: AppTheme.tintBorderStrong),
                        ),
                      ),
                      child: Text(
                        bandLabel,
                        style: TextStyle(
                          color: bandColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Score ring + breakdown row. Ring is the visual
                // anchor; the 4 stats to its right give the user the
                // "why" without a chart.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ScoreRing(
                      score: score.overallScore,
                      color: bandColor,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            // Use the shared formatter so the
                            // denominator localizes with the rest of
                            // the number — `৮২ / ১০০` in Bangla,
                            // `82 / 100` in English. Hardcoding
                            // ` / 100` here used to leave the
                            // denominator as ASCII in BN locale,
                            // which read as "shows 100" against a
                            // localised score (e.g. `৬৩ / 100`).
                            AppLocaleScope.of(context).formatScore(score.overallScore),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              letterSpacing: -0.4,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${t('home.safetyScoreCard.last30Days')} · '
                            '${fmt(score.totalInWindow)}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 4 stat pills in a 4-column grid. We collapse
                // Critical+High into separate pills so a single
                // critical scan stands out from a single high scan
                // — both feel "dangerous" to the user but the
                // pill colours match their actual severity.
                Row(
                  children: [
                    Expanded(
                      child: _StatPill(
                        label: t('home.safetyScoreCard.stat.critical'),
                        count: score.criticalCount,
                        color: AppTheme.riskCritical,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatPill(
                        label: t('home.safetyScoreCard.stat.high'),
                        count: score.highCount,
                        color: AppTheme.riskHigh,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatPill(
                        label: t('home.safetyScoreCard.stat.medium'),
                        count: score.mediumCount,
                        color: AppTheme.riskMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatPill(
                        label: t('home.safetyScoreCard.stat.safe'),
                        count: score.lowCount + score.safeCount,
                        color: AppTheme.riskLow,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -- Go Premium banner (free users only) --

  Widget _buildGoPremiumBanner(BuildContext context) {
    final service = SubscriptionScope.of(context);
    final t = AppLocaleScope.of(context).tr;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        if (!service.state.isFree) return const SizedBox.shrink();
        return Pressable(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PremiumScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // Brand header gradient token — same as the AppBar +
              // Go Premium upsell + Profile card CTAs.
              gradient: AppTheme.headerGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: AppTheme.tintBorderStrong),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('home.goPremiumBanner.title'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t('home.goPremiumBanner.subtitle'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -- Learn tile --

  Widget _buildLearnTile(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Pressable(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LearnScreen()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(
                    alpha: AppTheme.tintSubtle,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 28,
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t('home.section.learn'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('home.section.learnSubtitle'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Recent Scans header (title + inline "View all") --

  Widget _buildRecentScansHeader(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Row(
      children: [
        Expanded(
          child: Text(
            t('home.recentScansTitle'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
        ),
        Pressable(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => HistoryPage()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  t('home.recentScansViewAll'),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.primary,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // -- Recent Scans list (last 3 + footer link) --

  Widget _buildRecentScansList(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    // Live Firestore snapshots stream, same pattern as the History
    // page. We subscribe to the same `watchRecent(limit: 50)` the
    // Safety Score card uses so deletes from the History page
    // propagate here automatically — the previous
    // `FutureBuilder(getHistory(limit: 3))` only fired once on
    // mount, leaving a stale "last 3" on screen until the user
    // closed and reopened the app. We then `.take(3)` to clip down
    // to the dashboard's "last 3" tile; the underlying repository
    // always reads the most-recent `limit` rows in `createdAt desc`
    // order so taking the first 3 is the right slice.
    return StreamBuilder<List<HistoryEntry>>(
      stream: CheckerRepository().watchRecent(limit: 50),
      builder: (context, snapshot) {
        // Same loading-gate pattern as the Safety Score card:
        // spinner only while waiting AND we have no data yet. After
        // the first emission, subsequent re-emissions keep the
        // previous list visible while the new one is fetched — no
        // flicker on every Firestore write.
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          // Compact loading placeholder - the rest of the dashboard
          // shouldn't shift while we wait.
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          );
        }
        // If the stream errored AND we don't have anything cached
        // yet, fall through to the empty-state branch — same UX as
        // the old FutureBuilder which caught everything and returned
        // `[]`.
        // Clip the most-recent-50 down to the most-recent-3 the
        // dashboard renders. The stream itself is ordered
        // newest-first by the repository, so `take(3)` is the
        // correct slice.
        final all = (snapshot.hasError && !snapshot.hasData)
            ? const <HistoryEntry>[]
            : (snapshot.data ?? const <HistoryEntry>[]);
        final scans = all.length <= 3 ? all : all.take(3).toList();
        if (scans.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Text(
              t('home.recentScansEmpty'),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            children: [
              for (var i = 0; i < scans.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppTheme.borderSubtle,
                    indent: 16,
                    endIndent: 16,
                  ),
                _RecentScanTile(
                  entry: scans[i],
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HistoryPage(),
                      ),
                    );
                  },
                ),
              ],
              const Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.borderSubtle,
              ),
              Pressable(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => HistoryPage()),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t('home.recentScansViewAll'),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.primary,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -------- Safety score helpers --------

/// Visual + colour mapping for the 5-band [SafetyStatus]. Kept as a
/// pure helper so the home dashboard's call to [_statusColor] /
/// [_statusLabel] doesn't drift from any future rebrand of the
/// same tokens elsewhere.
Color _statusColor(SafetyStatus status) {
  switch (status) {
    case SafetyStatus.noScans:
      return AppTheme.primary;
    case SafetyStatus.excellent:
    case SafetyStatus.good:
      return AppTheme.riskLow;
    case SafetyStatus.fair:
      return AppTheme.riskMedium;
    case SafetyStatus.poor:
      return AppTheme.riskHigh;
    case SafetyStatus.critical:
      return AppTheme.riskCritical;
  }
}

String _statusLabel(SafetyStatus status, String Function(String) tr) {
  switch (status) {
    case SafetyStatus.noScans:
      return tr('home.safetyScoreCard.emptyTitle');
    case SafetyStatus.excellent:
      return tr('home.safetyScoreCard.status.excellent');
    case SafetyStatus.good:
      return tr('home.safetyScoreCard.status.good');
    case SafetyStatus.fair:
      return tr('home.safetyScoreCard.status.fair');
    case SafetyStatus.poor:
      return tr('home.safetyScoreCard.status.poor');
    case SafetyStatus.critical:
      return tr('home.safetyScoreCard.status.critical');
  }
}

/// Outer shell for the Safety Score card. Same `radiusXl` rounded
/// surface + subtle border used by the "Learn" tile so the two
/// stacked cards read as a pair. The press scale is reused from
/// [Pressable] so taps on the card feel identical to taps on the
/// hero CTA / run-check tile / Go Premium banner.
class _ScoreCardShell extends StatelessWidget {
  const _ScoreCardShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Pressable(onTap: onTap!, child: card);
  }
}

/// Circular score indicator. Renders a 0-100 score with a coloured
/// progress ring, leaving the actual breakdown to the surrounding
/// card body. Sized via [size] so the same widget could be reused
/// at smaller scales (e.g. profile card later) without restyling.
class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score, required this.color});

  final int score;
  final Color color;

  static const double _size = 76;

  @override
  Widget build(BuildContext context) {
    // Pct clamps to 0..1. We don't show intermediate progress as a
    // sweep — the static ring + the number reads cleaner at this
    // size than a partially-filled arc that could read as a bug.
    final pct = (score / 100).clamp(0.0, 1.0);
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring — drawn first so the foreground overlay
          // sits on top of it.
          SizedBox(
            width: _size,
            height: _size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 7,
              color: color.withValues(alpha: AppTheme.tintSubtle),
              backgroundColor: color.withValues(alpha: AppTheme.tintSurface),
            ),
          ),
          // Foreground sweep — solid colour, same thickness, the
          // actual score.
          SizedBox(
            width: _size,
            height: _size,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 7,
              color: color,
              backgroundColor: Colors.transparent,
            ),
          ),
          // Center label. We render the score here (not the "/100")
          // so the big number is the focal point; the "/100" lives
          // in the right-hand column for context.
          Text(
            AppLocaleScope.of(context).formatNumber(score),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: -0.6,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single stat pill inside the Safety Score card. Stacks the count
/// on top of the label so the count dominates (it's the data) and
/// the label sets context. Background is a tint of the band colour
/// so a glance at the four pills tells the user the distribution.
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.tintSurface),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: color.withValues(alpha: AppTheme.tintBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocaleScope.of(context).formatNumber(count),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single row in the Recent Scans card. Shows scan-type icon, risk pill,
/// truncated input, and the numeric score.
class _RecentScanTile extends StatelessWidget {
  const _RecentScanTile({required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  ({IconData icon, String labelKey}) _typeMeta(BuildContext context, ScanType t) {
    final tr = AppLocaleScope.of(context).tr;
    switch (t) {
      case ScanType.message:
        return (icon: Icons.chat_bubble_outline_rounded, labelKey: tr('history.typeMessage'));
      case ScanType.url:
        return (icon: Icons.link_rounded, labelKey: tr('history.typeUrl'));
      case ScanType.screenshot:
        return (
          icon: Icons.image_outlined,
          labelKey: tr('history.typeScreenshot'),
        );
      case ScanType.phone:
        return (icon: Icons.phone_outlined, labelKey: tr('history.typePhone'));
      case ScanType.qr:
        return (
          icon: Icons.qr_code_scanner_rounded,
          labelKey: tr('history.typeQr'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _typeMeta(context, entry.type);
    final style = RiskStyle.of(entry.result.level);
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: AppTheme.tintSurface),
                shape: BoxShape.circle,
              ),
              child: Icon(
                meta.icon,
                color: style.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.result.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.originalText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: style.color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                entry.result.level.localizedBadge,
                style: TextStyle(
                  color: style.onColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppLocaleScope.of(context).formatNumber(entry.result.score),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// -------- Subscription bits --------
//
// (Removed: the old `_SubscriptionChip` that lived below the tagline
// is gone. The plan status is now surfaced by the [HeaderPlanBadge]
// in row 1 of the header, and the free-tier remaining count is
// shown in the inline row below the tagline. The Go Premium banner
// further down the page is the upgrade CTA for free users.)
