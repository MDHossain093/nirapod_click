import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_env.dart';
import '../models/risk_result.dart';
import '../models/url_risk_result.dart';
import 'screenshot_analyzer.dart';

/// On-device Gemini analyzer (no Firebase Cloud Functions required,
/// runs on the free Spark plan).
///
/// The API key is resolved in this order:
///   1. `--dart-define=GEMINI_API_KEY=...` at build time
///   2. The `GEMINI_API_KEY` entry in the project's `.env` file
///   3. Empty string (treated as "not configured")
///
/// The `.env` file is the recommended local-dev path: put the real key
/// in there once, then `flutter run` works without command-line flags.
/// `.env` is gitignored — the key never lands in version control.
///
/// The transport is the public HTTPS REST endpoint
/// (`generativelanguage.googleapis.com`) instead of the unmaintained
/// `google_generative_ai` Dart SDK. Model: `gemini-3.6-flash`
/// (verified working against the free Developer API as of Aug 2026;
/// if it ever 404s, swap to `gemini-2.5-flash` which is GA).
class AiService {
  static const _model = 'gemini-3.6-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/';

  final String _apiKey;
  final http.Client _client;

  /// [apiKey] is resolved from [AppEnv.geminiApiKey] when not supplied,
  /// which already encapsulates the dart-define / .env precedence.
  /// Tests can inject a literal value via [apiKey] to bypass env lookup.
  AiService({
    http.Client? client,
    String? apiKey,
  })  : _apiKey = apiKey ?? AppEnv.geminiApiKey,
        _client = client ?? http.Client();

  Future<RiskResult> analyzeMessage(String message) =>
      _generate(_buildMessagePrompt(message));

  /// URL-aware variant of [analyzeMessage]. Uses a prompt specialized
  /// for link analysis (scheme, host, path, impersonation patterns).
  /// The shared [_generateUrl] body handles request/response parsing,
  /// error mapping, and the API-key check, and carries the original URL
  /// into the returned [UrlRiskResult].
  Future<UrlRiskResult> analyzeUrl(String url) =>
      _generateUrl(_buildUrlPrompt(url), url);

  /// Screenshot-aware variant. The full extracted OCR text is passed in
  /// as a single string; Gemini is asked to return a combined
  /// `risk_score` *and* a `urls` array so we can rebuild the same
  /// [ScreenshotAnalysis] shape the local analyzer produces.
  Future<ScreenshotAnalysis> analyzeScreenshot(String text) =>
      _generateScreenshot(_buildScreenshotPrompt(text), text);

  Future<RiskResult> _generate(String prompt) async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'GEMINI_API_KEY is not set. Add it to your .env file as '
        '`GEMINI_API_KEY=YOUR_KEY` or pass '
        '`--dart-define=GEMINI_API_KEY=YOUR_KEY` at build time.',
      );
    }
    // Note: the AIzaSy-prefix shape check lives in `AppEnv.hasValidGeminiKey`
    // (and in `main.dart`'s startup diagnostic). Keeping it out of the
    // runtime path lets unit tests inject a fake key without the HTTP call
    // being blocked by a format assertion.

    final uri = Uri.parse(
      '$_endpoint$_model:generateContent?key=$_apiKey',
    );

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }

    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(envelope);
    if (text == null || text.isEmpty) {
      throw const FormatException('Gemini returned an empty body.');
    }

    final parsed = jsonDecode(text) as Map<String, dynamic>;
    final rawScore = (parsed['risk_score'] as num?)?.toInt() ?? 0;

    return RiskResult(
      level: _parseRiskLevel(parsed['risk_level'] as String?),
      score: rawScore.clamp(0, 100),
      confidence: 0.90,
      category: parsed['category'] as String? ?? 'General',
      reasons: _stringList(parsed['reasons']),
      recommendations: _stringList(parsed['recommendations']),
      usedAi: true,
    );
  }

  /// URL-specialized twin of [_generate]. Same wire protocol, but
  /// packs the parsed envelope into [UrlRiskResult] and echoes the
  /// original URL string so the screen can show "what was checked".
  Future<UrlRiskResult> _generateUrl(String prompt, String url) async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'GEMINI_API_KEY is not set. Add it to your .env file as '
        '`GEMINI_API_KEY=YOUR_KEY` or pass '
        '`--dart-define=GEMINI_API_KEY=YOUR_KEY` at build time.',
      );
    }

    final uri = Uri.parse(
      '$_endpoint$_model:generateContent?key=$_apiKey',
    );

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }

    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    final text = _extractText(envelope);
    if (text == null || text.isEmpty) {
      throw const FormatException('Gemini returned an empty body.');
    }

    final parsed = jsonDecode(text) as Map<String, dynamic>;
    final rawScore = (parsed['risk_score'] as num?)?.toInt() ?? 0;

    return UrlRiskResult(
      level: _parseUrlRiskLevel(parsed['risk_level'] as String?),
      score: rawScore.clamp(0, 100),
      confidence: 0.90,
      category: parsed['category'] as String? ?? 'General',
      url: url,
      reasons: _stringList(parsed['reasons']),
      recommendations: _stringList(parsed['recommendations']),
      usedAi: true,
    );
  }

  /// Screenshot-specialized twin of [_generate]. Prompts Gemini for a
  /// combined verdict plus a per-URL array, then packs the envelope
  /// into a [ScreenshotAnalysis] with `usedAi = true` so the screen
  /// can show the AI-assisted badge.
  ///
  /// The returned `messageResult` reflects the combined AI verdict
  /// (not the local rule engine); `urlResults` is filled from the
  /// AI's `urls` array, one [UrlRiskResult] per embedded link.
  Future<ScreenshotAnalysis> _generateScreenshot(
    String prompt,
    String text,
  ) async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'GEMINI_API_KEY is not set. Add it to your .env file as '
        '`GEMINI_API_KEY=YOUR_KEY` or pass '
        '`--dart-define=GEMINI_API_KEY=YOUR_KEY` at build time.',
      );
    }

    final uri = Uri.parse(
      '$_endpoint$_model:generateContent?key=$_apiKey',
    );

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.2,
          'responseMimeType': 'application/json',
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API error ${response.statusCode}: ${response.body}',
      );
    }

    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    final body = _extractText(envelope);
    if (body == null || body.isEmpty) {
      throw const FormatException('Gemini returned an empty body.');
    }

    final parsed = jsonDecode(body) as Map<String, dynamic>;
    final rawScore = (parsed['risk_score'] as num?)?.toInt() ?? 0;

    final messageResult = RiskResult(
      level: _parseRiskLevel(parsed['risk_level'] as String?),
      score: rawScore.clamp(0, 100),
      confidence: 0.90,
      category: parsed['category'] as String? ?? 'General',
      reasons: _stringList(parsed['reasons']),
      recommendations: _stringList(parsed['recommendations']),
      usedAi: true,
    );

    final urlResults = _parseUrlResults(parsed['urls']);

    // Category for the combined verdict: prefer the URL engine's
    // category when at least one link scored, otherwise the message
    // engine's category (mirrors `ScreenshotAnalyzer.analyze`).
    final hasUrls = urlResults.isNotEmpty;
    final highestUrlScore =
        hasUrls ? urlResults.first.score : 0;
    final category = hasUrls && highestUrlScore >= messageResult.score
        ? urlResults.first.category
        : messageResult.category;

    // Reasons: message reasons first, then each URL's reasons prefixed
    // with "Link: " (de-duplicated) — same shape as local analyzer.
    final combinedReasons = <String>{
      ...messageResult.reasons,
      for (final u in urlResults)
        ...u.reasons.map((r) => 'Link: $r'),
    }.toList();

    return ScreenshotAnalysis(
      messageResult: messageResult,
      urlResults: urlResults,
      score: messageResult.score,
      category: category,
      reasons: combinedReasons,
      recommendations: messageResult.recommendations.toSet().toList(),
    );
  }

  /// Parse the `urls` array from the screenshot Gemini response into
  /// [UrlRiskResult] objects sorted by score descending (matches the
  /// local analyzer's "highest-URL-wins" convention). Missing or
  /// malformed entries are skipped silently — a non-2xx Gemini call
  /// would already have been thrown above.
  static List<UrlRiskResult> _parseUrlResults(Object? raw) {
    if (raw is! List) return const <UrlRiskResult>[];
    final out = <UrlRiskResult>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final url = entry['url'];
      if (url is! String || url.isEmpty) continue;
      final score = (entry['risk_score'] as num?)?.toInt() ?? 0;
      out.add(
        UrlRiskResult(
          level: _parseUrlRiskLevel(entry['risk_level'] as String?),
          score: score.clamp(0, 100),
          confidence: 0.90,
          category: (entry['category'] as String?) ?? 'Suspicious Link',
          url: url,
          reasons: _stringList(entry['reasons']),
          recommendations: _stringList(entry['recommendations']),
          usedAi: true,
        ),
      );
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  static String? _extractText(Map<String, dynamic> envelope) {
    final candidates = envelope['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final first = candidates.first;
    if (first is! Map) return null;
    final content = first['content'];
    if (content is! Map) return null;
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return null;
    final part0 = parts.first;
    if (part0 is! Map) return null;
    return part0['text'] as String?;
  }

  static List<String> _stringList(Object? raw) {
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }

  static RiskLevel _parseRiskLevel(String? level) {
    switch (level?.toUpperCase()) {
      case 'LOW':
        return RiskLevel.low;
      case 'MEDIUM':
        return RiskLevel.medium;
      case 'HIGH':
        return RiskLevel.high;
      case 'CRITICAL':
        return RiskLevel.critical;
      default:
        return RiskLevel.safe;
    }
  }

  static UrlRiskLevel _parseUrlRiskLevel(String? level) {
    switch (level?.toUpperCase()) {
      case 'LOW':
        return UrlRiskLevel.low;
      case 'MEDIUM':
        return UrlRiskLevel.medium;
      case 'HIGH':
        return UrlRiskLevel.high;
      case 'CRITICAL':
        return UrlRiskLevel.critical;
      default:
        return UrlRiskLevel.safe;
    }
  }

  static String _buildMessagePrompt(String message) => '''
You are NirapodClick, a digital safety assistant
designed for users in Bangladesh.

Analyze the following message for possible:
- phishing
- scam
- fraud
- impersonation
- fake job offers
- fake prizes
- payment fraud
- credential theft
- suspicious links
- account threats

Important:
Do not claim that something is definitely fraudulent
unless the evidence strongly supports it.

Return ONLY valid JSON using this structure:

{
  "risk_score": 0,
  "risk_level": "SAFE",
  "category": "General",
  "reasons": [],
  "recommendations": []
}

risk_score must be between 0 and 100.

risk_level must be one of:
SAFE, LOW, MEDIUM, HIGH, CRITICAL.

category should be a short category such as:
General
Phishing
Payment Scam
Prize Scam
Job Scam
Credential Theft
Impersonation
Account Scam

reasons should contain short explanations.

recommendations should contain practical safety advice.

Message to analyze:

$message
''';

  static String _buildUrlPrompt(String url) => '''
You are NirapodClick, a digital safety assistant
designed for users in Bangladesh.

Analyze the following URL for possible:
- phishing
- scam
- fraud
- impersonation (especially bKash, Nagad, Rocket, Dutch-Bangla Bank,
  BRAC Bank, Sonali Bank, Janata Bank, Grameenphone, Robi, Banglalink,
  Teletalk)
- credential theft
- homograph / punycode abuse
- shortened links hiding the destination
- direct downloads of risky files (.apk, .exe, .scr, .bat, .zip)
- login / verify / claim / gift keyword pressure tactics
- insecure transport (HTTP instead of HTTPS)

Important:
Do not claim that a URL is definitely malicious unless several
independent signals line up. A single keyword match alone should be
treated as "potentially suspicious", not "definitely phishing".

Return ONLY valid JSON using this structure:

{
  "risk_score": 0,
  "risk_level": "SAFE",
  "category": "General",
  "reasons": [],
  "recommendations": []
}

risk_score must be between 0 and 100.

risk_level must be one of:
SAFE, LOW, MEDIUM, HIGH, CRITICAL.

category should be a short category such as:
General
Phishing
Impersonation
Suspicious Link
Risky Download
Shortened Link

reasons should contain short explanations.

recommendations should contain practical safety advice.

URL to analyze:

$url
''';

  static String _buildScreenshotPrompt(String text) => '''
You are NirapodClick, a digital safety assistant
designed for users in Bangladesh.

You are analyzing the OCR-extracted text of a screenshot. The text may
contain chat messages, SMS, payment requests, prize claims, or links.

Analyze the full text for possible:
- phishing
- scam
- fraud
- impersonation (bKash, Nagad, Rocket, Dutch-Bangla Bank, BRAC Bank,
  Sonali Bank, Janata Bank, Grameenphone, Robi, Banglalink, Teletalk)
- credential theft (especially OTP requests)
- payment fraud
- fake job offers
- fake prizes
- urgency / pressure tactics
- suspicious embedded links

Important:
Do not claim that something is definitely fraudulent unless the evidence
strongly supports it. Treat isolated keyword matches as "potentially
suspicious", not "definitely phishing".

Return ONLY valid JSON using this structure:

{
  "risk_score": 0,
  "risk_level": "SAFE",
  "category": "General",
  "reasons": [],
  "recommendations": [],
  "urls": [
    {
      "url": "https://example.com/login",
      "risk_score": 0,
      "risk_level": "SAFE",
      "category": "Suspicious Link",
      "reasons": [],
      "recommendations": []
    }
  ]
}

risk_score must be between 0 and 100 and reflect the combined
message + URL verdict (you may weight links up to 35% of the total).

risk_level must be one of:
SAFE, LOW, MEDIUM, HIGH, CRITICAL.

category should be a short category such as:
General
Phishing
Payment Scam
Prize Scam
Job Scam
Credential Theft
Impersonation
Account Scam
Suspicious Link
Risky Download
Shortened Link

reasons should contain short explanations for the combined verdict.

recommendations should contain practical safety advice.

urls should contain one entry per http(s):// or www. link detected
in the text. If no links are present, return an empty array.

Extracted screenshot text:

$text
''';
}