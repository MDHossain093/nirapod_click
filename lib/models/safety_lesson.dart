import '../core/locale/app_locale.dart';

/// A single self-contained safety lesson displayed in the Learn Center.
///
/// Lessons are stored as plain Dart consts in `lib/data/safety_lessons.dart`
/// so they ship with the app (no Gemini, no Firebase — zero runtime cost).
///
/// Every translatable string has both English and Bangla variants baked in
/// so the Learn tab works offline in both languages without a remote
/// translation service.
class SafetyLesson {
  /// Stable identifier — also used as a deep-link slug later.
  final String id;

  /// Short headline shown on the lesson card and the detail AppBar.
  final String titleEn;
  final String titleBn;

  /// One-line subtitle shown directly under the title.
  final String subtitleEn;
  final String subtitleBn;

  /// Category label, e.g. "Payments", "Links", "Jobs", "Scams", "Social Media".
  final String categoryEn;
  final String categoryBn;

  /// Single emoji rendered inside the rounded badge (kept as a string so it
  /// renders identically across platforms without needing an icon font).
  final String icon;

  /// Estimated reading time, in minutes — shown on the card.
  final int minutes;

  /// Ordered list of body sections. Each section renders one heading + one
  /// paragraph + a checklist of tips.
  final List<LessonSection> sections;

  const SafetyLesson({
    required this.id,
    required this.titleEn,
    required this.titleBn,
    required this.subtitleEn,
    required this.subtitleBn,
    required this.categoryEn,
    required this.categoryBn,
    required this.icon,
    required this.minutes,
    required this.sections,
  });

  // ---- Localized accessors -------------------------------------------------
  //
  // The legacy single-locale getters are kept so older callers (and tests)
  // continue to compile. New code should read `titleFor(locale)` etc. so the
  // string follows the user's current language toggle.
  String get title => titleEn;
  String get subtitle => subtitleEn;
  String get category => categoryEn;
  String titleFor(AppLocale locale) =>
      locale == AppLocale.bangla ? titleBn : titleEn;
  String subtitleFor(AppLocale locale) =>
      locale == AppLocale.bangla ? subtitleBn : subtitleEn;
  String categoryFor(AppLocale locale) =>
      locale == AppLocale.bangla ? categoryBn : categoryEn;
}

/// One block of a lesson — heading + body text + a checklist of tips.
///
/// Every translatable field has both English and Bangla variants.
class LessonSection {
  final String titleEn;
  final String titleBn;
  final String contentEn;
  final String contentBn;
  final List<String> tipsEn;
  final List<String> tipsBn;

  const LessonSection({
    required this.titleEn,
    required this.titleBn,
    required this.contentEn,
    required this.contentBn,
    required this.tipsEn,
    required this.tipsBn,
  });

  String get title => titleEn;
  String get content => contentEn;
  List<String> get tips => tipsEn;
  String titleFor(AppLocale locale) =>
      locale == AppLocale.bangla ? titleBn : titleEn;
  String contentFor(AppLocale locale) =>
      locale == AppLocale.bangla ? contentBn : contentEn;
  List<String> tipsFor(AppLocale locale) =>
      locale == AppLocale.bangla ? tipsBn : tipsEn;
}
