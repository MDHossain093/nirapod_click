import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Brand-gradient primary CTA used by every BDApps screen.
///
/// Same shape and feel as the auth login form's CTA — brand-gradient
/// fill (primary → secondary), white label, 52px tap target,
/// `radiusSm` corners. Wrapping the [ElevatedButton] in a [Container]
/// with `BoxDecoration(gradient: …)` lets the gradient show through
/// (the button itself is transparent so its `backgroundColor` /
/// `foregroundColor` never overrides the gradient).
///
/// When [busy] is true the label is replaced by a small white
/// `CircularProgressIndicator`. When [onPressed] is null the CTA
/// shows the disabled-but-still-visible state (white-70 label, no
/// shadow) rather than the default disabled style which would render
/// the button as a grey box that hides the gradient.
class BdappsGradientCta extends StatelessWidget {
  const BdappsGradientCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
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
            fontWeight: FontWeight.w600,
          ),
        ),
        child: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}
