import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../history/history_page.dart';
import '../learn/learn_screen.dart';
import '../subscription/subscription_status_card.dart';

/// Profile + Settings hub.
///
/// Sections:
///   1. Account information (name + email + avatar circle)
///   2. Your Activity      - Scan History, Safety Learning
///   3. Settings           - Notifications, Privacy  (modal sheets)
///   4. Account            - Log Out (with confirm dialog)
///
/// All user-facing text flows through [AppLocaleScope] so EN/BN stay in sync.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final user = FirebaseAuth.instance.currentUser;

    final displayName =
        user?.displayName?.trim().isNotEmpty == true
            ? user!.displayName!
            : t('profile.fallbackName');

    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('profile.appBarTitle')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildProfileHeader(displayName, email),

          const SizedBox(height: 16),

          const SubscriptionStatusCard(),

          const SizedBox(height: 24),

          _buildSectionTitle(t('profile.sectionActivity')),

          const SizedBox(height: 10),

          _buildMenuItem(
            context,
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

          _buildMenuItem(
            context,
            icon: Icons.school_outlined,
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

          const SizedBox(height: 24),

          _buildSectionTitle(t('profile.sectionSettings')),

          const SizedBox(height: 10),

          _buildMenuItem(
            context,
            icon: Icons.notifications_outlined,
            title: t('profile.menuNotificationsTitle'),
            subtitle: t('profile.menuNotificationsSubtitle'),
            onTap: () => _showNotifications(context),
          ),

          _buildMenuItem(
            context,
            icon: Icons.privacy_tip_outlined,
            title: t('profile.menuPrivacyTitle'),
            subtitle: t('profile.menuPrivacySubtitle'),
            onTap: () => _showPrivacy(context),
          ),

          const SizedBox(height: 24),

          _buildSectionTitle(t('profile.sectionAccount')),

          const SizedBox(height: 10),

          _buildMenuItem(
            context,
            icon: Icons.logout_rounded,
            title: t('profile.menuLogoutTitle'),
            subtitle: t('profile.menuLogoutSubtitle'),
            isDanger: true,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- header

  Widget _buildProfileHeader(String name, String email) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 34,
              color: AppTheme.primary,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- pieces

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final color = isDanger ? AppTheme.danger : AppTheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDanger
                              ? AppTheme.danger
                              : AppTheme.textPrimary,
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
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- actions

  void _showNotifications(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return _SettingsSheet(
          title: t('profile.menuNotificationsTitle'),
          icon: Icons.notifications_outlined,
          child: Text(
            t('profile.notificationsBody'),
            style: const TextStyle(
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
        );
      },
    );
  }

  void _showPrivacy(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return _SettingsSheet(
          title: t('profile.menuPrivacyTitle'),
          icon: Icons.privacy_tip_outlined,
          child: Text(
            t('profile.privacyBody'),
            style: const TextStyle(
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
        );
      },
    );
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
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(t('profile.logoutConfirm')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

/// Generic rounded modal sheet used by Notifications + Privacy.
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}