import '../models/url_scam_rule.dart';

/// Shipped-with-the-APK fallback for [UrlScamRuleService.loadRules].
///
/// These rules are extracted byte-for-byte from the hardcoded lists that
/// previously lived in `lib/services/url_risk_engine.dart` lines 67–281.
/// If Firestore is unreachable, the network is down, or the user is on a
/// brand-new install with an empty `url_scam_rules` collection,
/// [UrlScamRuleService] returns this list — same detection as today, no
/// degradation.
///
/// When an admin edits a rule in Firestore (via the Firebase Console —
/// writes are denied client-side by `firestore.rules`), that doc
/// overrides the corresponding entry here on next cold start.
///
/// Each entry is **one [UrlScamRule] per pattern** (one doc per TLD, per
/// brand, per keyword, …). At v1's expected scale (~70 rules total) this
/// keeps the doc count small, makes the Firebase Console diff-friendly,
/// and matches the granular-edit intent of an admin UI.
///
/// The 6 structural checks in `url_risk_engine.dart` (HTTPS check, length
/// > 100, IP regex, `@` symbol, `//` after position 8, subdomain count
/// ≥ 3) are intentionally **not** represented here — they are
/// shape-based signals, not data-driven keywords, and have no parameters
/// an admin would reasonably want to tune.
const List<UrlScamRule> defaultUrlScamRules = [
  // ─── Suspicious TLDs ─────────────────────────────────────────────────
  //
  // Cheap / abuse-prone top-level domains. A TLD hit contributes a
  // `Suspicious Domain` category and the `urlReason.abuseTld` reason
  // (with the matched TLD appended, e.g. "Uses a frequently-abused
  // top-level domain (.tk)").
  UrlScamRule(
    id: 'tld_tk',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.tk',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_ml',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.ml',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_cf',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.cf',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_gq',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.gq',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_top',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.top',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_xyz',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.xyz',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_click',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.click',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_country',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.country',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_work',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.work',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_fit',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.fit',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_rest',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.rest',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_support',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.support',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_loan',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.loan',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_finance',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.finance',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_kim',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.kim',
    score: 15,
  ),
  UrlScamRule(
    id: 'tld_science',
    type: UrlScamRuleType.tld,
    category: 'Suspicious Domain',
    pattern: '.science',
    score: 15,
  ),

  // ─── Dangerous file extensions ───────────────────────────────────────
  //
  // Substring match anywhere in the URL path. `file.apk?download=1`
  // still trips it because the extension isn't tied to a token boundary.
  UrlScamRule(
    id: 'ext_apk',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.apk',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_exe',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.exe',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_zip',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.zip',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_scr',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.scr',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_bat',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.bat',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_cmd',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.cmd',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_jar',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.jar',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_iso',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.iso',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_pdf',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.pdf',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_doc',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.doc',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_docx',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.docx',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_xls',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.xls',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_xlsx',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.xlsx',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_js',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.js',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_vbs',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.vbs',
    score: 20,
  ),
  UrlScamRule(
    id: 'ext_lnk',
    type: UrlScamRuleType.extension,
    category: 'Suspicious URL',
    pattern: '.lnk',
    score: 20,
  ),

  // ─── Phishing keywords (English + Bangla) ───────────────────────────
  //
  // Substring match against the lower-cased URL. The Bangla list was
  // already widened vs. the English list to catch BD phishing wording.
  UrlScamRule(
    id: 'kw_login',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'login',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_verify',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'verify',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_verification',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'verification',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_secure',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'secure',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_account',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'account',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_update',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'update',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_confirm',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'confirm',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_password',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'password',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_signin',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'signin',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_wallet',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'wallet',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_claim',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'claim',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_reward',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'reward',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_prize',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'prize',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_free',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'free',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_bn_verify',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'ভেরিফাই',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_bn_account',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'অ্যাকাউন্ট',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_bn_prize',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'পুরস্কার',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_bn_login',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'লগইন',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_bn_password',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'পাসওয়ার্ড',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_bn_otp',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'ওটিপি',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_bn_pin',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'পিন',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_bn_payment',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'পেমেন্ট',
    score: 15,
  ),
  UrlScamRule(
    id: 'kw_bn_taka',
    type: UrlScamRuleType.keyword,
    category: 'Phishing',
    pattern: 'টাকা',
    score: 15,
  ),

  // ─── Foreign scam TLDs (soft) ────────────────────────────────────────
  //
  // Country-code TLDs historically used by offshore scam operations,
  // but also by legitimate users (.ng hosts many Nigerian businesses).
  // Soft penalty — only fires when combined with another rule.
  UrlScamRule(
    id: 'foreign_ru',
    type: UrlScamRuleType.foreignTld,
    category: 'Suspicious Domain',
    pattern: '.ru',
    score: 5,
  ),
  UrlScamRule(
    id: 'foreign_cn',
    type: UrlScamRuleType.foreignTld,
    category: 'Suspicious Domain',
    pattern: '.cn',
    score: 5,
  ),
  UrlScamRule(
    id: 'foreign_ng',
    type: UrlScamRuleType.foreignTld,
    category: 'Suspicious Domain',
    pattern: '.ng',
    score: 5,
  ),

  // ─── URL shorteners ──────────────────────────────────────────────────
  UrlScamRule(
    id: 'short_bitly',
    type: UrlScamRuleType.shortener,
    category: 'Shortened URL',
    pattern: 'bit.ly',
    score: 20,
  ),
  UrlScamRule(
    id: 'short_tinyurl',
    type: UrlScamRuleType.shortener,
    category: 'Shortened URL',
    pattern: 'tinyurl.com',
    score: 20,
  ),
  UrlScamRule(
    id: 'short_tco',
    type: UrlScamRuleType.shortener,
    category: 'Shortened URL',
    pattern: 't.co',
    score: 20,
  ),
  UrlScamRule(
    id: 'short_googl',
    type: UrlScamRuleType.shortener,
    category: 'Shortened URL',
    pattern: 'goo.gl',
    score: 20,
  ),
  UrlScamRule(
    id: 'short_isgd',
    type: UrlScamRuleType.shortener,
    category: 'Shortened URL',
    pattern: 'is.gd',
    score: 20,
  ),
  UrlScamRule(
    id: 'short_cuttly',
    type: UrlScamRuleType.shortener,
    category: 'Shortened URL',
    pattern: 'cutt.ly',
    score: 20,
  ),
  UrlScamRule(
    id: 'short_shorturlat',
    type: UrlScamRuleType.shortener,
    category: 'Shortened URL',
    pattern: 'shorturl.at',
    score: 20,
  ),

  // ─── Brand impersonation ─────────────────────────────────────────────
  //
  // Bangladeshi MFS + global brands. A brand hit only adds score on its
  // own; the brand+keyword combo adds more.
  UrlScamRule(
    id: 'brand_bkash',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'bkash',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_nagad',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'nagad',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_rocket',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'rocket',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_brac',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'brac',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_dbbl',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'dbbl',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_bank',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'bank',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_paypal',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'paypal',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_facebook',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'facebook',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_google',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'google',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_microsoft',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'microsoft',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_ibl',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'ibl',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_ebl',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'ebl',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_ucbl',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'ucbl',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_mtb',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'mtb',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_scb',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'scb',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_hsbc',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'hsbc',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_city',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'city',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_prime',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'prime',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_ific',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'ific',
    score: 10,
  ),
  UrlScamRule(
    id: 'brand_ab_bank',
    type: UrlScamRuleType.brand,
    category: 'Possible Impersonation',
    pattern: 'ab bank',
    score: 10,
  ),
];
