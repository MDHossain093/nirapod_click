import '../../models/phone_risk_result.dart';
import '../../models/risk_result.dart';
import '../../models/url_risk_result.dart';
import 'app_locale.dart';
import 'digits.dart' as digits;

/// Context-free localization singleton.
///
/// Why this exists alongside [AppLocaleScope]:
///
/// The result strings produced by [RiskEngine], [UrlRiskEngine],
/// [PhoneRiskEngine], and the Gemini prompts in [AiService] are
/// generated in pure-Dart code that doesn't have access to a
/// [BuildContext]. They used to be hardcoded English. This singleton
/// is the bridge: when the user picks a language, [AppLocaleScope]
/// calls [setLocale] which updates the global lookup. Any pure-Dart
/// caller (engines, AI service, the `ReportClipboard` formatter)
/// can then resolve a translation key through [tr] without needing
/// a widget tree.
///
/// In the rare case where the singleton hasn't been seeded yet
/// (e.g. a unit test that constructs an engine directly), [tr] falls
/// back to the English entry and finally to the key itself so
/// nothing ever crashes.
///
/// Adding a new key is cheap: drop a `_Entry` into the table and
/// reference it from the engine by key. Don't reach into the
/// translation map from screens — use `AppLocaleScope.of(context).tr`
/// there because that's still the canonical, widget-tree-aware path.
class Localizer {
  Localizer._();

  /// Process-wide singleton.
  static final Localizer instance = Localizer._();

  AppLocale _locale = AppLocale.english;

  /// Set the active locale. Called from [AppLocaleScope] whenever the
  /// user picks a different language.
  void setLocale(AppLocale locale) {
    _locale = locale;
  }

  /// Current locale.
  AppLocale get locale => _locale;

  /// Resolve [key] to a string in the active locale.
  /// English → Bangla → raw key. Never returns null.
  String tr(String key) {
    final entry = _engineStrings[key];
    if (entry == null) return key;
    switch (_locale) {
      case AppLocale.english:
        return entry.en;
      case AppLocale.bangla:
        return entry.en.isEmpty ? key : entry.bn;
    }
  }

  /// Format a number with locale-appropriate digits.
  ///
  /// Convenience wrapper around [digits.formatInt] for engines, the
  /// clipboard builder, and other pure-Dart code that doesn't have
  /// access to a [BuildContext]. Tracks the active locale set via
  /// [setLocale] (which [AppLocaleScope] calls on every language
  /// toggle), so the digits stay in sync with the UI.
  String formatNumber(num value) =>
      digits.formatInt(value.toInt(), _locale);

  /// `value * 100`, rounded, with localized digits and a `%` suffix.
  String formatPercent(double value) =>
      digits.formatPercent(value, _locale);

  /// `<n> / <denominator>` with localized digits. Defaults to the
  /// 0..100 risk-score scale.
  String formatScore(int score, {int denominator = 100}) =>
      digits.formatScore(score, _locale, denominator: denominator);
}

class _Entry {
  const _Entry(this.en, this.bn);
  final String en;
  final String bn;
}

/// Translation table for engine / AI / pure-Dart strings.
///
/// English is the source of truth. Bangla falls back to English when
/// missing. Keep this table flat (no nested groups) so the lookup is
/// O(1) — engines add reasons in tight inner loops.
const Map<String, _Entry> _engineStrings = {
  // ─────────── Risk levels (message + URL + phone) ───────────
  'level.safe': _Entry('Looks safe', 'নিরাপদ মনে হচ্ছে'),
  'level.low': _Entry('Be cautious', 'সতর্ক থাকুন'),
  'level.medium':
      _Entry('Potentially suspicious', 'সম্ভাব্য সন্দেহজনক'),
  'level.high': _Entry('High risk', 'উচ্চ ঝুঁকি'),
  'level.critical': _Entry('Critical warning', 'গুরুতর সতর্কতা'),

  // ─────────── Categories ───────────
  'category.general': _Entry('General', 'সাধারণ'),
  'category.credentialTheft':
      _Entry('Credential Theft', 'পাসওয়ার্ড চুরি'),
  'category.phishing': _Entry('Phishing', 'ফিশিং'),
  'category.paymentScam': _Entry('Payment Scam', 'পেমেন্ট প্রতারণা'),
  'category.prizeScam': _Entry('Prize Scam', 'পুরস্কার প্রতারণা'),
  'category.jobScam': _Entry('Job Scam', 'চাকরির প্রতারণা'),
  'category.accountScam': _Entry('Account Scam', 'অ্যাকাউন্ট প্রতারণা'),
  'category.urgency': _Entry('Urgency', 'জরুরিতা'),
  'category.impersonation':
      _Entry('Impersonation', 'প্রতারণামূলক ছদ্মবেশ'),
  'category.suspiciousLink':
      _Entry('Suspicious Link', 'সন্দেহজনক লিংক'),
  'category.suspiciousDomain':
      _Entry('Suspicious Domain', 'সন্দেহজনক ডোমেইন'),
  'category.shortenedLink':
      _Entry('Shortened Link', 'সংক্ষিপ্ত লিংক'),
  'category.riskyDownload':
      _Entry('Risky Download', 'ঝুঁকিপূর্ণ ডাউনলোড'),
  'category.invalid': _Entry('Invalid', 'অবৈধ'),
  'category.phone': _Entry('Phone Number', 'ফোন নম্বর'),
  'category.security': _Entry('Security', 'নিরাপত্তা'),

  // ─────────── RiskEngine reasons ───────────
  'reason.urgency':
      _Entry('Creates a sense of urgency', 'জরুরিতার অনুভূতি তৈরি করে'),
  'reason.paymentScam':
      _Entry('Requests money or payment', 'টাকা বা পেমেন্ট চাইছে'),
  'reason.credentialTheft': _Entry(
    'Requests sensitive authentication information',
    'সংবেদনশীল পাসওয়ার্ড বা তথ্য চাইছে',
  ),
  'reason.prizeScam': _Entry(
    'Contains a prize or winning claim',
    'পুরস্কার বা জেতার দাবি রয়েছে',
  ),
  'reason.accountScam': _Entry(
    'Uses an account suspension or closure threat',
    'অ্যাকাউন্ট বন্ধ বা স্থগিতের হুমকি দিচ্ছে',
  ),
  'reason.jobScam': _Entry(
    'Contains possible job-offer scam indicators',
    'সম্ভাব্য চাকরির প্রতারণার ইঙ্গিত রয়েছে',
  ),
  'reason.kycUpdate': _Entry(
    'Asks you to update KYC or NID details',
    'KYC বা জাতীয় পরিচয়পত্রের তথ্য আপডেট করতে বলছে',
  ),
  'reason.simBlockThreat': _Entry(
    'Threatens to block your SIM or IMEI',
    'আপনার SIM বা IMEI ব্লক করার হুমকি দিচ্ছে',
  ),
  'reason.fakeCourier': _Entry(
    'Implies a courier or parcel delivery issue',
    'কুরিয়ার বা পার্সেল ডেলিভারি সমস্যার কথা বলছে',
  ),
  'reason.utilityBill': _Entry(
    'Mentions a utility bill payment (DESCO, DPDC, WASA, etc.)',
    'বিদ্যুৎ/পানি/গ্যাস বিল পেমেন্টের কথা বলছে',
  ),
  'reason.govtSubsidy': _Entry(
    'Offers a government subsidy or relief payment',
    'সরকারি ভর্তুকি বা সাহায্যের টাকা প্রদানের কথা বলছে',
  ),
  'reason.policeThreat': _Entry(
    'Uses legal or police threats to pressure you',
    'আইনি বা পুলিশের হুমকি দিয়ে চাপ দিচ্ছে',
  ),
  'reason.familyImpersonation': _Entry(
    'Pretends to be a family member with a new number',
    'নতুন নম্বর থেকে পরিবারের কেউ সেজে কথা বলছে',
  ),
  'reason.cryptoInvestment': _Entry(
    'Promotes a crypto or investment scheme',
    'ক্রিপ্টো বা বিনিয়োগ স্কিমের প্রচার করছে',
  ),
  'reason.romance': _Entry(
    'Romance or matrimonial scam indicators',
    'রোমান্স বা বিয়ের প্রতারণার ইঙ্গিত রয়েছে',
  ),
  'reason.cashbackBonus': _Entry(
    'Lures you with cashback or reward points',
    'ক্যাশব্যাক বা রিওয়ার্ড পয়েন্টের লোভ দিচ্ছে',
  ),
  'reason.freelanceJob': _Entry(
    'Work-from-home or freelance job scam indicators',
    'ঘরে বসে কাজ বা ফ্রিল্যান্সের প্রতারণার ইঙ্গিত',
  ),
  'reason.microcreditLoan': _Entry(
    'Promises a quick or microcredit loan',
    'দ্রুত লোন বা ক্ষুদ্রঋণের প্রতিশ্রুতি দিচ্ছে',
  ),
  'reason.ecommerceRefund': _Entry(
    'Pretends to offer an e-commerce refund',
    'ই-কমার্স রিফান্ডের নাম করছে',
  ),
  'reason.deviceBait': _Entry(
    'Offers a free phone or device as bait',
    'বিনামূল্যে ফোন বা ডিভাইস দেওয়ার লোভ দিচ্ছে',
  ),
  'reason.otpShareRequest': _Entry(
    'Asks you to share your OTP with an agent',
    'এজেন্টের সাথে OTP শেয়ার করতে বলছে',
  ),
  'reason.containsLink':
      _Entry('Contains a web link', 'একটি ওয়েব লিংক রয়েছে'),
  'reason.suspiciousUrlPatterns': _Entry(
    'The link contains suspicious URL patterns',
    'লিংকে সন্দেহজনক URL প্যাটার্ন রয়েছে',
  ),
  'reason.bdPhoneNumber': _Entry(
    'Contains a Bangladesh phone number',
    'একটি বাংলাদেশি ফোন নম্বর রয়েছে',
  ),
  'reason.orgImpersonation': _Entry(
    'May be impersonating an organization or service',
    'কোনো প্রতিষ্ঠান বা সেবার ছদ্মবেশ ধারণ করতে পারে',
  ),
  'reason.paymentPlusSensitive': _Entry(
    'Combines a payment request with sensitive information',
    'পেমেন্টের অনুরোধের সাথে সংবেদনশীল তথ্য চাইছে',
  ),
  'reason.urgencyPlusUrl': _Entry(
    'Uses urgency together with a web link',
    'জরুরিতার সাথে একটি ওয়েব লিংক দিচ্ছে',
  ),
  'reason.prizePlusPayment': _Entry(
    'Requests payment related to a prize or reward',
    'পুরস্কার বা পুরস্কার সংক্রান্ত পেমেন্ট চাইছে',
  ),
  'reason.genericMatch': _Entry(
    'Matches a known scam pattern',
    'পরিচিত প্রতারণার প্যাটার্নের সাথে মিলে যাচ্ছে',
  ),

  // ─────────── UrlRiskEngine reasons ───────────
  'urlReason.noUrl':
      _Entry('No URL was provided.', 'কোনো URL দেওয়া হয়নি।'),
  'urlReason.notHttps':
      _Entry('The website does not use HTTPS.', 'ওয়েবসাইট HTTPS ব্যবহার করছে না।'),
  'urlReason.longUrl':
      _Entry('The URL is unusually long.', 'URL অস্বাভাবিক দীর্ঘ।'),
  'urlReason.ipAddress': _Entry(
    'The link uses an IP address instead of a normal domain.',
    'লিংকে সাধারণ ডোমেইনের বদলে IP ঠিকানা ব্যবহার করা হয়েছে।',
  ),
  'urlReason.abuseTld': _Entry(
    'Uses a frequently-abused top-level domain',
    'প্রতারণায় প্রায়ই ব্যবহৃত একটি ডোমেইন এক্সটেনশন ব্যবহার করছে',
  ),
  'urlReason.dangerousExt': _Entry(
    'Links directly to a downloadable executable file',
    'সরাসরি ডাউনলোডযোগ্য নির্বাহী ফাইলের লিংক',
  ),
  'urlReason.phishingTerms': _Entry(
    'Contains potentially sensitive or phishing-related terms.',
    'সম্ভাব্য সংবেদনশীল বা ফিশিং-সম্পর্কিত শব্দ রয়েছে।',
  ),
  'urlReason.foreignTld': _Entry(
    'Hosted on a TLD associated with offshore scam operations.',
    'বিদেশি প্রতারণামূলক কার্যক্রমে ব্যবহৃত একটি ডোমেইনে হোস্ট করা।',
  ),
  'urlReason.shortener':
      _Entry('Uses a URL shortening service.', 'URL সংক্ষেপণ পরিষেবা ব্যবহার করছে।'),
  'urlReason.manySubdomains': _Entry(
    'The domain contains an unusually large number of subdomains.',
    'ডোমেইনে অস্বাভাবিক বেশি সংখ্যক সাব-ডোমেইন রয়েছে।',
  ),
  'urlReason.atSymbol': _Entry(
    'Contains an @ symbol that can hide the actual destination.',
    'একটি @ চিহ্ন রয়েছে যা প্রকৃত গন্তব্য লুকাতে পারে।',
  ),
  'urlReason.unusualStructure': _Entry(
    'Contains an unusual URL structure.',
    'অস্বাভাবিক URL কাঠামো রয়েছে।',
  ),
  'urlReason.brandName': _Entry(
    'The URL contains a recognizable brand or service name.',
    'URL-এ একটি পরিচিত ব্র্যান্ড বা সেবার নাম রয়েছে।',
  ),
  'urlReason.brandPlusPhishing': _Entry(
    'A brand name appears together with phishing-related terms.',
    'একটি ব্র্যান্ডের নামের সাথে ফিশিং-সম্পর্কিত শব্দ ব্যবহৃত হয়েছে।',
  ),
  'urlReason.shortenerPlusPhishing': _Entry(
    'A shortened URL contains sensitive or phishing-related terms.',
    'সংক্ষিপ্ত URL-এ সংবেদনশীল বা ফিশিং-সম্পর্কিত শব্দ রয়েছে।',
  ),

  // ─────────── PhoneRiskEngine reasons ───────────
  'phoneReason.invalidNumber': _Entry(
    'This does not appear to be a valid Bangladesh mobile number.',
    'এটি একটি বৈধ বাংলাদেশি মোবাইল নম্বর বলে মনে হচ্ছে না।',
  ),
  'phoneReason.oneReport':
      _Entry('This number has been reported by users.', 'এই নম্বরটি ব্যবহারকারীদের দ্বারা রিপোর্ট করা হয়েছে।'),
  'phoneReason.multipleReports': _Entry(
    'Multiple users have reported this number.',
    'একাধিক ব্যবহারকারী এই নম্বরটি রিপোর্ট করেছেন।',
  ),
  'phoneReason.manyReports':
      _Entry('This number has received many reports.', 'এই নম্বরটি অনেক রিপোর্ট পেয়েছে।'),
  'phoneReason.scamReports': _Entry(
    'Users have reported possible scam activity.',
    'ব্যবহারকারীরা সম্ভাব্য প্রতারণামূলক কার্যকলাপ রিপোর্ট করেছেন।',
  ),
  'phoneReason.paymentReports': _Entry(
    'Users have reported payment-related activity.',
    'ব্যবহারকারীরা পেমেন্ট সম্পর্কিত কার্যকলাপ রিপোর্ট করেছেন।',
  ),
  'phoneReason.otpReports': _Entry(
    'Users have reported requests for OTP or verification codes.',
    'ব্যবহারকারীরা OTP বা ভেরিফিকেশন কোড চাওয়ার রিপোর্ট করেছেন।',
  ),
  'phoneReason.jobReports':
      _Entry('Users have reported suspicious job offers.', 'ব্যবহারকারীরা সন্দেহজনক চাকরির অফার রিপোর্ট করেছেন।'),
  'phoneOperator.unknown': _Entry('Unknown', 'অজানা'),

  // ─────────── Recommendations: critical ───────────
  'rec.critical.1':
      _Entry('Do not click any links.', 'কোনো লিংকে ক্লিক করবেন না।'),
  'rec.critical.2':
      _Entry('Do not send money.', 'টাকা পাঠাবেন না।'),
  'rec.critical.3': _Entry(
    'Never share OTP, PIN, or passwords.',
    'কখনো OTP, PIN বা পাসওয়ার্ড শেয়ার করবেন না।',
  ),
  'rec.critical.4': _Entry(
    'Verify the claim through an official channel.',
    'দাবিটি সরকারি/প্রাতিষ্ঠানিক চ্যানেলে যাচাই করুন।',
  ),
  'rec.critical.url.1':
      _Entry('Do not open this link.', 'এই লিংকটি খুলবেন না।'),
  'rec.critical.url.2':
      _Entry('Do not enter your password or OTP.', 'আপনার পাসওয়ার্ড বা OTP দেবেন না।'),
  'rec.critical.url.3':
      _Entry('Do not provide payment information.', 'পেমেন্টের তথ্য দেবেন না।'),
  'rec.critical.url.4':
      _Entry('Verify the website through an official source.', 'ওয়েবসাইটটি সরকারি উৎস থেকে যাচাই করুন।'),
  'rec.critical.phone.1':
      _Entry('Do not send money to this number.', 'এই নম্বরে টাকা পাঠাবেন না।'),
  'rec.critical.phone.2':
      _Entry('Do not share OTP, PIN, or passwords.', 'OTP, PIN বা পাসওয়ার্ড শেয়ার করবেন না।'),
  'rec.critical.phone.3': _Entry(
    'Avoid calling back if you do not know the caller.',
    'কলার চেনেন না এমন হলে কল ব্যাক করবেন না।',
  ),
  'rec.critical.phone.4': _Entry(
    'Consider blocking and reporting the number.',
    'নম্বরটি ব্লক ও রিপোর্ট করার কথা বিবেচনা করুন।',
  ),

  // ─────────── Recommendations: high ───────────
  'rec.high.msg.1':
      _Entry('Avoid clicking links in the message.', 'বার্তার লিংকে ক্লিক করা এড়িয়ে চলুন।'),
  'rec.high.msg.2':
      _Entry('Do not share sensitive information.', 'সংবেদনশীল তথ্য শেয়ার করবেন না।'),
  'rec.high.msg.3':
      _Entry('Verify the sender independently.', 'প্রেরককে স্বতন্ত্রভাবে যাচাই করুন।'),
  'rec.high.url.1':
      _Entry('Avoid opening this link.', 'এই লিংকটি খোলা এড়িয়ে চলুন।'),
  'rec.high.url.2':
      _Entry('Do not enter sensitive information.', 'সংবেদনশীল তথ্য দেবেন না।'),
  'rec.high.url.3':
      _Entry('Verify the domain independently.', 'ডোমেইনটি স্বতন্ত্রভাবে যাচাই করুন।'),
  'rec.high.phone.1':
      _Entry('Be extremely careful when communicating.', 'যোগাযোগের সময় অত্যন্ত সতর্ক থাকুন।'),
  'rec.high.phone.2':
      _Entry('Do not share sensitive information.', 'সংবেদনশীল তথ্য শেয়ার করবেন না।'),
  'rec.high.phone.3':
      _Entry('Verify the caller independently.', 'কলারকে স্বতন্ত্রভাবে যাচাই করুন।'),

  // ─────────── Recommendations: medium ───────────
  'rec.medium.msg.1':
      _Entry('Be careful before responding.', 'উত্তর দেওয়ার আগে সতর্ক থাকুন।'),
  'rec.medium.msg.2':
      _Entry('Verify the sender or organization.', 'প্রেরক বা প্রতিষ্ঠানকে যাচাই করুন।'),
  'rec.medium.msg.3':
      _Entry('Avoid sharing personal information.', 'ব্যক্তিগত তথ্য শেয়ার করা এড়িয়ে চলুন।'),
  'rec.medium.url.1':
      _Entry('Proceed carefully.', 'সতর্কতার সাথে এগিয়ে যান।'),
  'rec.medium.url.2': _Entry(
    'Check the domain before entering information.',
    'তথ্য দেওয়ার আগে ডোমেইন পরীক্ষা করুন।',
  ),
  'rec.medium.url.3':
      _Entry('Avoid providing sensitive information.', 'সংবেদনশীল তথ্য প্রদান এড়িয়ে চলুন।'),
  'rec.medium.phone.1':
      _Entry('Proceed with caution.', 'সতর্কতার সাথে এগিয়ে যান।'),
  'rec.medium.phone.2': _Entry(
    'Do not share financial or personal information.',
    'আর্থিক বা ব্যক্তিগত তথ্য শেয়ার করবেন না।',
  ),

  // ─────────── Recommendations: low ───────────
  'rec.low.msg.1':
      _Entry('Stay cautious.', 'সতর্ক থাকুন।'),
  'rec.low.msg.2': _Entry(
    'Verify important claims before taking action.',
    'পদক্ষেপ নেওয়ার আগে গুরুত্বপূর্ণ দাবি যাচাই করুন।',
  ),
  'rec.low.url.1':
      _Entry('The URL has some warning signs.', 'URL-এ কিছু সতর্কতা রয়েছে।'),
  'rec.low.url.2':
      _Entry('Verify the website before continuing.', 'এগিয়ে যাওয়ার আগে ওয়েবসাইট যাচাই করুন।'),
  'rec.low.phone.1':
      _Entry('Stay cautious if you do not recognize this number.', 'নম্বরটি চেনেন না এমন হলে সতর্ক থাকুন।'),

  // ─────────── Recommendations: safe ───────────
  'rec.safe.msg.1':
      _Entry('No major warning signs were detected.', 'কোনো বড় সতর্কতা পাওয়া যায়নি।'),
  'rec.safe.msg.2': _Entry(
    'Continue to avoid sharing sensitive information.',
    'সংবেদনশীল তথ্য শেয়ার এড়িয়ে চলুন।',
  ),
  'rec.safe.url.1':
      _Entry('No major warning signs were detected.', 'কোনো বড় সতর্কতা পাওয়া যায়নি।'),
  'rec.safe.url.2':
      _Entry('Always verify important websites independently.', 'গুরুত্বপূর্ণ ওয়েবসাইট সবসময় স্বতন্ত্রভাবে যাচাই করুন।'),
  'rec.safe.phone.1':
      _Entry('No suspicious reports were found.', 'কোনো সন্দেহজনক রিপোর্ট পাওয়া যায়নি।'),
  'rec.safe.phone.2': _Entry(
    'Still avoid sharing OTP, PIN, or passwords.',
    'তবুও OTP, PIN বা পাসওয়ার্ড শেয়ার করা এড়িয়ে চলুন।',
  ),

  // ─────────── URL-specific extras ───────────
  'urlRec.invalid.1':
      _Entry('Enter a valid website URL.', 'একটি বৈধ ওয়েবসাইট URL দিন।'),

  // ─────────── Generic / shared result screen labels ───────────
  'result.label.category': _Entry('Category', 'বিভাগ'),
  'result.label.confidence': _Entry('Confidence', 'নিশ্চয়তা'),
  'result.label.score': _Entry('Risk score: {score} / 100', 'ঝুঁকির স্কোর: {score} / ১০০'),
  'result.label.whatWeFound': _Entry('What we found ({count})', 'আমরা যা পেয়েছি ({count})'),
  'result.label.safetyTips': _Entry('Safety tips', 'নিরাপত্তা পরামর্শ'),
  'result.label.noSignals': _Entry(
    'No scam signals were detected. Stay alert - always verify '
    'unexpected payment or login requests.',
    'কোনো প্রতারণার ইঙ্গিত পাওয়া যায়নি। সতর্ক থাকুন — অপ্রত্যাশিত পেমেন্ট বা লগইন অনুরোধ সবসময় যাচাই করুন।',
  ),
  'result.label.aiBadge': _Entry('✨ AI Analysis', '✨ AI বিশ্লেষণ'),
  'result.label.back': _Entry('Back', 'ফিরে যান'),
  'result.label.copy': _Entry('Copy report', 'রিপোর্ট কপি করুন'),
  'result.label.copied': _Entry('Report copied to clipboard', 'রিপোর্ট ক্লিপবোর্ডে কপি হয়েছে'),
  'result.label.appBarTitle': _Entry('Result', 'ফলাফল'),

  // ─────────── RiskStyle badges ───────────
  'badge.safe': _Entry('SAFE', 'নিরাপদ'),
  'badge.low': _Entry('LOW RISK', 'কম ঝুঁকি'),
  'badge.medium': _Entry('MEDIUM RISK', 'মাঝারি ঝুঁকি'),
  'badge.high': _Entry('HIGH RISK', 'উচ্চ ঝুঁকি'),
  'badge.critical': _Entry('CRITICAL RISK', 'অত্যন্ত ঝুঁকিপূর্ণ'),

  // ─────────── Report clipboard (Bangla when BN) ───────────
  'clipboard.title':
      _Entry('NirapodClick Risk Report', 'নিরাপদক্লিক ঝুঁকি রিপোর্ট'),
  'clipboard.level':
      _Entry('Level', 'স্তর'),
  'clipboard.score':
      _Entry('Score', 'স্কোর'),
  'clipboard.category':
      _Entry('Category', 'বিভাগ'),
  'clipboard.confidence':
      _Entry('Confidence', 'নিশ্চয়তা'),
  'clipboard.signals':
      _Entry('Signals', 'ইঙ্গিত'),
  'clipboard.recommendations':
      _Entry('Recommendations', 'পরামর্শ'),
};

// ─────────────────────────────────────────
// Locale-aware risk-level badges / titles
// ─────────────────────────────────────────
//
// `RiskStyle.badge` is hardcoded English and that's intentional — the
// helper struct stays a `const` and is reachable from anywhere without
// touching a Flutter `BuildContext`. Widgets that need a *localized*
// badge (history rows, alerts rows, recent-scans row, inline result
// card, full result page) reach for the extensions below instead,
// which route through the singleton [Localizer].
//
// Keeping these as extensions (rather than methods on the enum itself)
// avoids touching the model files: `risk_result.dart` and friends stay
// pure data and don't grow a dependency on the locale layer.

extension RiskLevelL10n on RiskLevel {
  /// Localized short badge label, e.g. SAFE / নিরাপদ.
  String get localizedBadge {
    final loc = Localizer.instance;
    switch (this) {
      case RiskLevel.safe:
        return loc.tr('badge.safe');
      case RiskLevel.low:
        return loc.tr('badge.low');
      case RiskLevel.medium:
        return loc.tr('badge.medium');
      case RiskLevel.high:
        return loc.tr('badge.high');
      case RiskLevel.critical:
        return loc.tr('badge.critical');
    }
  }

  /// Localized long headline shown on the full result page, e.g.
  /// "Critical warning" / "গুরুতর সতর্কতা".
  String get localizedHeadline {
    final loc = Localizer.instance;
    switch (this) {
      case RiskLevel.safe:
        return loc.tr('level.safe');
      case RiskLevel.low:
        return loc.tr('level.low');
      case RiskLevel.medium:
        return loc.tr('level.medium');
      case RiskLevel.high:
        return loc.tr('level.high');
      case RiskLevel.critical:
        return loc.tr('level.critical');
    }
  }
}

extension UrlRiskLevelL10n on UrlRiskLevel {
  String get localizedBadge {
    final loc = Localizer.instance;
    switch (this) {
      case UrlRiskLevel.safe:
        return loc.tr('badge.safe');
      case UrlRiskLevel.low:
        return loc.tr('badge.low');
      case UrlRiskLevel.medium:
        return loc.tr('badge.medium');
      case UrlRiskLevel.high:
        return loc.tr('badge.high');
      case UrlRiskLevel.critical:
        return loc.tr('badge.critical');
    }
  }
}

extension PhoneRiskLevelL10n on PhoneRiskLevel {
  String get localizedBadge {
    final loc = Localizer.instance;
    switch (this) {
      case PhoneRiskLevel.safe:
        return loc.tr('badge.safe');
      case PhoneRiskLevel.low:
        return loc.tr('badge.low');
      case PhoneRiskLevel.medium:
        return loc.tr('badge.medium');
      case PhoneRiskLevel.high:
        return loc.tr('badge.high');
      case PhoneRiskLevel.critical:
        return loc.tr('badge.critical');
    }
  }
}
