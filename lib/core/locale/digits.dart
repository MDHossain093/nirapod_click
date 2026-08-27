import 'app_locale.dart';

/// Pure-Dart digit-localization helpers.
///
/// The Bangla locale uses ০-৯ instead of 0-9 (Unicode U+0660–U+0669,
/// the Eastern Arabic-Indic digit block that's also the standard
/// for Bengali/Bangla). This module is the single source of truth for
/// converting ASCII-digit numbers into their localized form for UI
/// display.
///
/// Two consumers exist:
///   - Widgets call `AppLocaleScope.of(context).formatNumber(...)` so
///     the value tracks the user's current language toggle.
///   - Pure-Dart code (engines, clipboard builder, AI service, log
///     lines) calls `Localizer.instance.formatNumber(...)`.
///
/// Both delegate to [toLocalizedDigits] / [toLocalizedPercent] here so
/// the digit table exists in exactly one place.

/// ASCII '0'..'9' → Bangla '০'..'৯'.
///
/// Used for the Bangla locale only — English returns the input
/// untouched. We deliberately don't handle Arabic-Indic / Devanagari /
/// Thai / Burmese etc. because the app only ships two locales today;
/// adding more later is a one-line change in [toLocalizedDigits].
const String _bnDigits = '০১২৩৪৫৬৭৮৯';

/// Convert an ASCII-digit string into the localized form for [locale].
///
/// Pass any non-negative integer or `toString()`-able number. Returns
/// the input unchanged for [AppLocale.english]. Strings without any
/// digits pass through verbatim (preserves phone numbers, slashes,
/// spaces).
String toLocalizedDigits(Object value, AppLocale locale) {
  if (locale == AppLocale.english) return value.toString();

  final raw = value.toString();
  final buffer = StringBuffer();
  for (final ch in raw.split('')) {
    final code = ch.codeUnitAt(0);
    if (code >= 0x30 && code <= 0x39) {
      // '0'..'9' → bnDigits[code - 0x30]
      buffer.write(_bnDigits[code - 0x30]);
    } else {
      buffer.write(ch);
    }
  }
  return buffer.toString();
}

/// Format an integer with locale-appropriate digits. The integer type
/// keeps call-sites concise (`formatInt(score, locale)`) without each
/// one doing the `.toString()` themselves.
String formatInt(int value, AppLocale locale) =>
    toLocalizedDigits(value, locale);

/// Format a 0..1 confidence as a localized percentage with the `%`
/// suffix and zero decimal places (e.g. `0.85` → `"৮৫%"` for Bangla,
/// `"85%"` for English).
String formatPercent(double value, AppLocale locale) {
  final pct = (value * 100).round();
  return '${toLocalizedDigits(pct, locale)}%';
}

/// Format a risk score as `"<n> / 100"` with localized digits and the
/// fixed English denominator. Used by every checker result card —
/// keeping the `" / 100"` constant in one place means future tweaks
/// (e.g. switching to a Bangla "১০০") only need this edit.
///
/// `denominator` defaults to 100 but is overridable so the helper also
/// covers things like `score / 82` if we ever switch away from the
/// 0..100 scale.
String formatScore(int score, AppLocale locale, {int denominator = 100}) {
  return '${toLocalizedDigits(score, locale)} / '
      '${toLocalizedDigits(denominator, locale)}';
}
