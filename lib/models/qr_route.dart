/// Classification result for a decoded QR-code payload.
///
/// Returned by [QrPayloadClassifier.classify]. The QR checker screen
/// uses [route] to pick which existing checker to push (URL / Phone
/// / Message), and [extracted] as the value to pre-fill that
/// checker's text input.
///
/// QR codes in Bangladesh carry one of three shapes we care about:
///   - a URL (incl. `bkash://`, `nagad://`, `rocket://` URI schemes
///     which we route to the URL checker because the same engine
///     knows how to analyse them), or
///   - a phone number (incl. `TEL:` URIs and the phone field inside
///     `vCard` / `MECARD` contact-card QRs), or
///   - plain text (free-form contact notes, promo blurbs, etc. —
///     routed to the message checker so the user can read the text
///     and decide whether to analyze).
enum QrRoute { url, phone, text }

/// Immutable classification result. Carries both the destination
/// kind and the cleaned-up payload string the destination checker
/// should display in its text field.
class QrClassification {
  const QrClassification({
    required this.route,
    required this.extracted,
    required this.raw,
  });

  /// Which existing checker to push next.
  final QrRoute route;

  /// Payload string cleaned up for the destination checker. For
  /// URLs, scheme-prefixed if it was missing one. For phones,
  /// normalized to BD local format `01XXXXXXXXX`. For text, the
  /// raw trimmed payload.
  final String extracted;

  /// The original trimmed QR string — kept around for diagnostics
  /// and for the "Detected: `preview`" affordance on the camera
  /// screen.
  final String raw;

  @override
  String toString() =>
      'QrClassification(route: $route, extracted: $extracted, '
      'raw: $raw)';
}
