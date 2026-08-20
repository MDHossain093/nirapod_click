import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// User-facing selection on the NirapodClick "Copy report" surface.
///
/// Two-state only — EN or BN. The toggle flips the global app locale so
/// the rest of the UI follows the same pick.
enum CopyLanguage { english, bangla }

/// Two-state pill toggle for the report copy language.
///
/// Lets the user pick English or Bangla before they copy or share the
/// NirapodClick risk report. Built as a compact pill so it fits
/// comfortably in an app bar `actions:` slot or on the home dashboard.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Current selection.
  final CopyLanguage value;

  final ValueChanged<CopyLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    const entries = <_Entry>[
      _Entry(CopyLanguage.english, 'EN', 'English'),
      _Entry(CopyLanguage.bangla, 'BN', 'Bangla'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in entries) _pill(e),
        ],
      ),
    );
  }

  Widget _pill(_Entry e) {
    final selected = e.language == value;
    return GestureDetector(
      onTap: () => onChanged(e.language),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          e.short,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Entry {
  const _Entry(this.language, this.short, this.tooltip);
  final CopyLanguage language;
  final String short;
  final String tooltip;
}
