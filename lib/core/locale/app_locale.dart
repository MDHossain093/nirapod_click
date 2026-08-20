import 'package:flutter/material.dart';

/// Available UI languages for the NirapodClick app.
enum AppLocale { english, bangla }

/// Inherited translator. Wrap the app in [LocaleScope] at the root,
/// then read translations from any descendant via
/// `AppLocaleScope.of(context).tr(key)`.
class AppLocaleScope extends InheritedWidget {
  const AppLocaleScope({
    super.key,
    required this.locale,
    required this.onChanged,
    required super.child,
  });

  /// Currently selected UI language.
  final AppLocale locale;

  /// Called when the user picks a different language from the toggle.
  final ValueChanged<AppLocale> onChanged;

  /// Shorthand for `AppLocaleScope.of(context)`.
  static AppLocaleScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
    assert(scope != null, 'AppLocaleScope is missing from the widget tree');
    return scope!;
  }

  /// Picks the translation for [key] in the current [locale].
  /// Falls back to English and finally to the key itself so a missing
  /// translation never crashes the UI.
  String tr(String key) {
    final entry = _translations[key];
    if (entry == null) return key;
    switch (locale) {
      case AppLocale.english:
        return entry.en;
      case AppLocale.bangla:
        return entry.bn;
    }
  }

  @override
  bool updateShouldNotify(AppLocaleScope oldWidget) =>
      locale != oldWidget.locale;
}

class _Entry {
  const _Entry(this.en, this.bn);
  final String en;
  final String bn;
}

/// Centralised translation table. Keep English as the source of truth;
/// Bangla falls back to the English string when a key is missing.
const Map<String, _Entry> _translations = {
  // -- App --
  'app.title': _Entry('NirapodClick', 'নিরাপদ ক্লিক'),
  'app.tagline': _Entry('Stay safe online', 'অনলাইনে নিরাপদ থাকুন'),

  // -- Greeting --
  'home.greeting': _Entry('Good Morning,', 'শুভ সকাল,'),
  'home.greetingFallback': _Entry('there', 'আপনি'),

  // -- Safety score --
  'home.safetyScore': _Entry('Your Safety Score', 'আপনার নিরাপত্তা স্কোর'),
  'home.safetyScoreValue': _Entry('82 / 100', '৮২ / ১০০'),
  'home.safetyStatus': _Entry('🟢 You are safe', '🟢 আপনি নিরাপদ আছেন'),
  'home.viewSafetyReport': _Entry(
    'View Safety Report',
    'নিরাপত্তা রিপোর্ট দেখুন',
  ),
  'home.safetyReportSoon': _Entry(
    'Safety report coming soon.',
    'নিরাপত্তা রিপোর্ট শীঘ্রই আসছে।',
  ),

  // -- Section titles --
  'home.section.check': _Entry(
    'What do you want to check?',
    'আপনি কী যাচাই করতে চান?',
  ),
  'home.section.scamAlert': _Entry('Latest Scam Alert', 'সর্বশেষ প্রতারণা সতর্কতা'),
  'home.section.learn': _Entry('Learn to Stay Safe', 'নিরাপদ থাকতে শিখুন'),
  'home.section.learnSubtitle': _Entry(
    'Learn how to identify common online scams.',
    'সাধারণ অনলাইন প্রতারণা চিনতে শিখুন।',
  ),

  // -- Scanner tiles --
  'home.tile.message.title': _Entry('Check Message', 'বার্তা যাচাই করুন'),
  'home.tile.message.subtitle': _Entry('SMS & chats', 'এসএমএস ও চ্যাট'),
  'home.tile.link.title': _Entry('Check Link', 'লিংক যাচাই করুন'),
  'home.tile.link.subtitle': _Entry('Website URLs', 'ওয়েবসাইট URL'),
  'home.tile.screenshot.title': _Entry('Scan Screenshot', 'স্ক্রিনশট স্ক্যান করুন'),
  'home.tile.screenshot.subtitle':
      _Entry('Analyze images', 'ছবি বিশ্লেষণ করুন'),
  'home.tile.number.title': _Entry('Check Number', 'নম্বর যাচাই করুন'),
  'home.tile.number.subtitle': _Entry('Phone reports', 'ফোন রিপোর্ট'),

  // -- Snackbar / system --
  'home.noAlerts': _Entry('No new alerts.', 'নতুন সতর্কতা নেই।'),
  'home.screenshotSoon': _Entry(
    'Screenshot scanner is coming soon.',
    'স্ক্রিনশট স্ক্যানার শীঘ্রই আসছে।',
  ),
  'home.numberSoon': _Entry(
    'Phone number lookup is coming soon.',
    'ফোন নম্বর অনুসন্ধান শীঘ্রই আসছে।',
  ),
  'home.scamAlertsSoon': _Entry(
    'Scam alerts list coming soon.',
    'প্রতারণা সতর্কতা তালিকা শীঘ্রই আসছে।',
  ),
  'home.copiedEn': _Entry(
    'English report copied to clipboard',
    'ইংরেজি রিপোর্ট ক্লিপবোর্ডে কপি হয়েছে',
  ),
  'home.copiedBn': _Entry(
    'Bangla report copied to clipboard',
    'বাংলা রিপোর্ট ক্লিপবোর্ডে কপি হয়েছে',
  ),
  'home.signOut': _Entry('Sign out', 'সাইন আউট'),

  // -- Bottom nav --
  'nav.home': _Entry('Home', 'হোম'),
  'nav.history': _Entry('History', 'ইতিহাস'),
  'nav.learn': _Entry('Learn', 'শিখুন'),
  'nav.profile': _Entry('Profile', 'প্রোফাইল'),

  // -- Message checker placeholder body --
  'messageChecker.title': _Entry('Check Message', 'বার্তা যাচাই করুন'),
  'messageChecker.body': _Entry('Message Checker', 'বার্তা যাচাইকারী'),
  'messageChecker.demoLang': _Entry(
    'Report language: ',
    'রিপোর্টের ভাষা: ',
  ),

  // -- URL checker placeholder body --
  'urlChecker.title': _Entry('Check Link', 'লিংক যাচাই করুন'),
  'urlChecker.body': _Entry('URL Checker', 'URL যাচাইকারী'),
};
