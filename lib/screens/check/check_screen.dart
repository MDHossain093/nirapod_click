import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../message_checker/message_checker_screen.dart';
import '../phone_checker/phone_checker_screen.dart';
import '../screenshot_scanner/screenshot_scanner_screen.dart';
import '../url_checker/url_checker_screen.dart';

/// Hub that lets the user pick which scanner to launch.
///
/// Reached via the bottom-nav "Check" tab. Each card pushes the
/// corresponding scanner screen. Keeping this as a thin dispatcher avoids
/// shipping four big tiles on every other screen.
class CheckScreen extends StatelessWidget {
  const CheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('check.appBarTitle')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            t('check.heading'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t('check.subheading'),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          _checkCard(
            context,
            icon: Icons.message_outlined,
            title: t('check.messageTitle'),
            subtitle: t('check.messageSubtitle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MessageCheckerScreen(),
                ),
              );
            },
          ),
          _checkCard(
            context,
            icon: Icons.link_rounded,
            title: t('check.urlTitle'),
            subtitle: t('check.urlSubtitle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UrlCheckerScreen(),
                ),
              );
            },
          ),
          _checkCard(
            context,
            icon: Icons.image_outlined,
            title: t('check.screenshotTitle'),
            subtitle: t('check.screenshotSubtitle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ScreenshotScannerScreen(),
                ),
              );
            },
          ),
          _checkCard(
            context,
            icon: Icons.phone_outlined,
            title: t('check.phoneTitle'),
            subtitle: t('check.phoneSubtitle'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PhoneCheckerScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _checkCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
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
}