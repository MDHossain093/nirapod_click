import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/auth/admin_gate.dart';
import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/checker_repository.dart';
import '../../services/notifications_prefs_service.dart';
import '../../widgets/scan_history_select_sheet.dart';
import '../admin/admin_alerts_screen.dart';
import '../admin/admin_url_rules_screen.dart';
import '../history/history_page.dart';
import '../learn/learn_screen.dart';
import '../subscription/subscription_status_card.dart';

/// Profile + Settings hub.
///
/// Sections:
///   1. Account information (name + email + avatar circle)
///   2. Subscription status card (delegated to [SubscriptionStatusCard])
///   3. Your Activity      - Scan History, Safety Learning
///   4. Settings           - Notifications, Privacy  (modal sheets)
///   5. Account            - Log Out (with confirm dialog)
///
/// All user-facing text flows through [AppLocaleScope] so EN/BN stay in sync.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final user = FirebaseAuth.instance.currentUser;

    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : t('profile.fallbackName');

    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('profile.appBarTitle')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          // Editorial avatar / name / email hero. Stacked (not Row) so
          // long display names + emails never overflow on narrow phones.
          _ProfileHeader(name: displayName, email: email),

          const SizedBox(height: 16),

          // Subscription state — managed by its own widget so the
          // free / active swap stays live. Visuals already match the
          // new design tokens; left untouched.
          const SubscriptionStatusCard(),

          const SizedBox(height: 28),

          // ---- Activity group ----
          _SectionTitle(text: t('profile.sectionActivity')),
          const SizedBox(height: 12),
          _MenuGroup(
            children: [
              _MenuItem(
                icon: Icons.history_rounded,
                title: t('profile.menuHistoryTitle'),
                subtitle: t('profile.menuHistorySubtitle'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HistoryPage(),
                    ),
                  );
                },
              ),
              _MenuItem(
                icon: Icons.school_rounded,
                title: t('profile.menuLearnTitle'),
                subtitle: t('profile.menuLearnSubtitle'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LearnScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ---- Settings group ----
          _SectionTitle(text: t('profile.sectionSettings')),
          const SizedBox(height: 12),
          _MenuGroup(
            children: [
              _MenuItem(
                icon: Icons.notifications_outlined,
                title: t('profile.menuNotificationsTitle'),
                subtitle: t('profile.menuNotificationsSubtitle'),
                onTap: () => _showNotifications(context),
              ),
              _MenuItem(
                icon: Icons.language_rounded,
                title: t('profile.menuLanguageTitle'),
                subtitle: t('profile.menuLanguageSubtitle'),
                onTap: () => _showLanguage(context),
              ),
              _MenuItem(
                icon: Icons.palette_outlined,
                title: t('profile.menuThemeTitle'),
                subtitle: t('profile.menuThemeSubtitle'),
                onTap: () => _showTheme(context),
              ),
              _MenuItem(
                icon: Icons.privacy_tip_outlined,
                title: t('profile.menuPrivacyTitle'),
                subtitle: t('profile.menuPrivacySubtitle'),
                onTap: () => _showPrivacy(context),
              ),
            ],
          ),

          // ---- Admin group (gated) ----
          // Visible only when the signed-in user is on the
          // compile-time admin list (see lib/core/auth/admin_uids.dart).
          // We rebuild on each frame so a freshly-promoted admin sees
          // the row without needing to log out and back in.
          if (isAdmin(user)) ...[
            const SizedBox(height: 28),
            _SectionTitle(text: t('profile.sectionAdmin')),
            const SizedBox(height: 12),
            _MenuGroup(
              children: [
                _MenuItem(
                  icon: Icons.campaign_rounded,
                  title: t('profile.menuAdminAlertsTitle'),
                  subtitle: t('profile.menuAdminAlertsSubtitle'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminAlertsScreen(),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.link_rounded,
                  title: t('profile.menuAdminUrlRulesTitle'),
                  subtitle: t('profile.menuAdminUrlRulesSubtitle'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminUrlRulesScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],

          const SizedBox(height: 28),

          

          // Dedicated logout CTA — same full-width gradient + white
          // text pattern as Login / SignUp. Uses the danger gradient
          // (red → darker red) so it reads as a destructive action
          // instead of a primary brand action. Tapping it shows the
          // confirm dialog; confirming calls AuthService.signOut() and
          // AuthGate automatically rebuilds to LoginPage.
          _GradientLogoutButton(
            label: t('profile.menuLogoutTitle'),
            onPressed: () => _logout(context),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- actions

  void _showNotifications(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    // Singleton prefs read — `load()` was awaited in main.dart so this
    // is synchronous and won't flicker on first frame.
    final prefs = NotificationsPrefsService.instance;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (innerCtx, setSheetState) {
            return _SettingsSheet(
              title: t('profile.menuNotificationsTitle'),
              icon: Icons.notifications_outlined,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: prefs.enabled,
                    onChanged: (v) async {
                      await prefs.setEnabled(v);
                      // State lives on the singleton, but the Switch's
                      // `value` is read fresh every build — setSheetState
                      // here is what keeps the thumb in sync after the
                      // async setEnabled resolves.
                      if (innerCtx.mounted) setSheetState(() {});
                    },
                    title: Text(t('profile.notificationsToggleTitle')),
                    subtitle: Text(t('profile.notificationsToggleSubtitle')),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t('profile.notificationsBody'),
                    style: const TextStyle(
                      height: 1.4,
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Language picker sheet. Shows two rows (English / বাংলা); the
  /// currently-active locale is marked with a check icon and the other
  /// row is a chevron — same visual language as `_MenuItem`. Tapping a
  /// row swaps the locale through [AppLocaleScope] (single source of
  /// truth shared with the home header's `LanguageToggle`) and pops
  /// the sheet so the user sees the rest of the app re-render in the
  /// new locale immediately.
  void _showLanguage(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final scope = AppLocaleScope.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return _SettingsSheet(
          title: t('profile.menuLanguageTitle'),
          icon: Icons.language_rounded,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in const <_LanguageOption>[
                _LanguageOption(AppLocale.english, 'English', 'EN'),
                _LanguageOption(AppLocale.bangla, 'বাংলা', 'BN'),
              ]) ...[
                _LanguageRow(
                  label: entry.label,
                  short: entry.short,
                  selected: scope.locale == entry.locale,
                  onTap: () {
                    scope.onChanged(entry.locale);
                    Navigator.of(context).pop();
                  },
                ),
                if (entry.locale == AppLocale.english)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppTheme.borderSubtle,
                    indent: 64,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Theme stub. The app is light-only today, so the sheet is a single
  /// paragraph (same body copy as the future real sheet would show when
  /// no theme is selectable). When real theme switching is added, swap
  /// this body for the actual `RadioListTile`s.
  void _showTheme(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return _SettingsSheet(
          title: t('profile.menuThemeTitle'),
          icon: Icons.palette_outlined,
          child: Text(
            t('profile.themeComingSoon'),
            style: const TextStyle(
              height: 1.4,
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        );
      },
    );
  }

  /// Privacy sheet. Body is the existing description paragraph + two
  /// action buttons: a destructive "Delete all" (with a confirm dialog
  /// behind it) and a neutral "Select scans to delete" that opens the
  /// multi-select bottom sheet.
  void _showPrivacy(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    // Capture the parent navigator NOW, while the BuildContext is
    // still valid, so the inner sheet buttons can chain to a second
    // sheet after popping the privacy sheet. Using a stale inner
    // context after `pop()` is the classic async-context-after-pop
    // bug — it silently swallows the next `showModalBottomSheet`.
    final parentNavigator = Navigator.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return _SettingsSheet(
          title: t('profile.menuPrivacyTitle'),
          icon: Icons.privacy_tip_outlined,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('profile.privacyBody'),
                style: const TextStyle(
                  height: 1.4,
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _PrivacyActionButton(
                icon: Icons.delete_sweep_rounded,
                label: t('profile.privacyDeleteAll'),
                tone: _PrivacyActionTone.danger,
                onTap: () => _confirmDeleteAll(context),
              ),
              const SizedBox(height: 10),
              _PrivacyActionButton(
                icon: Icons.checklist_rounded,
                label: t('profile.privacyDeleteSelected'),
                tone: _PrivacyActionTone.neutral,
                onTap: () {
                  // Pop the privacy sheet (this Navigator), then open
                  // the multi-select sheet anchored to the parent
                  // Navigator (Profile screen). Using the captured
                  // parentNavigator avoids the "context has been
                  // disposed" failure mode that hit this flow before.
                  Navigator.of(context).pop();
                  showScanHistorySelectSheet(parentNavigator.context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Confirm dialog for "delete all". On confirm: closes the privacy
  /// sheet, calls [CheckerRepository.clearAll], and shows a SnackBar
  /// with the deleted count. SnackBar is on the parent Scaffold so it
  /// survives sheet dismissal.
  Future<void> _confirmDeleteAll(BuildContext context) async {
    final t = AppLocaleScope.of(context).tr;
    final fmt = AppLocaleScope.of(context).formatNumber;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t('profile.privacyDeleteAllConfirm')),
          content: Text(t('profile.privacyDeleteAllBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t('profile.commonCancel')),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.riskHigh, AppTheme.riskCritical],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(t('profile.commonDelete')),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    // Pop the privacy sheet so the SnackBar has somewhere to anchor.
    navigator.pop();

    try {
      final deleted = await CheckerRepository().clearAll();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            t('profile.historyDeletedToast').replaceAll('{n}', fmt(deleted)),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(e.toString()),
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    final t = AppLocaleScope.of(context).tr;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t('profile.logoutDialogTitle')),
          content: Text(t('profile.logoutDialogBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t('profile.logoutCancel')),
            ),
            // Brand-gradient confirm CTA — same `primary → secondary`
            // gradient + transparent ElevatedButton pattern used by the
            // Login / SignUp primary CTAs (see login_page.dart). The
            // button itself stays transparent so its backgroundColor /
            // foregroundColor never overrides the gradient or the white
            // label. Visually this reads as "the same button you tap to
            // sign in", confirming the action rather than reading as a
            // separate destructive style.
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.headerGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(t('profile.logoutConfirm')),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // Sign out from BOTH Firebase Auth AND the cached GoogleSignIn
    // session. We must go through AuthService (not just
    // `FirebaseAuth.instance.signOut()`) because `google_sign_in`
    // keeps a separate on-device session for the Google account
    // picker: if we only sign out of Firebase, the next tap on
    // "Continue with Google" silently re-uses the cached account and
    // AuthGate immediately bounces the user back into MainScreen
    // without ever showing the account picker. AuthService.signOut()
    // already runs both calls in parallel via Future.wait.
    //
    // AuthGate listens to authStateChanges() (see auth_gate.dart) and
    // rebuilds to LoginPage automatically the moment Firebase emits
    // `null` — there's nothing to manually navigate. Pushing or
    // popping here would either be a no-op (popUntil on the home
    // stack returns Profile itself as `isFirst`) or fight the gate's
    // own rebuild.
    try {
      await AuthService().signOut();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(AuthService.describeError(e)),
        ),
      );
    }
  }
}

// -------- Header --------

/// Horizontal avatar + name/email identity card. White surface (matches
/// `_MenuGroup`) with a soft gradient accent strip on the left so it
/// still reads as a hero card without the dated stacked look. Same
/// radius, shadow, and border tokens as the menu cards that follow it.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFrom(name);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left gradient strip — visual anchor so the card still
            // feels like a "hero" without competing with the avatar.
            Container(
              width: 6,
              decoration: const BoxDecoration(
                gradient: AppTheme.headerGradient,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusXl),
                  bottomLeft: Radius.circular(AppTheme.radiusXl),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        // Gradient avatar so it doesn't look like the
                        // pure-white circle on the old design — pairs
                        // with the left strip + header gradient.
                        gradient: AppTheme.headerGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.alternate_email_rounded,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// First letter of first two whitespace-separated words. Falls back
  /// to "?" when the name is empty so the avatar never renders blank.
  static String _initialsFrom(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }
}

// -------- Section title --------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppTheme.textPrimary,
        letterSpacing: -0.4,
        height: 1.2,
      ),
    );
  }
}

// -------- Menu group (white rounded container holding items) --------

/// White rounded container that groups a cluster of menu items together.
/// Items inside are separated by hairline dividers so the group reads as
/// one surface, not three floating rows.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.borderSubtle,
                indent: 64,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

// -------- Single menu row --------

/// One row inside a [_MenuGroup]. Tinted icon disc, title + subtitle
/// in an Expanded column, trailing chevron. Same Row pattern as the
/// Home / Learn redesigns, with `Expanded` to keep text wrapped.
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppTheme.primary;
    return _Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: AppTheme.tintSurface),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 14),
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
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
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

// -------- Gradient logout button --------

/// Full-width logout CTA with a red-to-darker-red gradient. Same
/// Container+ElevatedButton(backgroundColor: transparent) pattern as
/// the Login / SignUp CTAs so the visual language of "primary action
/// on a card" stays consistent across the app. Red instead of the
/// brand gradient because logout is destructive — readers should
/// not confuse it with a brand-CTA like "Go Premium" or "Login".
class _GradientLogoutButton extends StatelessWidget {
  const _GradientLogoutButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // Destructive gradient built from the existing risk tokens
        // (riskHigh → riskCritical) so logout reads as the same
        // "danger family" the rest of the UI uses, and a future token
        // refresh propagates here too.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.riskHigh, // orange-600
            AppTheme.riskCritical, // red-700
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        boxShadow: [
          BoxShadow(
            color: AppTheme.riskCritical.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// -------- Pressable wrapper --------

/// Lightweight press-scale wrapper — identical 0.97 spring used on
/// Home / Check / Learn, so taps feel the same everywhere.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// -------- Settings sheet --------

/// Generic rounded modal sheet used by Notifications + Privacy.
/// Sits inside a `showModalBottomSheet` call; top corners rounded.
class _SettingsSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SettingsSheet({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle for affordance.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: AppTheme.tintSurface),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Body scrolls when the locale produces a long description
            // and the sheet is taller than the available half-screen.
            Flexible(
              child: SingleChildScrollView(child: child),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// -------- Language sheet bits --------

/// Triple of `(AppLocale, label, short-code)` used by [_showLanguage]
/// so we can iterate cleanly without a switch.
class _LanguageOption {
  const _LanguageOption(this.locale, this.label, this.short);
  final AppLocale locale;
  final String label;
  final String short;
}

/// Row in the Language picker sheet. 40×40 short-code disc on the left
/// (EN / BN), full label in the middle, trailing check or chevron
/// depending on whether this row is the active locale. Whole row is
/// tap-target so the user doesn't have to hit the label precisely.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.label,
    required this.short,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String short;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 12,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: AppTheme.tintSurface),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                short,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: selected ? accent : AppTheme.textSecondary,
              size: selected ? 22 : 20,
            ),
          ],
        ),
      ),
    );
  }
}

// -------- Privacy sheet bits --------

/// Visual variant for [_PrivacyActionButton]. Danger is the red family
/// used by the destructive buttons elsewhere (Logout); neutral is the
/// brand-tinted style used for non-destructive actions like
/// "Select items".
enum _PrivacyActionTone { danger, neutral }

/// Stacked row inside the Privacy sheet — tinted icon disc on the left,
/// label in the middle, chevron on the right. Same visual shape as
/// `_MenuItem` but with no `subtitle` slot (the Privacy sheet puts the
/// explanatory copy above the buttons, not inside them).
class _PrivacyActionButton extends StatelessWidget {
  const _PrivacyActionButton({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _PrivacyActionTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _PrivacyActionTone.danger => AppTheme.riskCritical,
      _PrivacyActionTone.neutral => AppTheme.primary,
    };
    return _Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: color.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: AppTheme.tintSurface),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.65),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}