import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Soft amber banner shown when the AI fallback path failed and the
/// displayed verdict was produced by the local rule engine.
///
/// Shared across [UrlCheckerScreen], [ScreenshotScannerScreen], and
/// [RiskResultPage] so the message, colors, and shape stay identical.
class AiUnavailableBanner extends StatelessWidget {
  const AiUnavailableBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.amberBannerBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.amberBannerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.amberBannerIcon,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
