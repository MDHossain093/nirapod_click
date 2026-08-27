import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/checker_repository.dart';

/// Compact human label for a relative timestamp, e.g. "just now",
/// "12m ago", "3h ago", "2d ago", or `YYYY-MM-DD` for anything older
/// than a week.
///
/// `createdAt` is whatever the [HistoryEntry] carries — a [Timestamp]
/// when read back from Firestore, `null` while the server is still
/// stamping the document, or a sentinel when round-tripped locally.
/// Anything non-[Timestamp] is treated as "no timestamp yet" and
/// rendered as `just now`.
String relativeDateLabel(Object? createdAt) {
  final dt = createdAt is Timestamp ? createdAt.toDate() : null;
  if (dt == null) return 'just now';
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Per-scan-type icon + i18n key for the small chip that distinguishes
/// message / url / screenshot / phone rows at a glance. Same lookup the
/// History page uses; exposed here so the Alerts page stays in sync.
({IconData icon, String labelKey}) scanTypeMeta(ScanType t) {
  switch (t) {
    case ScanType.message:
      return (icon: Icons.chat_bubble_outline, labelKey: 'history.typeMessage');
    case ScanType.url:
      return (icon: Icons.link_rounded, labelKey: 'history.typeUrl');
    case ScanType.screenshot:
      return (icon: Icons.image_outlined, labelKey: 'history.typeScreenshot');
    case ScanType.phone:
      return (icon: Icons.phone_outlined, labelKey: 'history.typePhone');
  }
}

/// Day-bucket label for grouping entries in the alerts timeline.
///
/// Returns one of: `today`, `yesterday`, `earlierThisWeek`, `earlier`.
/// Used as a key into the locale table (`alerts.group.*`).
String dayBucket(DateTime ts, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final that = _dateOnly(ts);
  final diffDays = today.difference(that).inDays;
  if (diffDays <= 0) return 'today';
  if (diffDays == 1) return 'yesterday';
  if (diffDays < 7) return 'earlierThisWeek';
  return 'earlier';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
