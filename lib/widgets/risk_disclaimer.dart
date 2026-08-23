import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Small print at the bottom of every result screen. Reminds the user that
/// risk indicators are guidance, not guarantees.
///
/// Shared across [UrlCheckerScreen], [PhoneCheckerScreen],
/// [ScreenshotScannerScreen], [MessageCheckerScreen], and [RiskResultPage].
class RiskDisclaimer extends StatelessWidget {
  const RiskDisclaimer({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
