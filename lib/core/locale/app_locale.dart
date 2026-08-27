import 'package:flutter/material.dart';

import 'digits.dart' as digits;
import 'localizer.dart';

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
  bool updateShouldNotify(AppLocaleScope oldWidget) {
    // Keep the context-free Localizer singleton in sync with the
    // widget-tree locale so pure-Dart engines (RiskEngine,
    // UrlRiskEngine, PhoneRiskEngine, AiService) emit Bangla strings
    // when the user has picked Bangla. Engines don't have access to
    // a BuildContext, so they read through Localizer.instance.tr()
    // instead of the InheritedWidget.
    if (locale != oldWidget.locale) {
      Localizer.instance.setLocale(locale);
      return true;
    }
    return false;
  }

  /// Format a number with locale-appropriate digits.
  ///
  /// Widget-tree-aware sibling of [Localizer.formatNumber]. Call
  /// sites that already have a [BuildContext] should prefer this so
  /// the digits track the [AppLocaleScope] the screen is wrapped in
  /// (which is also the source of truth used by [tr]).
  ///
  /// Both helpers delegate to [digits.formatInt] so the digit table
  /// lives in exactly one place.
  String formatNumber(num value) => digits.formatInt(value.toInt(), locale);

  /// `value * 100`, rounded, with localized digits and a `%` suffix.
  String formatPercent(double value) => digits.formatPercent(value, locale);

  /// `<n> / <denominator>` with localized digits. Defaults to the
  /// 0..100 risk-score scale.
  String formatScore(int score, {int denominator = 100}) =>
      digits.formatScore(score, locale, denominator: denominator);
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

  // -- Generic --
  'common.cancel': _Entry('Cancel', 'বাতিল'),
  'common.close': _Entry('Close', 'বন্ধ করুন'),

  // -- Greeting --
  // Time-of-day variants keyed off the local hour. The home header
  // picks one of these in [HomePage._greetingFor] so "Good Morning"
  // never leaks into the evening.
  'home.greeting.morning': _Entry('Good Morning,', 'শুভ সকাল,'),
  'home.greeting.afternoon': _Entry('Good Afternoon,', 'শুভ দুপুর,'),
  'home.greeting.evening': _Entry('Good Evening,', 'শুভ সন্ধ্যা,'),
  'home.greeting.night': _Entry('Good Night,', 'শুভ রাত্রি,'),
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

  // -- Home safety-score card (post-redesign) --
  // Replaces the per-tile "X left today" count with a single
  // dashboard widget that aggregates the user's recent scans.
  'home.safetyScoreCard.title': _Entry(
    'Your Safety Score',
    'আপনার নিরাপত্তা স্কোর',
  ),
  'home.safetyScoreCard.subtitle': _Entry(
    'Based on your last 30 days of scans',
    'গত ৩০ দিনের স্ক্যানের ভিত্তিতে',
  ),
  'home.safetyScoreCard.last30Days': _Entry(
    'Last 30 days',
    'গত ৩০ দিন',
  ),
  'home.safetyScoreCard.emptyTitle': _Entry(
    'No scans yet',
    'এখনো কোনো স্ক্যান নেই',
  ),
  'home.safetyScoreCard.emptyBody': _Entry(
    'Run your first check to start tracking your safety score.',
    'আপনার নিরাপত্তা স্কোর ট্র্যাক করতে প্রথম যাচাই চালান।',
  ),
  'home.safetyScoreCard.emptyCta': _Entry(
    'Run your first check',
    'প্রথম যাচাই চালান',
  ),
  'home.safetyScoreCard.viewDetails': _Entry(
    'View details',
    'বিস্তারিত দেখুন',
  ),
  'home.safetyScoreCard.status.excellent': _Entry(
    'Excellent',
    'চমৎকার',
  ),
  'home.safetyScoreCard.status.good': _Entry(
    'Good',
    'ভালো',
  ),
  'home.safetyScoreCard.status.fair': _Entry(
    'Fair',
    'মোটামুটি',
  ),
  'home.safetyScoreCard.status.poor': _Entry(
    'Needs attention',
    'মনোযোগ দরকার',
  ),
  'home.safetyScoreCard.status.critical': _Entry(
    'Critical',
    'গুরুতর',
  ),
  'home.safetyScoreCard.stat.critical': _Entry(
    'Critical',
    'গুরুতর',
  ),
  'home.safetyScoreCard.stat.high': _Entry(
    'High',
    'উচ্চ',
  ),
  'home.safetyScoreCard.stat.medium': _Entry(
    'Medium',
    'মাঝারি',
  ),
  'home.safetyScoreCard.stat.safe': _Entry(
    'Safe',
    'নিরাপদ',
  ),
  'home.safetyScoreCard.runCheck': _Entry(
    'Run a check',
    'যাচাই চালান',
  ),
  'home.safetyScoreCard.runCheckSubtitle': _Entry(
    'Message, link, screenshot or phone number',
    'বার্তা, লিংক, স্ক্রিনশট বা ফোন নম্বর',
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
  'home.screenshotSoon': _Entry(
    'Screenshot scanner is coming soon.',
    'স্ক্রিনশট স্ক্যানার শীঘ্রই আসছে।',
  ),
  'home.numberSoon': _Entry(
    'Phone number lookup is coming soon.',
    'ফোন নম্বর অনুসন্ধান শীঘ্রই আসছে।',
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

  // -- Redesign 2026: subscription chip, scan counts, premium banner --
  'home.scansLeftShort': _Entry(
    '{count} left today',
    'আজ {count}টি বাকি',
  ),
  'home.scansUnlimited': _Entry('Unlimited', 'আনলিমিটেড'),
  'home.premiumActiveChip': _Entry('✨ Premium active', '✨ প্রিমিয়াম সক্রিয়'),

  // -- Header plan badge + "X of 5 free checks" inline --
  // The plan badge sits in the top-right of the header next to the
  // EN/BN language toggle and is read-only — tapping it doesn't do
  // anything (it's a status, not a switch). The free-checks line
  // sits under the "Stay safe online" tagline and shows how many of
  // the monthly 5-check budget the user has consumed.
  'home.headerPlan.free': _Entry('FREE', 'ফ্রি'),
  'home.headerPlan.premium': _Entry('PREMIUM', 'প্রিমিয়াম'),
  'home.headerQuota.inline': _Entry(
    '{used} of 5 free checks used this month',
    'এই মাসে {used} / ৫টি ফ্রি যাচাই ব্যবহৃত',
  ),
  'home.headerQuota.inlineFresh': _Entry(
    '5 of 5 free checks left this month',
    'এই মাসে ৫ / ৫টি ফ্রি যাচাই বাকি',
  ),
  'home.headerQuota.unlimited': _Entry(
    'Unlimited checks · Premium',
    'আনলিমিটেড যাচাই · প্রিমিয়াম',
  ),
  'home.recentScansEmptyHint': _Entry(
    'Tap a Quick Check above to run your first scan.',
    'আপনার প্রথম স্ক্যান করতে উপরের যেকোনো চেক ব্যবহার করুন।',
  ),
  'home.goPremiumBanner.title': _Entry(
    'Get unlimited scans',
    'আনলিমিটেড স্ক্যান নিন',
  ),
  'home.goPremiumBanner.subtitle': _Entry(
    'Unlock every checker for just ৳2.78 / day.',
    'মাত্র ৳২.৭৮ / দিনে সব চেকার আনলক করুন।',
  ),
  'home.goPremiumBanner.cta': _Entry('✨ Go Premium', '✨ প্রিমিয়ামে যান'),
  'home.subscriptionBanner.dismiss': _Entry('Dismiss', 'বন্ধ করুন'),

  // -- Bottom nav --
  'nav.home': _Entry('Home', 'হোম'),
  'nav.check': _Entry('Check', 'যাচাই'),
  'nav.history': _Entry('History', 'ইতিহাস'),
  'nav.learn': _Entry('Learn', 'শিখুন'),
  'nav.profile': _Entry('Profile', 'প্রোফাইল'),

  // -- History page --
  'history.appBarTitle': _Entry('Scan History', 'স্ক্যান ইতিহাস'),
  'history.emptyTitle': _Entry('No scans yet', 'এখনো কোনো স্ক্যান নেই'),
  'history.emptyBody': _Entry(
    'Your previous checks will appear here.',
    'আপনার আগের চেকগুলো এখানে দেখা যাবে।',
  ),
  'history.clearAction': _Entry('Clear', 'মুছুন'),
  'history.clearDialogTitle': _Entry('Clear all history?', 'সব ইতিহাস মুছবেন?'),
  'history.clearDialogBody': _Entry(
    'This will permanently delete every saved scan. This action cannot be undone.',
    'এটি সংরক্ষিত প্রতিটি স্ক্যান স্থায়ীভাবে মুছে ফেলবে। এই কাজটি ফিরিয়ে আনা যাবে না।',
  ),
  'history.clearConfirm': _Entry('Delete all', 'সব মুছুন'),
  'history.cancel': _Entry('Cancel', 'বাতিল'),
  'history.typeMessage': _Entry('Message', 'বার্তা'),
  'history.typeUrl': _Entry('URL', 'লিংক'),
  'history.typeScreenshot': _Entry('Screenshot', 'স্ক্রিনশট'),
  'history.typePhone': _Entry('Phone', 'ফোন'),
  'history.clearedToast': _Entry(
    'History cleared',
    'ইতিহাস মুছে ফেলা হয়েছে',
  ),

  // -- Alerts screen --
  'alerts.appBarTitle': _Entry('Safety Alerts', 'নিরাপত্তা সতর্কতা'),
  'alerts.emptyTitle': _Entry(
    'No critical alerts',
    'কোনো গুরুতর সতর্কতা নেই',
  ),
  'alerts.emptyBody': _Entry(
    'Scans with a high risk score and confidence will appear here.',
    'উচ্চ ঝুঁকির স্কোর ও আত্মবিশ্বাস সহ স্ক্যানগুলো এখানে দেখা যাবে।',
  ),
  'alerts.group.today': _Entry('Today', 'আজ'),
  'alerts.group.yesterday': _Entry('Yesterday', 'গতকাল'),
  'alerts.group.earlierThisWeek': _Entry(
    'Earlier this week',
    'এই সপ্তাহের আগে',
  ),
  'alerts.group.earlier': _Entry('Earlier', 'আগে'),
  'alerts.viewScan': _Entry('View scan', 'স্ক্যান দেখুন'),
  'alerts.loadError': _Entry(
    'Could not load alerts.\n{error}',
    'সতর্কতা লোড করা যায়নি।\n{error}',
  ),
  'alerts.adminHeader': _Entry(
    'Official safety alerts',
    'সরকারি নিরাপত্তা সতর্কতা',
  ),
  'alerts.adminBadge': _Entry('OFFICIAL', 'সরকারি'),
  'alerts.severity.info': _Entry('INFO', 'তথ্য'),
  'alerts.severity.warning': _Entry('WARNING', 'সতর্কতা'),
  'alerts.severity.critical': _Entry('CRITICAL', 'গুরুতর'),

  // -- Message checker placeholder body --
  'messageChecker.title': _Entry('Check Message', 'বার্তা যাচাই করুন'),
  'messageChecker.body': _Entry('Message Checker', 'বার্তা যাচাইকারী'),
  'messageChecker.demoLang': _Entry(
    'Report language: ',
    'রিপোর্টের ভাষা: ',
  ),

  // -- Message checker screen (form labels) --
  'messageChecker.wording': _Entry(
    'Paste the SMS, WhatsApp, or email below.',
    'নিচে এসএমএস, হোয়াটসঅ্যাপ বা ইমেইল পেস্ট করুন।',
  ),
  'messageChecker.hint': _Entry(
    'e.g. Your bKash account will be suspended. Send 5000 BDT to 017xx... to verify.',
    'যেমন: আপনার বিকাশ অ্যাকাউন্ট স্থগিত হবে। যাচাই করতে ৫০০০ টাকা ০১৭xx... নম্বরে পাঠান।',
  ),
  'messageChecker.analyze': _Entry('Analyze', 'বিশ্লেষণ করুন'),
  'messageChecker.checkAnother': _Entry('Check another', 'আরেকটি যাচাই করুন'),
  'messageChecker.scoreLabel': _Entry(
    'Score {score}/100',
    'স্কোর {score}/১০০',
  ),
  'messageChecker.categoryLabel': _Entry(
    'Category: {category}',
    'বিভাগ: {category}',
  ),
  'messageChecker.confidenceLabel': _Entry(
    'Confidence: {value}%',
    'নিশ্চিতা: {value}%',
  ),
  'messageChecker.aiBadge': _Entry('✨ AI Analysis', '✨ AI বিশ্লেষণ'),
  'messageChecker.tapForDetails': _Entry(
    'Tap for full details',
    'বিস্তারিত দেখতে ট্যাপ করুন',
  ),

  // -- Message Checker — hero strip + inline verdict card (redesign) --
  'messageChecker.heading': _Entry('Check a message', 'বার্তা যাচাই করুন'),
  'messageChecker.subheading': _Entry(
    "Paste any suspicious SMS, WhatsApp or email below. We'll scan it for phishing, scam and impersonation signals.",
    'নিচে যেকোনো সন্দেহজনক এসএমএস, হোয়াটসঅ্যাপ বা ইমেইল পেস্ট করুন। আমরা ফিশিং, স্ক্যাম ও প্রতারণার সংকেত খুঁজব।',
  ),
  'messageChecker.noWarnings': _Entry(
    'No specific risk signals detected.',
    'নির্দিষ্ট কোনো ঝুঁকির সংকেত পাওয়া যায়নি।',
  ),
  'messageChecker.why': _Entry('Why?', 'কেন?'),
  'messageChecker.recommendations': _Entry(
    'What should you do?',
    'আপনার কী করা উচিত?',
  ),
  'messageChecker.aiAssisted': _Entry(
    'AI-assisted',
    'এআই সহায়তায়',
  ),
  'messageChecker.localOnly': _Entry(
    'Local rules only',
    'শুধু স্থানীয় নিয়ম',
  ),
  'messageChecker.safetyNotice': _Entry(
    'For your safety: never share OTPs, PINs or passwords — even with someone you trust. NirapodClick checks signals, not intentions.',
    'নিরাপত্তার জন্য: ওটিপি, পিন বা পাসওয়ার্ড কারো সাথে শেয়ার করবেন না — এমনকি বিশ্বস্ত কারো সাথেও নয়। নিরাপদক্লিক সংকেত যাচাই করে, অভিস্তি নয়।',
  ),

  // -- URL checker placeholder body --
  'urlChecker.title': _Entry('Check Link', 'লিংক যাচাই করুন'),
  'urlChecker.body': _Entry('URL Checker', 'URL যাচাইকারী'),

  // -- URL checker screen (full form, post-rebuild) --
  'urlChecker.appBarTitle': _Entry('URL Checker', 'URL যাচাইকারী'),
  'urlChecker.heading': _Entry(
    'Check a suspicious link',
    'সন্দেহজনক লিংক যাচাই করুন',
  ),
  'urlChecker.subheading': _Entry(
    'Paste a website link to check for potential phishing or scam indicators.',
    'ফিশিং বা প্রতারণার সম্ভাব্য চিহ্ন পরীক্ষা করতে ওয়েবসাইট লিংক পেস্ট করুন।',
  ),
  'urlChecker.hint': _Entry('https://example.com', 'https://example.com'),
  'urlChecker.paste': _Entry('Paste', 'পেস্ট'),
  'urlChecker.check': _Entry('Check URL', 'URL যাচাই করুন'),
  'urlChecker.checking': _Entry('Checking...', 'যাচাই হচ্ছে...'),
  'urlChecker.emptyInput': _Entry(
    'Please enter a URL.',
    'একটি URL দিন।',
  ),
  'urlChecker.confidence': _Entry(
    'Confidence: {percent}%',
    'নির্ভরযোগ্যতা: {percent}%',
  ),
  'urlChecker.urlLabel': _Entry('URL', 'URL'),
  'urlChecker.why': _Entry('Why?', 'কেন?'),
  'urlChecker.recommendationsHeader': _Entry(
    'What should you do?',
    'আপনার করণীয় কী?',
  ),
  'urlChecker.noWarnings': _Entry(
    'No major warning signs were detected.',
    'কোনো বড় সতর্কতা পাওয়া যায়নি।',
  ),
  'urlChecker.safetyNotice': _Entry(
    'NirapodClick checks for potential warning signs. '
    'A result does not guarantee that a website is safe or malicious.',
    'নিরাপদক্লিক সম্ভাব্য সতর্কতা যাচাই করে। '
    'ফলাফল কোনো ওয়েবসাইট নিরাপদ বা ক্ষতিকর তার পূর্ণ নিশ্চয়তা দেয় না।',
  ),
  'urlChecker.aiAssisted': _Entry(
    'AI-assisted verdict',
    'AI-সহায়তায় যাচাইকৃত',
  ),
  'urlChecker.localOnly': _Entry(
    'Local rules only',
    'শুধু স্থানীয় নিয়ম',
  ),
  'urlChecker.titleSafe': _Entry('LOW RISK', 'কম ঝুঁকি'),
  'urlChecker.titleLow': _Entry('LOW RISK', 'কম ঝুঁকি'),
  'urlChecker.titleMedium': _Entry('MEDIUM RISK', 'মাঝারি ঝুঁকি'),
  'urlChecker.titleHigh': _Entry('HIGH RISK', 'উচ্চ ঝুঁকি'),
  'urlChecker.titleCritical': _Entry('CRITICAL RISK', 'অত্যন্ত ঝুঁকিপূর্ণ'),

  // -- Screenshot Scanner screen --
  'screenshotScanner.appBarTitle': _Entry(
    'Screenshot Scanner',
    'স্ক্রিনশট স্ক্যানার',
  ),
  'screenshotScanner.heading': _Entry(
    'Scan a suspicious screenshot',
    'সন্দেহজনক স্ক্রিনশট স্ক্যান করুন',
  ),
  'screenshotScanner.subheading': _Entry(
    'Upload a screenshot of an SMS, chat, job post, payment request, '
    'or any suspicious message.',
    'এসএমএস, চ্যাট, চাকরির পোস্ট, পেমেন্ট অনুরোধ বা যেকোনো সন্দেহজনক '
    'বার্তার স্ক্রিনশট আপলোড করুন।',
  ),
  'screenshotScanner.pickerTitle': _Entry(
    'Tap to select screenshot',
    'স্ক্রিনশট নির্বাচন করতে ট্যাপ করুন',
  ),
  'screenshotScanner.pickerFormats': _Entry('JPG, PNG', 'JPG, PNG'),
  'screenshotScanner.processing': _Entry(
    'Reading screenshot...',
    'স্ক্রিনশট পড়া হচ্ছে...',
  ),
  'screenshotScanner.extractedHeader': _Entry(
    'Extracted Text',
    'নির্ণীত লেখা',
  ),
  'screenshotScanner.linksDetected': _Entry(
    'Links detected',
    'শনাক্ত লিংক',
  ),
  'screenshotScanner.foundHeader': _Entry(
    'What we found',
    'আমরা যা পেয়েছি',
  ),
  'screenshotScanner.urlsHeader': _Entry(
    'Links',
    'লিংক',
  ),
  'screenshotScanner.phonesHeader': _Entry(
    'Phone numbers',
    'ফোন নম্বর',
  ),
  'screenshotScanner.noUrls': _Entry(
    'No links were detected.',
    'কোনো লিংক পাওয়া যায়নি।',
  ),
  'screenshotScanner.noPhones': _Entry(
    'No phone numbers were detected.',
    'কোনো ফোন নম্বর পাওয়া যায়নি।',
  ),
  'screenshotScanner.why': _Entry('Why?', 'কেন?'),
  'screenshotScanner.recommendationsHeader': _Entry(
    'What should you do?',
    'আপনার করণীয় কী?',
  ),
  'screenshotScanner.emptyText': _Entry(
    'No readable text was found in the screenshot.',
    'স্ক্রিনশটে কোনো পাঠযোগ্য লেখা পাওয়া যায়নি।',
  ),
  'screenshotScanner.errorGeneric': _Entry(
    'Unable to analyze the screenshot.',
    'স্ক্রিনশট বিশ্লেষণ করা সম্ভব হচ্ছে না।',
  ),
  'screenshotScanner.permissionDenied': _Entry(
    'Photo access was denied. Enable it in Settings to scan screenshots.',
    'ফটো অ্যাক্সেস প্রত্যাখ্যাত হয়েছে। স্ক্রিনশট স্ক্যান করতে সেটিংসে '
    'অনুমতি দিন।',
  ),
  'screenshotScanner.scanAnother': _Entry(
    'Scan another',
    'আরেকটি স্ক্যান করুন',
  ),
  'screenshotScanner.safetyNotice': _Entry(
    'On-device OCR + local rules. '
    'Your image and extracted text are not sent to any server in this version.',
    'অন-ডিভাইস OCR + স্থানীয় নিয়ম। '
    'এই সংস্করণে আপনার ছবি ও নির্ণীত লেখা কোনো সার্ভারে পাঠানো হয় না।',
  ),
  'screenshotScanner.aiAssisted': _Entry(
    'AI-assisted verdict',
    'AI-সহায়তায় যাচাইকৃত',
  ),
  'screenshotScanner.localOnly': _Entry(
    'Local rules only',
    'শুধু স্থানীয় নিয়ম',
  ),
  'screenshotScanner.titleSafe': _Entry('LOW RISK', 'কম ঝুঁকি'),
  'screenshotScanner.titleLow': _Entry('LOW RISK', 'কম ঝুঁকি'),
  'screenshotScanner.titleMedium': _Entry('MEDIUM RISK', 'মাঝারি ঝুঁকি'),
  'screenshotScanner.titleHigh': _Entry('HIGH RISK', 'উচ্চ ঝুঁকি'),
  'screenshotScanner.titleCritical': _Entry(
    'CRITICAL RISK',
    'অত্যন্ত ঝুঁকিপূর্ণ',
  ),

  // -- Learn / Safety Center screen --
  'learn.appBarTitle': _Entry(
    'Safety Learning',
    'নিরাপত্তা শিক্ষা',
  ),
  'learn.heading': _Entry(
    'Learn Online Safety',
    'অনলাইন নিরাপত্তা শিখুন',
  ),
  'learn.subheading': _Entry(
    'Short lessons to help you recognize common online scams.',
    'সাধারণ অনলাইন প্রতারণা চিনতে সহায়তা করার জন্য ছোট পাঠ।',
  ),
  'learn.minutesShort': _Entry('min', 'মিনিট'),
  'learn.footerReminder': _Entry(
    'When in doubt, stop and verify through an official channel.',
    'সন্দেহ হলে থামুন এবং অফিসিয়াল মাধ্যমে যাচাই করুন।',
  ),

  // -- Phone Checker screen --
  'phoneChecker.appBarTitle': _Entry(
    'Phone Checker',
    'ফোন যাচাইকারী',
  ),
  'phoneChecker.heading': _Entry(
    'Check a phone number',
    'একটি ফোন নম্বর যাচাই করুন',
  ),
  'phoneChecker.subheading': _Entry(
    'Check whether a Bangladesh phone number has suspicious reports.',
    'এই বাংলাদেশি ফোন নম্বরের বিরুদ্ধে কোনো সন্দেহজনক রিপোর্ট আছে কিনা যাচাই করুন।',
  ),
  'phoneChecker.hint': _Entry('017XXXXXXXX', '০১৭XXXXXXXX'),
  'phoneChecker.check': _Entry('Check Number', 'নম্বর যাচাই করুন'),
  'phoneChecker.checking': _Entry('Checking...', 'যাচাই হচ্ছে...'),
  'phoneChecker.emptyInput': _Entry(
    'Please enter a phone number.',
    'একটি ফোন নম্বর দিন।',
  ),
  'phoneChecker.numberLabel': _Entry('Phone numbers', 'ফোন নম্বর'),
  'phoneChecker.operatorLabel': _Entry('Operator', 'অপারেটর'),
  'phoneChecker.reportsLabel': _Entry('Reports', 'রিপোর্ট'),
  'phoneChecker.why': _Entry('Why?', 'কেন?'),
  'phoneChecker.recommendationsHeader': _Entry(
    'What should you do?',
    'আপনার করণীয় কী?',
  ),
  'phoneChecker.safetyNotice': _Entry(
    'NirapodClick checks for potential warning signs. '
    'A result does not guarantee that a phone number is safe or malicious.',
    'নিরাপদক্লিক সম্ভাব্য সতর্কতা যাচাই করে। '
    'ফলাফল কোনো ফোন নম্বর নিরাপদ বা ক্ষতিকর তার পূর্ণ নিশ্চয়তা দেয় না।',
  ),
  'phoneChecker.titleSafe': _Entry('LOW RISK', 'কম ঝুঁকি'),
  'phoneChecker.titleLow': _Entry('LOW RISK', 'কম ঝুঁকি'),
  'phoneChecker.titleMedium': _Entry('MEDIUM RISK', 'মাঝারি ঝুঁকি'),
  'phoneChecker.titleHigh': _Entry('HIGH RISK', 'উচ্চ ঝুঁকি'),
  'phoneChecker.titleCritical': _Entry(
    'CRITICAL RISK',
    'অত্যন্ত ঝুঁকিপূর্ণ',
  ),

  // -- Phone Checker: community report dialog -- (e.g. 31–39 = 4*20, etc.)
  'phoneChecker.reportButton': _Entry(
    'Report This Number',
    'এই নম্বর রিপোর্ট করুন',
  ),
  'phoneChecker.reportDialogTitle': _Entry(
    'Report this number',
    'এই নম্বর রিপোর্ট করুন',
  ),
  'phoneChecker.reportReasonLabel': _Entry('Reason', 'কারণ'),
  'phoneChecker.reportReasonScam': _Entry('Scam', 'প্রতারণা'),
  'phoneChecker.reportReasonPayment': _Entry(
    'Payment fraud',
    'পেমেন্ট প্রতারণা',
  ),
  'phoneChecker.reportReasonOtp': _Entry(
    'OTP request',
    'OTP চাওয়া',
  ),
  'phoneChecker.reportReasonJob': _Entry('Fake job', 'ভুয়া চাকরি'),
  'phoneChecker.reportReasonHarassment': _Entry(
    'Harassment',
    'হয়রানি',
  ),
  'phoneChecker.reportReasonOther': _Entry('Other', 'অন্যান্য'),
  'phoneChecker.reportDetailsLabel': _Entry(
    'Additional details',
    'অতিরিক্ত তথ্য',
  ),
  'phoneChecker.reportDetailsHint': _Entry(
    'What happened? (optional)',
    'কী হয়েছিল? (ঐচ্ছিক)',
  ),
  'phoneChecker.reportCancel': _Entry('Cancel', 'বাতিল'),
  'phoneChecker.reportSubmit': _Entry('Submit', 'জমা দিন'),
  'phoneChecker.reportSuccess': _Entry(
    'Thank you. Your report has been submitted.',
    'ধন্যবাদ। আপনার রিপোর্ট জমা হয়েছে।',
  ),
  'phoneChecker.reportFailure': _Entry(
    'Unable to submit report. Please try again.',
    'রিপোর্ট জমা দেওয়া যায়নি। আবার চেষ্টা করুন।',
  ),
  'phoneChecker.reportInvalidPhone': _Entry(
    'Cannot report — this is not a valid BD mobile number.',
    'রিপোর্ট করা যাচ্ছে না — এটি বৈধ বাংলাদেশি মোবাইল নম্বর নয়।',
  ),
  'phoneChecker.reportsFetchFailed': _Entry(
    'Unable to check community reports. Showing local rules only.',
    'কমিউনিটি রিপোর্ট যাচাই করা যায়নি। শুধু স্থানীয় নিয়ম দেখানো হচ্ছে।',
  ),

  // -- Check Hub screen --
  'check.appBarTitle': _Entry(
    'Safety Check',
    'নিরাপত্তা যাচাই',
  ),
  'check.heading': _Entry(
    'What do you want to check?',
    'কী যাচাই করতে চান?',
  ),
  'check.subheading': _Entry(
    'Choose the type of suspicious content '
    'you want NirapodClick to analyze.',
    'নিরাপদক্লিক কোন ধরনের সন্দেহজনক বিষয় বিশ্লেষণ করবে তা বেছে নিন।',
  ),
  'check.messageTitle': _Entry('Message', 'বার্তা'),
  'check.messageSubtitle': _Entry(
    'Check SMS, WhatsApp or social messages',
    'SMS, হোয়াটসঅ্যাপ বা সামাজিক মাধ্যমের বার্তা যাচাই করুন',
  ),
  'check.urlTitle': _Entry('URL', 'লিংক'),
  'check.urlSubtitle': _Entry(
    'Check a suspicious website link',
    'সন্দেহজনক ওয়েবসাইটের লিংক যাচাই করুন',
  ),
  'check.screenshotTitle': _Entry('Screenshot', 'স্ক্রিনশট'),
  'check.screenshotSubtitle': _Entry(
    'Scan text from a screenshot',
    'স্ক্রিনশটের লেখা স্ক্যান করুন',
  ),
  'check.phoneTitle': _Entry('Phone', 'ফোন'),
  'check.phoneSubtitle': _Entry(
    'Check community reports',
    'কমিউনিটি রিপোর্ট যাচাই করুন',
  ),

  // -- Profile screen --
  'profile.appBarTitle': _Entry('Profile', 'প্রোফাইল'),
  'profile.fallbackName': _Entry(
    'NirapodClick User',
    'নিরাপদক্লিক ব্যবহারকারী',
  ),
  'profile.sectionActivity': _Entry(
    'Your Activity',
    'আপনার কার্যকলাপ',
  ),
  'profile.sectionSafety': _Entry(
    'Your Safety',
    'আপনার নিরাপত্তা',
  ),
  'profile.sectionSettings': _Entry('Settings', 'সেটিংস'),
  'profile.sectionAccount': _Entry('Account', 'অ্যাকাউন্ট'),
  'profile.menuHistoryTitle': _Entry('Scan History', 'স্ক্যান ইতিহাস'),
  'profile.menuHistorySubtitle': _Entry(
    'View your previous scans',
    'পূর্বের স্ক্যানগুলো দেখুন',
  ),
  'profile.menuLearnTitle': _Entry(
    'Safety Learning',
    'নিরাপত্তা শিক্ষা',
  ),
  'profile.menuLearnSubtitle': _Entry(
    'Learn about common scams',
    'সাধারণ প্রতারণা সম্পর্কে জানুন',
  ),
  'profile.menuNotificationsTitle': _Entry(
    'Notifications',
    'বিজ্ঞপ্তি',
  ),
  'profile.menuNotificationsSubtitle': _Entry(
    'Manage safety alerts',
    'নিরাপত্তা সতর্কতা পরিচালনা করুন',
  ),
  'profile.menuLanguageTitle': _Entry('Language', 'ভাষা'),
  'profile.menuLanguageSubtitle': _Entry(
    'Choose your app language',
    'অ্যাপের ভাষা নির্বাচন করুন',
  ),
  'profile.menuThemeTitle': _Entry('Theme', 'থিম'),
  'profile.menuThemeSubtitle': _Entry(
    'Light, dark, or system',
    'হালকা, অন্ধকার বা সিস্টেম',
  ),
  'profile.themeComingSoon': _Entry(
    'Coming soon — light mode is currently the only theme available.',
    'শীঘ্রই আসছে — বর্তমানে শুধু হালকা মোড পাওয়া যায়।',
  ),
  'profile.notificationsToggleTitle': _Entry(
    'Enable safety alerts',
    'নিরাপত্তা সতর্কতা চালু করুন',
  ),
  'profile.notificationsToggleSubtitle': _Entry(
    'Show new critical scans on the home bell',
    'নতুন গুরুতর স্ক্যান হোমের ঘণ্টায় দেখান',
  ),
  'profile.privacyDeleteAll': _Entry(
    'Delete all scan history',
    'সব স্ক্যান ইতিহাস মুছুন',
  ),
  'profile.privacyDeleteAllConfirm': _Entry(
    'Delete all scans?',
    'সব স্ক্যান মুছে ফেলবেন?',
  ),
  'profile.privacyDeleteAllBody': _Entry(
    'This permanently removes every saved scan. This cannot be undone.',
    'এটি প্রতিটি সংরক্ষিত স্ক্যান স্থায়ীভাবে মুছে দেবে। এটি ফিরিয়ে আনা যাবে না।',
  ),
  'profile.privacyDeleteSelected': _Entry(
    'Select scans to delete',
    'মুছতে স্ক্যান নির্বাচন করুন',
  ),
  'profile.historySelectTitle': _Entry(
    'Select scans to delete',
    'মুছতে স্ক্যান নির্বাচন করুন',
  ),
  'profile.historySelectEmpty': _Entry(
    'No scans to delete.',
    'মুছার জন্য কোনো স্ক্যান নেই।',
  ),
  'profile.historySelectLoadError': _Entry(
    'Could not load scans. Check your connection and try again.',
    'স্ক্যান লোড করা যায়নি। আপনার সংযোগ পরীক্ষা করে আবার চেষ্টা করুন।',
  ),
  'profile.historySelectRetry': _Entry('Retry', 'আবার চেষ্টা করুন'),
  'profile.historySelectCount': _Entry(
    '{n} selected',
    '{n}টি নির্বাচিত',
  ),
  'profile.historySelectDelete': _Entry('Delete', 'মুছুন'),
  'profile.historySelectDeleteConfirm': _Entry(
    'Delete {n} scans?',
    '{n}টি স্ক্যান মুছে ফেলবেন?',
  ),
  'profile.historyDeletedToast': _Entry(
    'Deleted {n} scans.',
    '{n}টি স্ক্যান মুছে ফেলা হয়েছে।',
  ),
  'profile.commonDelete': _Entry('Delete', 'মুছুন'),
  'profile.commonCancel': _Entry('Cancel', 'বাতিল'),
  'profile.menuPrivacyTitle': _Entry('Privacy', 'গোপনীয়তা'),
  'profile.menuPrivacySubtitle': _Entry(
    'Manage your scan data',
    'আপনার স্ক্যান ডেটা পরিচালনা করুন',
  ),
  'profile.menuLogoutTitle': _Entry('Log Out', 'লগ আউট'),
  'profile.menuLogoutSubtitle': _Entry(
    'Sign out of NirapodClick',
    'নিরাপদক্লিক থেকে সাইন আউট করুন',
  ),
  'profile.sectionAdmin': _Entry('Admin', 'অ্যাডমিন'),
  'profile.menuAdminAlertsTitle': _Entry(
    'Safety alerts',
    'নিরাপত্তা সতর্কতা',
  ),
  'profile.menuAdminAlertsSubtitle': _Entry(
    'Publish alerts to all users',
    'সব ব্যবহারকারীদের সতর্কতা প্রকাশ করুন',
  ),
  'profile.notificationsBody': _Entry(
    'Critical scan alerts appear on the home bell. '
    'Tap the bell to review them.',
    'গুরুতর স্ক্যান সতর্কতা হোমের ঘণ্টায় দেখা যায়। '
    'সতর্কতাগুলো দেখতে ঘণ্টায় ট্যাপ করুন।',
  ),
  'profile.privacyBody': _Entry(
    'NirapodClick should only store the minimum '
    'information required to provide its services. '
    'You can delete your scan history at any time.',
    'নিরাপদক্লিক শুধু তার সেবা দেওয়ার জন্য প্রয়োজনীয় সর্বনিম্ন তথ্য সংরক্ষণ করে। '
    'আপনি যেকোনো সময় আপনার স্ক্যান ইতিহাস মুছে ফেলতে পারবেন।',
  ),
  'profile.logoutDialogTitle': _Entry('Log out?', 'লগ আউট করবেন?'),
  'profile.logoutDialogBody': _Entry(
    'Are you sure you want to log out?',
    'আপনি কি নিশ্চিত যে লগ আউট করতে চান?',
  ),
  'profile.logoutCancel': _Entry('Cancel', 'বাতিল'),
  'profile.logoutConfirm': _Entry('Log Out', 'লগ আউট'),

  // -- Home dashboard (post-Phase-2 refactor) --
  'home.heroTitle': _Entry('Is something suspicious?', 'কিছু কি সন্দেহজনক?'),
  'home.heroSubtitle': _Entry(
    'Check messages, links, screenshots and phone numbers in seconds.',
    'মুহূর্তেই মেসেজ, লিংক, স্ক্রিনশট ও ফোন নম্বর যাচাই করুন।',
  ),
  'home.ctaCheckNow': _Entry('Check Now', 'এখনই যাচাই করুন'),
  'home.recentScansTitle': _Entry('Recent Scans', 'সাম্প্রতিক যাচাই'),
  'home.recentScansEmpty': _Entry(
    'No scans yet. Run your first check to see it here.',
    'এখনো কোনো যাচাই নেই। প্রথম যাচাই চালালে এখানে দেখা যাবে।',
  ),
  'home.recentScansViewAll': _Entry('View all', 'সব দেখুন'),

  // -- Result screens: shared disclaimer + AI-fallback banner --
  'result.disclaimer': _Entry(
    'NirapodClick provides risk indicators, not a guarantee that content is '
    'safe or malicious. Always verify important requests through official '
    'channels.',
    'নিরাপদক্লিক কেবল ঝুঁকির ইঙ্গিত দেয়, নিরাপদ বা ক্ষতিকর হওয়ার নিশ্চয়তা '
    'দেয় না। গুরুত্বপূর্ণ অনুরোধ সবসময় সরকারি/প্রাতিষ্ঠানিক চ্যানেলে যাচাই করুন।',
  ),
  'result.originalHeader': _Entry(
    'Original message',
    'মূল বার্তা',
  ),
  'result.aiUnavailable': _Entry(
    'AI analysis unavailable. Showing the local rule-engine result instead.',
    'AI বিশ্লেষণ পাওয়া যায়নি। স্থানীয় নিয়ম-ভিত্তিক ফলাফল দেখানো হচ্ছে।',
  ),
  // Result-screen labels: rendered via `AppLocaleScope.of(context).tr(...)`
  // in `risk_result_page.dart`. Earlier these only lived in the engine
  // map (`lib/core/locale/localizer.dart`), so the widget tree's
  // translator fell back to the raw key string ("result.label.back",
  // etc.) — fixed by mirroring them here.
  'result.label.appBarTitle': _Entry('Result', 'ফলাফল'),
  'result.label.score': _Entry(
    'Risk score: {score} / 100',
    'ঝুঁকির স্কোর: {score} / ১০০',
  ),
  'result.label.category': _Entry('Category', 'বিভাগ'),
  'result.label.confidence': _Entry('Confidence', 'নিশ্চয়তা'),
  'result.label.aiBadge': _Entry('✨ AI Analysis', '✨ AI বিশ্লেষণ'),
  'result.label.whatWeFound': _Entry(
    'What we found ({count})',
    'আমরা যা পেয়েছি ({count})',
  ),
  'result.label.noSignals': _Entry(
    'No suspicious signals detected.',
    'কোনো সন্দেহজনক ইঙ্গিত পাওয়া যায়নি।',
  ),
  'result.label.safetyTips': _Entry(
    'Safety tips',
    'নিরাপত্তা পরামর্শ',
  ),
  'result.label.back': _Entry('Back', 'ফিরে যান'),
  'result.label.copy': _Entry('Copy report', 'রিপোর্ট কপি করুন'),
  'result.label.copied': _Entry(
    'Report copied to clipboard',
    'রিপোর্ট ক্লিপবোর্ডে কপি হয়েছে',
  ),

  // -- Premium / Subscription screen --
  'subscription.appBarTitle': _Entry('Premium', 'প্রিমিয়াম'),
  'subscription.title': _Entry(
    'NirapodClick Premium',
    'নিরাপদক্লিক প্রিমিয়াম',
  ),
  'subscription.tagline': _Entry(
    'Stay safer. Scan without worrying about limits.',
    'আরও নিরাপদ থাকুন। সীমা নিয়ে চিন্তা ছাড়াই যাচাই করুন।',
  ),
  'subscription.benefitsHeader': _Entry(
    'PREMIUM BENEFITS',
    'প্রিমিয়াম সুবিধা',
  ),
  'subscription.benefit.unlimitedMessages': _Entry(
    'Unlimited message scans',
    'সীমাহীন বার্তা যাচাই',
  ),
  'subscription.benefit.unlimitedUrls': _Entry(
    'Unlimited URL checks',
    'সীমাহীন URL যাচাই',
  ),
  'subscription.benefit.moreScreenshots': _Entry(
    'More screenshot scans',
    'আরও স্ক্রিনশট স্ক্যান',
  ),
  'subscription.benefit.advancedAi': _Entry(
    'Advanced AI analysis',
    'উন্নত AI বিশ্লেষণ',
  ),
  'subscription.benefit.detailedReports': _Entry(
    'Detailed risk reports',
    'বিস্তারিত ঝুঁকি রিপোর্ট',
  ),
  'subscription.benefit.priorityUpdates': _Entry(
    'Priority scam updates',
    'অগ্রাধিকার প্রতারণা আপডেট',
  ),
  'subscription.priceLine': _Entry(
    'Only ৳2.78 / day',
    'মাত্র ৳২.৭৮ / দিন',
  ),
  'subscription.subscribeCta': _Entry(
    'Subscribe Now',
    'এখনই সাবস্ক্রাইব করুন',
  ),
  'subscription.subscribing': _Entry(
    'Verifying subscription...',
    'সাবস্ক্রিপশন যাচাই হচ্ছে...',
  ),
  'subscription.fineprint': _Entry(
    'Unsubscribe',
    'নাম প্রত্যাহার',
  ),
  'subscription.errorTitle': _Entry(
    'Subscription could not be verified',
    'সাবস্ক্রিপশন যাচাই করা যায়নি',
  ),
  'subscription.tryAgain': _Entry(
    'Try Again',
    'আবার চেষ্টা করুন',
  ),

  // -- Profile subscription status card --
  'subscription.card.premiumTitle': _Entry(
    'NirapodClick Premium',
    'নিরাপদক্লিক প্রিমিয়াম',
  ),
  'subscription.card.premiumStatus': _Entry(
    'Active',
    'সক্রিয়',
  ),
  'subscription.card.premiumPrice': _Entry(
    '৳2.78 / day',
    '৳২.৭৮ / দিন',
  ),
  'subscription.card.nextRenewal': _Entry(
    'Next renewal: {date}',
    'পরবর্তী নবায়ন: {date}',
  ),
  'subscription.card.nextRenewalPending': _Entry(
    'Next renewal: —',
    'পরবর্তী নবায়ন: —',
  ),
  'subscription.card.manageCta': _Entry(
    'Manage Subscription',
    'সাবস্ক্রিপশন পরিচালনা',
  ),
  'subscription.card.freeTitle': _Entry(
    'NirapodClick Free',
    'নিরাপদক্লিক ফ্রি',
  ),
  'subscription.card.freeSubtitle': _Entry(
    'Your daily safety check budget',
    'আপনার দৈনিক নিরাপত্তা যাচাই বাজেট',
  ),
  'subscription.card.freeScreenshots': _Entry(
    '{count} screenshot scans left',
    '{count}টি স্ক্রিনশট স্ক্যান বাকি',
  ),
  'subscription.card.freeMessages': _Entry(
    '{count} message scans left',
    '{count}টি বার্তা স্ক্যান বাকি',
  ),
  'subscription.card.freeScreenshotsLabel': _Entry(
    'Screenshot scans',
    'স্ক্রিনশট স্ক্যান',
  ),
  'subscription.card.freeMessagesLabel': _Entry(
    'Message scans',
    'বার্তা স্ক্যান',
  ),
  'subscription.card.freeTotalLabel': _Entry(
    'Total scans left',
    'মোট স্ক্যান বাকি',
  ),
  'subscription.card.premiumPriceLabel': _Entry(
    'Plan price',
    'প্ল্যান মূল্য',
  ),
  'subscription.card.nextRenewalLabel': _Entry(
    'Next renewal',
    'পরবর্তী নবায়ন',
  ),
  'subscription.card.goPremiumCta': _Entry(
    '✨ Go Premium',
    '✨ প্রিমিয়ামে যান',
  ),

  // -- Admin alerts screen --
  'adminAlerts.appBarTitle': _Entry(
    'Admin Alerts',
    'অ্যাডমিন সতর্কতা',
  ),
  'adminAlerts.refresh': _Entry('Refresh', 'রিফ্রেশ'),
  'adminAlerts.compose': _Entry('Publish alert', 'সতর্কতা প্রকাশ'),
  'adminAlerts.consoleOnlyNotice': _Entry(
    'Alerts are managed in the Firebase Console for security. '
    'Use this form to preview and prepare the alert, then paste it into the Console.',
    'নিরাপত্তার জন্য সতর্কতাগুলো ফায়ারবেস কনসোলে পরিচালিত হয়। '
    'এই ফর্মটি সতর্কতা প্রস্তুত ও পূর্বরূপ দেখানোর জন্য ব্যবহার করুন, তারপর কনসোলে পেস্ট করুন।',
  ),
  'adminAlerts.sectionLive': _Entry('Live alerts', 'সক্রিয় সতর্কতা'),
  'adminAlerts.emptyLive': _Entry(
    'No alerts published yet.',
    'এখনও কোনো সতর্কতা প্রকাশিত হয়নি।',
  ),
  'adminAlerts.draftCopied': _Entry(
    'Draft prepared. Open Firebase Console → Firestore → admin_alerts to publish.',
    'খসড়া প্রস্তুত। প্রকাশ করতে Firebase Console → Firestore → admin_alerts খুলুন।',
  ),
  'adminAlerts.composeTitle': _Entry(
    'Compose alert',
    'সতর্কতা তৈরি করুন',
  ),
  'adminAlerts.fieldDocId': _Entry('Document ID', 'ডকুমেন্ট আইডি'),
  'adminAlerts.fieldDocIdHint': _Entry(
    'lowercase-id-with-dashes (e.g. bkash-phishing-q4)',
    'ছোটহাতের-আইডি-ড্যাশসহ (যেমন: bkash-phishing-q4)',
  ),
  'adminAlerts.fieldTitleEn': _Entry('Title (English)', 'শিরোনাম (ইংরেজি)'),
  'adminAlerts.fieldTitleBn': _Entry('Title (Bangla)', 'শিরোনাম (বাংলা)'),
  'adminAlerts.fieldBodyEn': _Entry('Body (English)', 'বিষয়বস্তু (ইংরেজি)'),
  'adminAlerts.fieldBodyBn': _Entry('Body (Bangla)', 'বিষয়বস্তু (বাংলা)'),
  'adminAlerts.fieldSeverity': _Entry('Severity', 'তীব্রতা'),
  'adminAlerts.fieldActive': _Entry('Active (visible to users)', 'সক্রিয় (ব্যবহারকারীদের কাছে দৃশ্যমান)'),
  'adminAlerts.submit': _Entry('Prepare draft', 'খসড়া প্রস্তুত করুন'),
  'adminAlerts.cancel': _Entry('Cancel', 'বাতিল'),
  'adminAlerts.previewHeader': _Entry('Preview', 'পূর্বরূপ'),

  // -- Admin URL rules screen --
  'adminUrlRules.appBarTitle': _Entry(
    'Admin • URL Rules',
    'অ্যাডমিন • URL নিয়ম',
  ),
  'adminUrlRules.noticeConsoleOnly': _Entry(
    'URL rules are managed in the Firebase Console for security. '
    'Use this form to preview the live rules and prepare a draft, then paste it into the Console.',
    'নিরাপত্তার জন্য URL নিয়মগুলো ফায়ারবেস কনসোলে পরিচালিত হয়। '
    'এই ফর্মটি সক্রিয় নিয়ম দেখতে ও খসড়া প্রস্তুত করতে ব্যবহার করুন, তারপর কনসোলে পেস্ট করুন।',
  ),
  'adminUrlRules.compose': _Entry('New URL rule', 'নতুন URL নিয়ম'),
  'adminUrlRules.composeTitle': _Entry(
    'Compose URL rule',
    'URL নিয়ম তৈরি করুন',
  ),
  'adminUrlRules.draftCopied': _Entry(
    'Draft prepared. Open Firebase Console → Firestore → url_scam_rules to publish.',
    'খসড়া প্রস্তুত। প্রকাশ করতে Firebase Console → Firestore → url_scam_rules খুলুন।',
  ),
  'adminUrlRules.empty': _Entry(
    'No URL rules published yet. The app is using the bundled defaults.',
    'এখনও কোনো URL নিয়ম প্রকাশিত হয়নি। অ্যাপটি ডিফল্ট নিয়ম ব্যবহার করছে।',
  ),
  'adminUrlRules.typeLabel': _Entry('Type', 'ধরন'),
  'adminUrlRules.patternLabel': _Entry('Pattern (substring to match)', 'প্যাটার্ন (মেলানোর অংশ)'),
  'adminUrlRules.categoryLabel': _Entry('Output category', 'আউটপুট বিভাগ'),
  'adminUrlRules.scoreLabel': _Entry('Score', 'স্কোর'),
  'adminUrlRules.activeLabel': _Entry('Active', 'সক্রিয়'),
  'adminUrlRules.activeOn': _Entry('Active', 'সক্রিয়'),
  'adminUrlRules.activeOff': _Entry('Off', 'বন্ধ'),
  'adminUrlRules.type.tld': _Entry('TLD', 'TLD'),
  'adminUrlRules.type.foreignTld': _Entry('Foreign TLD', 'বিদেশি TLD'),
  'adminUrlRules.type.extension': _Entry('Extension', 'এক্সটেনশন'),
  'adminUrlRules.type.keyword': _Entry('Keyword', 'কীওয়ার্ড'),
  'adminUrlRules.type.shortener': _Entry('Shortener', 'শর্টেনার'),
  'adminUrlRules.type.brand': _Entry('Brand', 'ব্র্যান্ড'),

  // -- Profile screen admin menu entries --
  'profile.menuAdminUrlRulesTitle': _Entry(
    'URL Rules',
    'URL নিয়ম',
  ),
  'profile.menuAdminUrlRulesSubtitle': _Entry(
    'Preview and compose Firestore-backed URL rule docs.',
    'Firestore-ভিত্তিক URL নিয়ম ডকুমেন্ট পূর্বরূপ ও তৈরি করুন।',
  ),

  // -- Free-tier usage quota --
  // Free users get 5 checks per calendar month. After exhausting the
  // budget the four scanners refuse to analyze and the Home shows a
  // single "X of 5 free checks remaining" pill that links to Premium.
  'quota.remaining': _Entry(
    '{used} of {total} free checks used this month',
    'এই মাসে {used} / {total}টি ফ্রি যাচাই ব্যবহৃত',
  ),
  'quota.remainingShort': _Entry(
    '{remaining} free left',
    '{remaining}টি ফ্রি বাকি',
  ),
  'quota.unlimitedActive': _Entry(
    'Unlimited checks · Premium',
    'আনলিমিটেড যাচাই · প্রিমিয়াম',
  ),
  'quota.exhaustedTitle': _Entry(
    'Free check limit reached',
    'ফ্রি যাচাই সীমা শেষ',
  ),
  'quota.exhaustedBody': _Entry(
    'You have used all {total} free checks for this month. '
    'Subscribe to Premium for unlimited checks.',
    'এই মাসে আপনার সব {total}টি ফ্রি যাচাই শেষ হয়েছে। '
    'আনলিমিটেড যাচাইয়ের জন্য প্রিমিয়ামে সাবস্ক্রাইব করুন।',
  ),
  'quota.upgradeCta': _Entry(
    'View Premium plans',
    'প্রিমিয়াম প্ল্যান দেখুন',
  ),
  'quota.alreadyPremium': _Entry(
    'You have unlimited checks.',
    'আপনার আনলিমিটেড যাচাই আছে।',
  ),
  'quota.spent': _Entry(
    'Used',
    'ব্যবহৃত',
  ),
  'quota.resetsOn': _Entry(
    'Resets on {date}',
    '{date} তারিখে রিসেট হবে',
  ),
  'quota.checkName.message': _Entry('Message check', 'বার্তা যাচাই'),
  'quota.checkName.url': _Entry('URL check', 'লিংক যাচাই'),
  'quota.checkName.screenshot': _Entry('Screenshot scan', 'স্ক্রিনশট স্ক্যান'),
  'quota.checkName.phone': _Entry('Phone check', 'ফোন যাচাই'),
};
