import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// User's plan tier — surfaced as a read-only status badge in the
/// home header (top-right corner, next to the EN/BN language toggle).
///
/// We don't expose a switch on this badge: changing the plan happens
/// through the Premium screen (`PremiumScreen`) so the user always
/// sees the full benefits + payment surface, not a 1-tap flip.
/// Tapping the badge on the home header just routes to the Premium
/// screen as a convenience for free users who want to upgrade.
enum HeaderPlan { free, premium }

/// Read-only plan-status pill that lives in the home header.
///
/// Visually mirrors the [LanguageToggle] next to it so the two
/// badges read as a pair — same outline pill, same selected-pill
/// proportions, same typography. The pill is non-interactive (no
/// GestureDetector) because it's a status indicator, not a switch.
class HeaderPlanBadge extends StatelessWidget {
  const HeaderPlanBadge({
    super.key,
    required this.plan,
    this.onTap,
  });

  /// Which plan tier the user is currently on. Drives both the
  /// label ("FREE" / "PREMIUM") and the colour.
  final HeaderPlan plan;

  /// Optional callback. The home page wires this to
  /// `Navigator.push(PremiumScreen)` so free users can tap the badge
  /// to start upgrading. Premium users leave it null (no action).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isPremium = plan == HeaderPlan.premium;
    final label = isPremium ? 'PREMIUM' : 'FREE';
    final color = isPremium ? AppTheme.success : AppTheme.textSecondary;

    final pill = Container(
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          // Selected pill. We tint it with the plan colour so the
          // FREE pill looks neutral and the PREMIUM pill picks up
          // the success-tinted treatment that already signals
          // "premium" elsewhere in the app (subscription chip,
          // active-badge on the premium screen).
          color: isPremium
              ? AppTheme.success.withValues(alpha: AppTheme.tintSurface)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: isPremium
              ? Border.all(color: AppTheme.success.withValues(alpha: 0.30))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPremium
                  ? Icons.verified_rounded
                  : Icons.lock_clock_rounded,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return pill;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: pill,
    );
  }
}
