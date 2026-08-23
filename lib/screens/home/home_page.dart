import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../services/checker_repository.dart';
import '../../services/history_service.dart';
import '../../services/subscription_service.dart';
import '../../widgets/language_toggle.dart';
import '../check/check_screen.dart';
import '../history/history_page.dart';
import '../learn/learn_screen.dart';
import '../message_checker/message_checker_screen.dart';
import '../phone_checker/phone_checker_screen.dart';
import '../screenshot_scanner/screenshot_scanner_screen.dart';
import '../subscription/premium_screen.dart';
import '../url_checker/url_checker_screen.dart';

/// NirapodClick post-login dashboard.
///
/// Designed to be a *dashboard*, not a navigation menu - the bottom nav
/// lives one level up in [MainScreen], so this widget just renders the
/// home tab body.
///
/// Layout (top -> bottom):
///   1. Greeting header   - `Good Morning, <name>` + bell + EN/BN toggle.
///   2. Hero CTA card     - "Is something suspicious?" -> CheckScreen.
///   3. Quick Check grid  - 2x2 actionable tiles (Message / Link /
///                          Screenshot / Number).
///   4. Learn tile        - secondary CTA into the Safety Learning Center.
///   5. Recent Scans      - last 3 entries from [HistoryService] with a
///                          "View all" link into the History page.
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildHeader(context, scope, firstName),
                  const SizedBox(height: 24),
                  _buildHeroCta(context),
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, t('home.recentScansTitle')),
                  const SizedBox(height: 12),
                  _buildRecentScans(context),
                  const SizedBox(height: 28),
                  _buildSectionTitle(context, t('home.section.check')),
                  const SizedBox(height: 16),
                  _buildQuickCheckGrid(context),
                  const SizedBox(height: 20),
                  _buildGoPremiumBanner(context),
                  const SizedBox(height: 20),
                  _buildLearnTile(context),
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
    final service = SubscriptionScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t('home.greeting')} $firstName',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('app.tagline'),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            _BellButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text(t('home.noAlerts')),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
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
          ],
        ),
        const SizedBox(height: 14),
        _SubscriptionChip(service: service),
      ],
    );
  }

  // -- Hero CTA --

  Widget _buildHeroCta(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CheckScreen()),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primary, AppTheme.secondary],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded,
                  size: 44, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('home.heroTitle'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('home.heroSubtitle'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t('home.ctaCheckNow'),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppTheme.primary,
                      size: 16,
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

  // -- Section title --

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  // -- Quick Check grid --

  Widget _buildQuickCheckGrid(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final service = SubscriptionScope.of(context);
    final state = service.state;
    final limits = state.limits;
    final unlimited = state.isPremium;
    final tr = AppLocaleScope.of(context).tr;
    String countLabel(int? remaining) {
      if (unlimited || remaining == null) {
        return tr('home.scansUnlimited');
      }
      return tr('home.scansLeftShort').replaceAll(
        '{count}',
        remaining.toString(),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.1,
      children: [
        _QuickCheckCard(
          icon: Icons.mark_email_read_rounded,
          title: t('home.tile.message.title'),
          subtitle: t('home.tile.message.subtitle'),
          countLabel: countLabel(limits.messageScansRemaining),
          showCount: !unlimited,
          color: AppTheme.primary,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MessageCheckerScreen()),
          ),
        ),
        _QuickCheckCard(
          icon: Icons.link_rounded,
          title: t('home.tile.link.title'),
          subtitle: t('home.tile.link.subtitle'),
          countLabel: countLabel(limits.urlScansRemaining),
          // URL checks are already unlimited on free; don't show a chip
          // for them to avoid implying a quota that doesn't exist.
          showCount: limits.urlScansRemaining != null,
          color: AppTheme.secondary,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UrlCheckerScreen()),
          ),
        ),
        _QuickCheckCard(
          icon: Icons.document_scanner_rounded,
          title: t('home.tile.screenshot.title'),
          subtitle: t('home.tile.screenshot.subtitle'),
          countLabel: countLabel(limits.screenshotScansRemaining),
          showCount: !unlimited,
          color: AppTheme.accent,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ScreenshotScannerScreen(),
            ),
          ),
        ),
        _QuickCheckCard(
          icon: Icons.phone_rounded,
          title: t('home.tile.number.title'),
          subtitle: t('home.tile.number.subtitle'),
          countLabel: countLabel(limits.phoneScansRemaining),
          showCount: limits.phoneScansRemaining != null,
          color: AppTheme.danger,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PhoneCheckerScreen(),
            ),
          ),
        ),
      ],
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
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PremiumScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.accent, Color(0xFFFFD789)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('home.goPremiumBanner.title'),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t('home.goPremiumBanner.subtitle'),
                          style: TextStyle(
                            color: AppTheme.textPrimary.withValues(
                              alpha: 0.75,
                            ),
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppTheme.textPrimary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -- Learn tile --

  Widget _buildLearnTile(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Material(
      color: AppTheme.secondary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LearnScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.school_rounded,
                  size: 38, color: AppTheme.secondary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('home.section.learn'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('home.section.learnSubtitle'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Recent Scans (last 3) --

  Widget _buildRecentScans(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return FutureBuilder<List<HistoryEntry>>(
      future: HistoryService().getHistory(limit: 3),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
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
        final scans = snapshot.data ?? const <HistoryEntry>[];
        if (scans.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(16),
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
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => HistoryPage()),
                  );
                },
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t('home.recentScansViewAll'),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
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

// -------- Reusable bits --------

/// Bell icon button shown in the dashboard header.
class _BellButton extends StatelessWidget {
  const _BellButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(
          Icons.notifications_none_rounded,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

/// Single tile in the 2x2 Quick Check grid. Free users see a small scan
/// count chip; premium users see none (their counts are unlimited).
class _QuickCheckCard extends StatelessWidget {
  const _QuickCheckCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    required this.countLabel,
    required this.showCount,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String countLabel;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                if (showCount) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      countLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _typeMeta(context, entry.type);
    final style = RiskStyle.of(entry.result.level);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                meta.icon,
                color: style.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.result.category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: style.color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                style.badge,
                style: TextStyle(
                  color: style.onColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${entry.result.score}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// -------- Subscription bits --------

/// Slim status chip below the header. Says "✨ Premium active" for premium
/// users, otherwise renders nothing (the free-tier user already gets the
/// amber Go Premium banner further down the page).
class _SubscriptionChip extends StatelessWidget {
  const _SubscriptionChip({required this.service});

  final SubscriptionService service;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        if (!service.state.isPremium) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppTheme.success.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_rounded,
                size: 14,
                color: AppTheme.success,
              ),
              const SizedBox(width: 6),
              Text(
                t('home.premiumActiveChip'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
