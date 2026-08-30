import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Layout scaffold shared by LoginPage and SignUpPage.
///
/// Below 900px (most phones in portrait, tablets in portrait) we render
/// a single stacked column: the screen's [mobileHeader] on top and the
/// [formPanel] below it.
///
/// At 900px and above (landscape phones, tablets, desktop web) we
/// render a two-column layout: the gradient [AuthBrandPanel] on the
/// left as the marketing anchor, and the [formPanel] on the right over
/// the standard `#F7F9FC` background. No card wrapping on the right
/// — the white surface is the scaffold itself, matching the user's
/// "white-on-white" intent.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.formPanel,
    required this.mobileHeader,
  });

  /// Form content shared between both layouts. The screen passes a
  /// widget that already includes the AuthTrustFooter at the bottom.
  final Widget formPanel;

  /// Header shown only on the narrow layout. Login uses a compact
  /// shield + tagline hero; SignUp uses a back-arrow AppBar.
  final Widget mobileHeader;

  static const double wideBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scaffold is the standard #F7F9FC; the left gradient panel
      // paints its own background so the form side stays light.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= wideBreakpoint) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(
                    flex: 5,
                    child: AuthBrandPanel(),
                  ),
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 32,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: formPanel,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                mobileHeader,
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: formPanel,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Gradient left panel shown on wide screens. Communicates the brand
/// promise ("Stay one step ahead of online scams.") and surfaces the
/// three core product features in icon+text rows.
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.brandHeaderGradient),
      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand mark — same `logo_full.png` asset used by the splash
          // and Premium screens so the brand reads identically across
          // every branded surface. Sized at 48px height to match the
          // visual weight of the previous shield + wordmark row.
          // `errorBuilder` falls back to a generic shield if the asset
          // is missing on a desktop build flavor.
          Image.asset(
            'assets/logo_full.png',
            height: 48,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Row(
              children: const [
                Icon(Icons.shield_outlined,
                    size: 36, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'NirapodClick',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          const Text(
            'Stay one step ahead\nof online scams.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'ক্লিক করার আগে যাচাই করুন।',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          const _FeatureRow(
            icon: Icons.chat_bubble_outline,
            label: 'Message checking',
          ),
          const SizedBox(height: 16),
          const _FeatureRow(
            icon: Icons.link,
            label: 'Link verification',
          ),
          const SizedBox(height: 16),
          const _FeatureRow(
            icon: Icons.photo_camera_outlined,
            label: 'Screenshot analysis',
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusXs),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}