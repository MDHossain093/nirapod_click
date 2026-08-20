import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';

/// Temporary placeholder for the real URL-checker screen.
///
/// The home dashboard navigates here when the user taps "Check Link".
/// The full screen (URL input → link analysis → result) will replace
/// this file in a later step. Strings already flow through the global
/// locale so the same view will Bangla-flip with the rest of the app.
class UrlCheckerScreen extends StatelessWidget {
  const UrlCheckerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(t('urlChecker.title'))),
      body: Center(
        child: Text(
          t('urlChecker.body'),
          style: const TextStyle(
            fontSize: 18,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
