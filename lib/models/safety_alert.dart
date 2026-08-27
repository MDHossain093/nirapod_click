import 'package:flutter/foundation.dart';

import '../services/checker_repository.dart';
import 'admin_alert.dart';

/// A row in the Alerts page.
///
/// The page mixes two kinds of entries:
///   * [ScanAlert]   — derived from the user's own scan history.
///                     Severity is driven by the scan's score/confidence.
///   * [AdminAlertItem] — published by an admin via the Admin screen.
///                        Always rendered above scan alerts.
///
/// Keeping them under one type lets the page iterate a single list
/// and lets [AlertService] emit a single stream. The discriminator
/// is the runtime type of [kind].
@immutable
sealed class SafetyAlert {
  const SafetyAlert({required this.id, required this.createdAt});
  final String id;
  final Object? createdAt;
}

class ScanAlert extends SafetyAlert {
  const ScanAlert({required super.id, required this.entry, super.createdAt});
  final HistoryEntry entry;
}

class AdminAlertItem extends SafetyAlert {
  const AdminAlertItem({
    required super.id,
    required this.alert,
    super.createdAt,
  });
  final AdminAlert alert;
}