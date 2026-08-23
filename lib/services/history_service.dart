import 'checker_repository.dart';

/// Re-export so callers can `import 'history_service.dart'` and get the
/// canonical [HistoryEntry] type without also importing `checker_repository`.
export 'checker_repository.dart' show HistoryEntry;

/// One-time read of the signed-in user's recent scans.
///
/// This is a thin convenience wrapper around [CheckerRepository.watchRecent]
/// for call sites (e.g. the Home dashboard) that want a one-shot snapshot
/// rather than a live stream. The underlying repository is the single source
/// of truth — both this shim and the History page stream from it.
///
/// Returns an empty list if the user has no scans yet (or if the call
/// fails to fetch and we fall back to the empty default).
class HistoryService {
  HistoryService({CheckerRepository? repository})
      : _repository = repository ?? CheckerRepository();

  final CheckerRepository _repository;

  /// Fetches the most recent scans for the signed-in user.
  ///
  /// Defaults to the same `limit = 50` the History page uses so a caller
  /// asking for "recent" sees the same set the user sees in the History
  /// tab. Pass a smaller [limit] for the dashboard's "last 3" tile.
  Future<List<HistoryEntry>> getHistory({int limit = 50}) async {
    final stream = _repository.watchRecent(limit: limit);
    // `first` resolves to the first emission of the live stream - i.e. the
    // initial snapshot. If Firestore errors, fall back to an empty list so
    // a transient network failure on the dashboard doesn't break the rest
    // of the page.
    try {
      return await stream.first;
    } catch (_) {
      return const <HistoryEntry>[];
    }
  }
}
