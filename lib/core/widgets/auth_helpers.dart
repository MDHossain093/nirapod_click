import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small red banner shown beneath the primary submit button when an
/// auth request fails. Keeps the error visible (no scrolling) so the
/// user can read it without losing context.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.riskCritical.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        border: Border.all(
          color: AppTheme.riskCritical.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              color: AppTheme.riskCritical, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.riskCritical,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal rule with "OR" centered between two segments. Used to
/// separate the primary email/password submit from the Google button.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppTheme.borderSubtle)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppTheme.borderSubtle)),
      ],
    );
  }
}

/// Small "Your privacy and safety matter to us." line that closes the
/// bottom of every auth screen. Uses a shield icon in primary navy so
/// it reads as a brand reassurance, not a generic disclaimer.
class AuthTrustFooter extends StatelessWidget {
  const AuthTrustFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined,
            size: 14, color: AppTheme.textSecondary.withValues(alpha: 0.8)),
        const SizedBox(width: 6),
        Text(
          'Your privacy and safety matter to us.',
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}