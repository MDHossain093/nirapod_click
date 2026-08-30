import '../models/qr_route.dart';

/// Pure-Dart QR-payload classifier.
///
/// Takes the raw string decoded from a QR code and decides which
/// existing NirapodClick checker should handle it:
///
///   * `http://...`, `https://...`, `www....`, `bkash://...`,
///     `nagad://...`, `rocket://...`, or any hostname-shaped string
///     with a recognizable TLD → [QrRoute.url]
///   * `TEL:...`, `tel:...`, plain BD mobile numbers
///     (incl. `+88` / `88` prefix), or phone numbers extracted from
///     `vCard` / `MECARD` payloads → [QrRoute.phone]
///   * anything else (free-form text, WiFi credentials, contact
///     notes) → [QrRoute.text]
///
/// The classifier is **deliberately pure Dart** — no Flutter, no
/// platform channels — so it is unit-testable in `flutter test`
/// without spinning up the camera stack. The camera screen wires it
/// up via [classify] on every successful decode.
///
/// Detection order matters: a payload like `bkash.com.bd/...` matches
/// both the URL and (loosely) the phone regex, but the URL test fires
/// first, which is what we want — the URL checker handles payment
/// URIs by treating them as suspicious-looking URLs. The phone
/// regex requires an 11-digit BD mobile shape with no dots or slashes,
/// so a real URL won't accidentally match it.
class QrPayloadClassifier {
  const QrPayloadClassifier();

  /// URL schemes we explicitly route to the URL checker. `bkash://`,
  /// `nagad://`, and `rocket://` are MFS-specific deep links used
  /// for "send money" / "receive money" intents; the URL checker
  /// already handles suspicious-looking URIs through the same rules
  /// engine that catches phishing.
  static const Set<String> _urlSchemes = {
    'http',
    'https',
    'ftp',
    'bkash',
    'nagad',
    'rocket',
    'upay',
    'surecash',
    'mcash',
    'tap',
  };

  /// vCard TEL field — `TEL`, `TEL;TYPE=CELL;...=...` all start with
  /// `TEL` after the optional `;...` parameters. Anchored to the
  /// start of a line because vCard is line-delimited.
  static final RegExp _vCardTelLine = RegExp(
    r'^TEL[^:]*:(.+)$',
    caseSensitive: false,
    multiLine: true,
  );

  // Note: MECARD is a single-line `KEY:VALUE;KEY:VALUE;...` blob,
  // so we handle it by splitting on `;` in [_extractPhoneFromContactCard]
  // rather than via a regex. multiLine `^` anchors do not help here
  // because MECARD has no line breaks.

  /// TLD-bearing bare hostnames (`example.com`, `bit.ly`,
  /// `bkash.com.bd`). Anchored so we don't accidentally accept
  /// `1.2.3.4`-style IPs (those are out of scope for v1 — IP hosts
  /// in URLs are already flagged by the URL engine's existing
  /// heuristics).
  static final RegExp _bareHostname = RegExp(
    r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+'
    r'(?:[/?#][^\s]*)?$',
    caseSensitive: false,
  );

  /// BD mobile shape — exactly 11 digits, `01` + `[3-9]` + 8 more,
  /// optionally prefixed with `+88` or `88`. We only count a
  /// payload as "phone" when the *whole* cleaned string matches;
  /// phones embedded in longer blobs (e.g. "call me at 017...")
  /// are handled by the message checker instead.
  static final RegExp _bdMobile = RegExp(
    r'^(?:\+?88)?01[3-9]\d{8}$',
  );

  /// Classify a raw QR-payload string. Empty / whitespace-only input
  /// returns [QrRoute.text] with an empty `extracted` value so the
  /// caller can show the "unsupported content" snackbar.
  QrClassification classify(String raw) {
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      return QrClassification(
        route: QrRoute.text,
        extracted: '',
        raw: '',
      );
    }

    // 1. vCard / MECARD payloads — extract the first TEL line, then
    //    recurse on that so the same normalization + BD-shape test
    //    applies. Falls through to text if no phone is found.
    final fromVcard = _extractPhoneFromContactCard(trimmed);
    if (fromVcard != null) {
      return _classifyPhone(fromVcard, trimmed);
    }

    // 2. TEL: URI scheme (`tel:+8801712345678`, `TEL:01712345678`).
    //    Common on business-card QRs and saved-contact QRs.
    if (RegExp(r'^tel:', caseSensitive: false).hasMatch(trimmed)) {
      final withoutScheme = trimmed.replaceFirst(
        RegExp(r'^tel:', caseSensitive: false),
        '',
      ).trim();
      return _classifyPhone(withoutScheme, trimmed);
    }

    // 3. URL-shaped payloads (scheme-bearing or bare hostname).
    final lower = trimmed.toLowerCase();
    for (final scheme in _urlSchemes) {
      if (lower.startsWith('$scheme://')) {
        return QrClassification(
          route: QrRoute.url,
          extracted: trimmed,
          raw: trimmed,
        );
      }
    }
    if (lower.startsWith('www.')) {
      return QrClassification(
        route: QrRoute.url,
        // Prepend https:// so the URL checker doesn't reject the
        // bare hostname as "missing scheme".
        extracted: 'https://$trimmed',
        raw: trimmed,
      );
    }
    if (_bareHostname.hasMatch(trimmed)) {
      return QrClassification(
        route: QrRoute.url,
        extracted: 'https://$trimmed',
        raw: trimmed,
      );
    }

    // 4. Plain BD mobile number (with or without country prefix).
    if (_bdMobile.hasMatch(_stripPhoneJunk(trimmed))) {
      return _classifyPhone(trimmed, trimmed);
    }

    // 5. Fallback: free-form text → message checker.
    return QrClassification(
      route: QrRoute.text,
      extracted: trimmed,
      raw: trimmed,
    );
  }

  /// Apply the BD-normalization rules used by [PhoneRiskEngine] and
  /// wrap the result in a [QrClassification]. Kept private so the
  /// public API stays a single `classify()` call.
  QrClassification _classifyPhone(String rawPhone, String rawOriginal) {
    final normalized = _normalizeBdPhone(rawPhone);
    // If normalization fails to produce a BD-shaped number (e.g. a
    // TEL: payload with a foreign number), fall back to text — the
    // message checker will at least let the user see what they
    // scanned.
    if (normalized == null) {
      return QrClassification(
        route: QrRoute.text,
        extracted: rawOriginal,
        raw: rawOriginal,
      );
    }
    return QrClassification(
      route: QrRoute.phone,
      extracted: normalized,
      raw: rawOriginal,
    );
  }

  /// Pull the first phone-looking field out of a vCard / MECARD
  /// payload. Returns null if no TEL line is present so the caller
  /// can fall through to text classification.
  String? _extractPhoneFromContactCard(String payload) {
    // vCard begins with `BEGIN:VCARD` and ends with `END:VCARD`.
    // MECARD begins with `MECARD:` and ends with `;;`. We accept
    // either prefix so we don't accidentally route a contact-card
    // to the message checker when a phone is sitting right there.
    final isVcard = payload.toUpperCase().startsWith('BEGIN:VCARD');
    final isMeCard = payload.toUpperCase().startsWith('MECARD:');
    if (!isVcard && !isMeCard) return null;

    if (isVcard) {
      final match = _vCardTelLine.firstMatch(payload);
      if (match == null) return null;
      final raw = match.group(1)?.trim();
      if (raw == null || raw.isEmpty) return null;
      return raw;
    }

    // MECARD path. MECARD is a single-line `KEY:VALUE;KEY:VALUE;...`
    // blob, so we split on `;` and walk the fields looking for one
    // that starts with `TEL:` (case-insensitive). The first match
    // wins — MECARD has no field ordering guarantee but phones
    // almost always come first when present.
    for (final field in payload.split(';')) {
      final colonIdx = field.indexOf(':');
      if (colonIdx <= 0) continue;
      final key = field.substring(0, colonIdx).trim().toUpperCase();
      if (key != 'TEL') continue;
      final value = field.substring(colonIdx + 1).trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  /// Strip whitespace / dashes / parens from a candidate phone
  /// string. Mirrors [PhoneRiskEngine._normalize] but stays local
  /// to keep this classifier Flutter-independent.
  String _stripPhoneJunk(String input) {
    return input.replaceAll(RegExp(r'[\s\-()]'), '');
  }

  /// Normalize to BD-local `01XXXXXXXXX` form. Returns null when
  /// the result isn't a valid BD mobile (11 digits, `01` + `[3-9]`
  /// + 8 more).
  String? _normalizeBdPhone(String input) {
    var phone = _stripPhoneJunk(input);

    if (phone.startsWith('+88')) {
      phone = phone.substring(3);
    }
    if (phone.startsWith('88') && phone.length == 13) {
      phone = phone.substring(2);
    }

    if (RegExp(r'^01[3-9]\d{8}$').hasMatch(phone)) {
      return phone;
    }
    return null;
  }
}
