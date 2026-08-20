import '../models/risk_result.dart';

/// Abstract client for the Gemini-backed analyser.
///
/// The real implementation lives in a Firebase Cloud Function so the API
/// key never ships in the Flutter APK. The contract here is everything
/// the UI / analyzer needs to call it.
///
/// Implementations MUST be safe to mock in tests — see [_FakeAiService]
/// in `test/`.
abstract class AiService {
  /// Send [message] to the backend Gemini pipeline and return a
  /// fully-formed [RiskResult]. Implementations should:
  ///   * throw [AiUnavailableException] if the network / function call fails
  ///     in a way the caller should fall back from (timeouts, 5xx);
  ///   * throw [AiInvalidResponseException] if Gemini returns something
  ///     we can't safely parse.
  Future<RiskResult> analyze(String message);
}

/// Thrown when the AI service is unreachable / not configured.
class AiUnavailableException implements Exception {
  final String reason;
  const AiUnavailableException(this.reason);
  @override
  String toString() => 'AiUnavailableException: $reason';
}

/// Thrown when the AI service returned a payload we can't trust.
class AiInvalidResponseException implements Exception {
  final String reason;
  const AiInvalidResponseException(this.reason);
  @override
  String toString() => 'AiInvalidResponseException: $reason';
}

/// No-op client used until the Cloud Function is deployed.
///
/// Returning `null` would force callers to special-case it; instead we
/// make the in-memory client the default and let the rule engine do all
/// the work. The real client will replace this in production.
class NoopAiService implements AiService {
  const NoopAiService();
  @override
  Future<RiskResult> analyze(String message) async {
    throw const AiUnavailableException(
      'NoopAiService: Gemini Cloud Function is not configured yet.',
    );
  }
}
