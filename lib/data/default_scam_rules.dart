import '../models/scam_rule.dart';

/// Shipped-with-the-APK fallback for [ScamRuleService.loadRules].
///
/// These six rules are extracted byte-for-byte from
/// `lib/services/risk_engine.dart` lines 15–155 — the keyword arrays
/// that previously lived as `final urgencyPatterns = [...]` etc.
/// inside `analyzeMessage`. If a Firestore read fails, the network is
/// down, or the user is on a brand-new install with an empty
/// `scam_patterns` collection, [ScamRuleService] returns this list —
/// same detection as today, no degradation.
///
/// When the admin panel first edits a rule in Firestore, that doc
/// overrides the corresponding entry here on next cold start. The
/// auto-seed uses `SetOptions(merge: true)` so it never stomps an
/// existing admin edit.
const List<ScamRule> defaultScamRules = [
  ScamRule(
    id: 'urgency',
    category: 'Urgency',
    keywords: [
      'urgent', 'immediately', 'act now', 'right now', 'last chance',
      'জরুরি', 'এখনই', 'তাড়াতাড়ি', 'অতি জরুরি', 'আজকের মধ্যে',
    ],
    score: 15,
  ),
  ScamRule(
    id: 'payment',
    category: 'Payment Scam',
    keywords: [
      'send money', 'send payment', 'make payment', 'pay now',
      'payment required', 'registration fee', 'processing fee',
      'টাকা পাঠান', 'টাকা দিন', 'পেমেন্ট করুন', 'ফি দিন',
      'রেজিস্ট্রেশন ফি', 'প্রসেসিং ফি',
    ],
    score: 25,
  ),
  ScamRule(
    id: 'sensitive',
    category: 'Credential Theft',
    keywords: [
      'otp', 'one time password', 'pin', 'password',
      'verification code', 'security code',
      'ওটিপি', 'পিন', 'পাসওয়ার্ড', 'ভেরিফিকেশন কোড', 'সিকিউরিটি কোড',
    ],
    score: 30,
  ),
  ScamRule(
    id: 'prize',
    category: 'Prize Scam',
    keywords: [
      'you won', 'you have won', 'winner', 'lottery', 'prize', 'reward',
      'congratulations',
      'পুরস্কার', 'লটারি', 'আপনি জিতেছেন', 'অভিনন্দন', 'পুরস্কার পেয়েছেন',
    ],
    score: 20,
  ),
  ScamRule(
    id: 'account',
    category: 'Account Scam',
    keywords: [
      'account blocked', 'account suspended', 'account will be closed',
      'account disabled', 'verify your account',
      'অ্যাকাউন্ট বন্ধ', 'অ্যাকাউন্ট ব্লক', 'অ্যাকাউন্ট বাতিল',
      'অ্যাকাউন্ট স্থগিত', 'অ্যাকাউন্ট ভেরিফাই',
    ],
    score: 20,
  ),
  ScamRule(
    id: 'job',
    category: 'Job Scam',
    keywords: [
      'work from home', 'easy income', 'earn money', 'part time job',
      'online job', 'job opportunity',
      'চাকরি', 'জব', 'ঘরে বসে আয়', 'অনলাইন কাজ',
      'পার্ট টাইম', 'নিয়োগ',
    ],
    score: 15,
  ),

  // ─── Bangladesh-specific patterns ─────────────────────────────────────
  //
  // These close gaps surfaced by the AI-call audit. Each category was
  // either entirely absent from the bundled rules or only triggered via
  // a downstream combinator (e.g. `government` only fired when paired
  // with credential/payment). Adding standalone rules lets obvious BD
  // scams resolve locally instead of falling through to Gemini.

  // KYC / NID update phish — bank-style "update your KYC or account
  // suspended" wording.
  ScamRule(
    id: 'kyc_update',
    category: 'KYC Update',
    keywords: [
      'kyc update', 'kyc verify', 'kyc verification', 'update kyc',
      'nid update', 'nid verification', 'update your nid',
      'কেওয়াইসি', 'কেয়াইসি', 'এনআইডি আপডেট', 'ভেরিফাই করুন',
    ],
    score: 25,
  ),

  // SIM / IMEI block threat — "your mobile number will be blocked".
  ScamRule(
    id: 'imei_sim_block',
    category: 'SIM Block Threat',
    keywords: [
      'sim blocked', 'sim will be blocked', 'imei blocked',
      'imei will be blocked', 'mobile number blocked',
      'সিম ব্লক', 'সিম বন্ধ', 'মোবাইল নম্বর ব্লক', 'আইএমইআই ব্লক',
    ],
    score: 25,
  ),

  // Fake courier / parcel delivery scam (Sundarban, SA, DHL, etc.).
  ScamRule(
    id: 'fake_courier',
    category: 'Fake Courier',
    keywords: [
      'courier', 'parcel', 'package', 'customs duty', 'customs fee',
      'sundarban', 'sa parcel', 'dhl delivery',
      'কুরিয়ার', 'পার্সেল', 'কাস্টমস ডিউটি', 'ডেলিভারি ফি',
    ],
    score: 15,
  ),

  // Utility-bill phish (DESCO, DPDC, WASA, Titas, BTCL, etc.).
  ScamRule(
    id: 'utility_bill',
    category: 'Utility Bill',
    keywords: [
      'desco', 'dpdc', 'wasa', 'titas', 'btcl', 'electricity bill',
      'power bill', 'gas bill', 'water bill',
      'বিদ্যুৎ বিল', 'গ্যাস বিল', 'পানির বিল', 'বিদ্যুৎ বকেয়া',
    ],
    score: 20,
  ),

  // Government subsidy / relief scam.
  ScamRule(
    id: 'govt_subsidy',
    category: 'Govt Subsidy',
    keywords: [
      'govt subsidy', 'government subsidy', 'relief fund', 'allowance',
      'subsidy', 'government grant', 'govt grant',
      'সরকারি ভর্তুকি', 'অনুদান', 'সরকারি অনুদান', 'ভর্তুকি',
    ],
    score: 25,
  ),

  // Police / court threat wording (warrant, arrest, fine).
  ScamRule(
    id: 'police_threat',
    category: 'Police Threat',
    keywords: [
      'arrest warrant', 'warrant', 'arrest', 'legal action', 'fine',
      'court notice', 'police case',
      'গ্রেপ্তার', 'জরিমানা', 'পুলিশ কেস', 'আদালতের নোটিশ',
      'ওয়ারেন্ট',
    ],
    score: 25,
  ),

  // "Hi mom / আম্মা" family-member impersonation on a new number.
  //
  // English keywords are deliberately only the strong-context phrases
  // ("new number", "lost my phone") — bare "hi mom" / "hi dad" appear
  // in many benign family chats and would create false positives.
  // Bangla phrases (`আম্মা`, `বাবা`, `নতুন নম্বর`) are kept because
  // they're rare in non-family-scam Bangla messages.
  ScamRule(
    id: 'family_impersonation',
    category: 'Family Impersonation',
    keywords: [
      'this is my new number', 'new number', 'lost my phone',
      'আম্মা', 'বাবা', 'ভাই', 'নতুন নম্বর', 'ফোন হারিয়ে গেছে',
    ],
    score: 25,
  ),

  // Crypto / investment / trading scam.
  ScamRule(
    id: 'crypto_investment',
    category: 'Crypto Investment',
    keywords: [
      'bitcoin', 'ethereum', 'crypto', 'investment', 'trading',
      'double in 24 hours', 'guaranteed returns',
      'বিটকয়েন', 'ক্রিপ্টো', 'ইনভেস্টমেন্ট', 'ট্রেডিং', 'মুনাফা',
    ],
    score: 25,
  ),

  // Romance / matrimonial scam.
  ScamRule(
    id: 'romance',
    category: 'Romance',
    keywords: [
      'my dear', 'my love', 'bahadur', 'i love you', 'matrimonial',
      'lonely', 'need a partner',
      'প্রিয়', 'ভালোবাসা', 'বিয়ে', 'একা', 'সঙ্গী চাই',
    ],
    score: 20,
  ),

  // Cashback / bonus / reward-points scam (distinct from prize).
  ScamRule(
    id: 'cashback_bonus',
    category: 'Cashback Bonus',
    keywords: [
      'cashback', 'bonus', 'reward points', 'redeem points',
      'points expiring', 'claim your bonus',
      'ক্যাশব্যাক', 'বোনাস', 'পয়েন্ট রিডিম', 'পয়েন্ট মেয়াদ শেষ',
    ],
    score: 20,
  ),

  // Freelance / data-entry / typing job scam (subset of job but
  // specific enough to deserve its own category — these are the
  // highest-volume BD job scams on Telegram).
  ScamRule(
    id: 'freelance_job',
    category: 'Freelance Job',
    keywords: [
      'freelancing', 'freelance', 'outsourcing', 'data entry', 'typing job',
      'youtube like', 'youtube subscribe', 'task job',
      'ফ্রিল্যান্সিং', 'আউটসোর্সিং', 'ডাটা এন্ট্রি', 'টাইপিং জব',
      'লাইক সাবস্ক্রাইব',
    ],
    score: 15,
  ),

  // Microcredit / NGO loan offer.
  ScamRule(
    id: 'microcredit_loan',
    category: 'Microcredit Loan',
    keywords: [
      'microcredit', 'micro-credit', 'instant loan', 'quick loan',
      'ng loan', 'low interest loan',
      'মাইক্রোক্রেডিট', 'দ্রুত ঋণ', 'ঋণ', 'লোন', 'সহজ ঋণ',
    ],
    score: 20,
  ),

  // E-commerce refund (Daraz, Evaly, etc.).
  ScamRule(
    id: 'ecommerce_refund',
    category: 'E-commerce Refund',
    keywords: [
      'daraz', 'evaly', 'refund', 'order refund', 'cashback refund',
      'return money', 'product return',
      'ইভ্যালি', 'রিফান্ড', 'অর্ডার রিফান্ড', 'টাকা ফেরত',
    ],
    score: 20,
  ),

  // Free iPhone / free gift device-bait scam.
  ScamRule(
    id: 'device_bait',
    category: 'Device Bait',
    keywords: [
      'free iphone', 'free gift', 'free samsung', 'free smartphone',
      'free mobile', 'win a phone',
      'ফ্রি আইফোন', 'ফ্রি গিফট', 'ফ্রি মোবাইল', 'ফ্রি ফোন',
    ],
    score: 20,
  ),

  // "Share your OTP with our customer-care agent" — distinct from
  // the credential-theft rule (which catches OTP itself); this
  // catches the *request* to share it with a third party.
  ScamRule(
    id: 'otp_share_request',
    category: 'OTP Share Request',
    keywords: [
      'share otp', 'send otp', 'forward otp', 'tell me the otp',
      'customer care agent', 'helpdesk agent', 'technical support agent',
      'ওটিপি শেয়ার', 'ওটিপি পাঠান', 'কাস্টমার কেয়ার এজেন্ট',
      'হেল্প ডেস্ক',
    ],
    score: 30,
  ),
];
