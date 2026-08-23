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

  // -- Redesign 2026: subscription chip, scan counts, premium banner --
  'home.scansLeftShort': _Entry(
    '{count} left today',
    'আজ {count}টি বাকি',
  ),
  'home.scansUnlimited': _Entry('Unlimited', 'আনলিমিটেড'),
  'home.premiumActiveChip': _Entry('✨ Premium active', '✨ প্রিমিয়াম সক্রিয়'),
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
  'history.typePhone': _Entry('Phone Number', 'ফোন নম্বর'),
  'history.clearedToast': _Entry(
    'History cleared',
    'ইতিহাস মুছে ফেলা হয়েছে',
  ),

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
  'phoneChecker.numberLabel': _Entry('Number', 'নম্বর'),
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
  'check.phoneTitle': _Entry('Phone Number', 'ফোন নম্বর'),
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
  'profile.notificationsBody': _Entry(
    'Safety notifications can be enabled here '
    'when the alert system is added.',
    'সতর্কতা ব্যবস্থা যুক্ত হলে এখান থেকে নিরাপত্তা বিজ্ঞপ্তি চালু করা যাবে।',
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
  'result.aiUnavailable': _Entry(
    'AI analysis unavailable. Showing the local rule-engine result instead.',
    'AI বিশ্লেষণ পাওয়া যায়নি। স্থানীয় নিয়ম-ভিত্তিক ফলাফল দেখানো হচ্ছে।',
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
    'Subscription renews daily. Cancel anytime.',
    'সাবস্ক্রিপশন প্রতিদিন নবায়ন হবে। যেকোনো সময় বাতিল করতে পারবেন।',
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
  'subscription.card.freeScreenshots': _Entry(
    '{count} screenshot scans left',
    '{count}টি স্ক্রিনশট স্ক্যান বাকি',
  ),
  'subscription.card.freeMessages': _Entry(
    '{count} message scans left',
    '{count}টি বার্তা স্ক্যান বাকি',
  ),
  'subscription.card.goPremiumCta': _Entry(
    '✨ Go Premium',
    '✨ প্রিমিয়ামে যান',
  ),
};
