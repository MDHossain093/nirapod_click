/// What kind of scan produced a [HistoryEntry]. Stored on the Firestore
/// document so the history list can render the right icon / label
/// without sniffing the original text.
///
/// Originally defined in `services/checker_repository.dart`; extracted
/// to its own file so the subscription service can depend on it
/// without creating a `services/checker_repository.dart →
/// services/subscription_service.dart → services/checker_repository.dart`
/// import cycle.
enum ScanType {
  message,
  url,
  screenshot,
  phone,

  /// QR Code scan. A QR scan itself is **free** and never persisted
  /// to history — it just routes to the URL / Phone / Message
  /// checker that handles its decoded payload. This enum value is
  /// reserved for future telemetry (e.g. counting how many QR scans
  /// happened this month) and to keep the subscription service's
  /// exhaustive switch honest.
  qr;

  /// Stable wire name used in Firestore payloads + rules whitelist.
  String get wire => name;
}
