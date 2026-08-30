import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/pressable.dart';
import '../message_checker/message_checker_screen.dart';
import '../phone_checker/phone_checker_screen.dart';
import '../qr_checker/qr_checker_screen.dart';
import '../screenshot_scanner/screenshot_scanner_screen.dart';
import '../url_checker/url_checker_screen.dart';

/// Hub that lets the user pick which scanner to launch.
///
/// Reached via the bottom-nav "Check" tab or the home hero CTA. The
/// top of the screen renders a 2x2 grid of the four primary
/// scanners (Message / URL / Screenshot / Phone) so the user never
/// has to scroll to find the most common tile. A fifth tile — the
/// QR Code scanner — sits in its own full-width row below the grid
/// because (a) it requires a distinct affordance (camera permission
/// prompt) and (b) at 168 px a 3x2 grid would shrink every tile
/// below the comfortable 44 px tap target on narrow phones.
///
/// Visual language matches the home screen's bold-editorial style:
/// color-block tiles, big tagline-style heading, brand-tinted shadows.
/// No business logic lives here — all four tiles just `Navigator.push`
/// the existing checker screens.
class CheckScreen extends StatelessWidget {
  const CheckScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('check.appBarTitle')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
          ),
        ),
      ),
      body: SingleChildScrollView(
        // Wrapped in a scroll view so the 5th tile (QR) doesn't
        // overflow on short screens — at 168-px tile height + the
        // heading + subheading, content can exceed the viewport on
        // 320×568 phones. The grid is still scroll-free for the
        // common case; scrolling only kicks in when needed.
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tagline-style heading, matches home's 32 / w800 / -0.6
            // letter-spacing treatment so both screens feel like one app.
            Text(
              t('check.heading'),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                height: 1.15,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('check.subheading'),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            // Fixed 168-px tile height — keeps the grid deterministic
            // across devices without paying for IntrinsicHeight.
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 168,
                    child: _CheckTile(
                      icon: Icons.mark_email_read_rounded,
                      title: t('check.messageTitle'),
                      subtitle: t('check.messageSubtitle'),
                      color: AppTheme.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MessageCheckerScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 168,
                    child: _CheckTile(
                      icon: Icons.link_rounded,
                      title: t('check.urlTitle'),
                      subtitle: t('check.urlSubtitle'),
                      color: AppTheme.secondary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UrlCheckerScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 168,
                    child: _CheckTile(
                      icon: Icons.document_scanner_rounded,
                      title: t('check.screenshotTitle'),
                      subtitle: t('check.screenshotSubtitle'),
                      color: AppTheme.accent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScreenshotScannerScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 168,
                    child: _CheckTile(
                      icon: Icons.phone_rounded,
                      title: t('check.phoneTitle'),
                      subtitle: t('check.phoneSubtitle'),
                      color: AppTheme.danger,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PhoneCheckerScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // QR scanner sits in its own full-width row. Same
            // 168-px tile height as the 2x2 tiles for visual
            // rhythm; the wider footprint gives the longer
            // "Scan a QR with your camera" subtitle room to
            // breathe without truncating.
            SizedBox(
              width: double.infinity,
              height: 168,
              child: _CheckTile(
                icon: Icons.qr_code_scanner_rounded,
                title: t('check.qrTitle'),
                subtitle: t('check.qrSubtitle'),
                color: AppTheme.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QrCheckerScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------- Reusable bits --------

/// Single scanner tile. Color-block style matches the home hero
/// tiles so both screens read as one design system.
///
/// Layout is **stacked** (not a Row): icon disc up top, title +
/// subtitle pinned to the bottom. Avoids horizontal competition on
/// narrow phones.
class _CheckTile extends StatelessWidget {
  const _CheckTile({
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
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: AppTheme.tintBorderStrong),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppTheme.radiusXs),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}