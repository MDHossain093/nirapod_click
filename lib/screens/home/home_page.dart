import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/language_toggle.dart';
import '../auth/auth_gate.dart';
import '../history/history_page.dart';
import '../message_checker/message_checker_screen.dart';
import '../url_checker/url_checker_screen.dart';

/// NirapodClick post-login dashboard.
///
/// Layout (top -> bottom):
///   1. Greeting header  - `Good Morning, <name>` + bell icon + EN/BN.
///   2. Safety Score     - gradient hero card with `82/100` + status pill.
///   3. Scanner grid     - 2x2 actionable tiles (Message / Link /
///                         Screenshot / Number).
///   4. Latest Scam Alert - one-line card with chevron.
///   5. Learn to Stay Safe - secondary CTA to the academy (placeholder).
///   6. Bottom nav       - Home / History / Learn / Profile.
///
/// Every user-facing string flows through `AppLocaleScope.tr(...)`. The
/// EN/BN pill in the header is the global language switcher - tapping it
/// flips every screen in the app.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 0=Home, 1=History, 2=Learn (placeholder), 3=Profile (placeholder).
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final pages = <Widget>[
      const _HomeTab(),
      const HistoryPage(),
      _LearnPlaceholderPage(),
      _ProfilePlaceholderPage(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: t('nav.home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history_rounded),
            label: t('nav.history'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.school_outlined),
            selectedIcon: const Icon(Icons.school_rounded),
            label: t('nav.learn'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: t('nav.profile'),
          ),
        ],
      ),
    );
  }
}

// -------- Home tab --------

class _HomeTab extends StatelessWidget {
  const _HomeTab();

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

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(context, scope, firstName),
                const SizedBox(height: 24),
                _buildSafetyScore(context),
                const SizedBox(height: 28),
                _buildSectionTitle(context, t('home.section.check')),
                const SizedBox(height: 16),
                _buildScannerGrid(context),
                const SizedBox(height: 28),
                _buildScamAlert(context),
                const SizedBox(height: 20),
                _buildLearnCard(context),
                const SizedBox(height: 16),
                _buildFooter(context),
              ]),
            ),
          ),
        ],
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
    return Row(
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
    );
  }

  // -- Safety Score hero --

  Widget _buildSafetyScore(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.secondary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_user_rounded,
              color: Colors.white, size: 42),
          const SizedBox(height: 12),
          Text(
            t('home.safetyScore'),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            t('home.safetyScoreValue'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              t('home.safetyStatus'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(t('home.safetyReportSoon')),
                ),
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 18),
            label: Text(
              t('home.viewSafetyReport'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // -- Section title --

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  // -- Scanner grid --

  Widget _buildScannerGrid(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    void showSoon(String key) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(t(key)),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.25,
      children: [
        _ScannerCard(
          icon: Icons.mark_email_read_rounded,
          title: t('home.tile.message.title'),
          subtitle: t('home.tile.message.subtitle'),
          color: AppTheme.primary,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MessageCheckerScreen()),
          ),
        ),
        _ScannerCard(
          icon: Icons.link_rounded,
          title: t('home.tile.link.title'),
          subtitle: t('home.tile.link.subtitle'),
          color: AppTheme.secondary,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UrlCheckerScreen()),
          ),
        ),
        _ScannerCard(
          icon: Icons.document_scanner_rounded,
          title: t('home.tile.screenshot.title'),
          subtitle: t('home.tile.screenshot.subtitle'),
          color: AppTheme.accent,
          onTap: () => showSoon('home.screenshotSoon'),
        ),
        _ScannerCard(
          icon: Icons.phone_rounded,
          title: t('home.tile.number.title'),
          subtitle: t('home.tile.number.subtitle'),
          color: AppTheme.danger,
          onTap: () => showSoon('home.numberSoon'),
        ),
      ],
    );
  }

  // -- Scam alert --

  Widget _buildScamAlert(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final headline = t('home.section.scamAlert');
    final body = t('home.scamAlertsSoon');
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(body),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.riskMedium.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.riskMedium,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
    );
  }

  // -- Learn card --

  Widget _buildLearnCard(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
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
        ],
      ),
    );
  }

  // -- Footer (sign-out) --

  Widget _buildFooter(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Center(
      child: TextButton.icon(
        onPressed: () async {
          await AuthService().signOut();
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthGate()),
            (_) => false,
          );
        },
        icon: const Icon(Icons.logout, size: 18),
        label: Text(t('home.signOut')),
      ),
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

/// Single tile in the 2x2 scanner grid.
class _ScannerCard extends StatelessWidget {
  const _ScannerCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
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

// -------- Placeholder pages for the 4-tab nav --------

/// "Learn" tab - full academy is not built yet. Shows a placeholder so
/// the bottom-nav works and judges can see the tab structure.
class _LearnPlaceholderPage extends StatelessWidget {
  const _LearnPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Scaffold(
      appBar: AppBar(title: Text(t('nav.learn'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t('home.section.learnSubtitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Profile" tab - account settings live here. Not built yet.
class _ProfilePlaceholderPage extends StatelessWidget {
  const _ProfilePlaceholderPage();

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text(t('nav.profile'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: AppTheme.primary,
                child: Icon(Icons.person,
                    color: Colors.white, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                user?.displayName?.isNotEmpty == true
                    ? user!.displayName!
                    : (user?.email ?? t('home.greetingFallback')),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                t('home.section.learnSubtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
