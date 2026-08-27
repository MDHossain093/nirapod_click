import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../message_checker/message_checker_screen.dart';
import '../phone_checker/phone_checker_screen.dart';
import '../screenshot_scanner/screenshot_scanner_screen.dart';
import '../url_checker/url_checker_screen.dart';

/// Hub that lets the user pick which scanner to launch.
///
/// Reached via the bottom-nav "Check" tab or the home hero CTA. Each tile
/// pushes the corresponding scanner screen. Keeping this as a thin
/// dispatcher avoids shipping four big tiles on every other screen.
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
      body: ListView(
        // Bottom inset matches home so the last card isn't hidden behind
        // the bottom nav on short screens.
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
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

          _CheckTile(
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
          _CheckTile(
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
          _CheckTile(
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
          _CheckTile(
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
        ],
      ),
    );
  }
}

// -------- Reusable bits --------

/// Lightweight press-scale wrapper — same 0.97 spring used on home, so
/// taps feel identical across screens. Defined locally to avoid touching
/// any shared widget file.
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

/// Single scanner tile. Color-block style — matches the home Quick Check
/// tiles so the two screens feel like the same design system.
///
/// Layout is **stacked** (not a Row): icon disc up top, title + subtitle
/// pinned to the bottom. This eliminates any horizontal competition on
/// narrow phones and avoids the "Row right-overflowed by N pixels"
/// problem we hit on the home hero before the redesign.
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _Pressable(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.30),
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
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
      ),
    );
  }
}