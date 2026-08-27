import 'package:flutter/material.dart';

import '../core/locale/app_locale.dart';
import '../core/theme/app_theme.dart';
import '../services/checker_repository.dart';

/// Multi-select delete sheet for scan history. Opened from the Profile
/// screen's Privacy sheet ("Select scans to delete" action).
///
/// Behavior:
///   - Subscribes to [CheckerRepository.watchRecent] so newly-arriving
///     scans stream in while the sheet is open (Firestore snapshots
///     stream, no manual refresh).
///   - Per-row checkbox toggles membership in a `Set<String>` of
///     `checkId`s.
///   - Sticky bottom bar shows the current selection count + a
///     destructive Delete button (disabled when nothing is selected).
///   - Delete tap → confirm dialog → [CheckerRepository.deleteMany] →
///     pop with a "Deleted N scans" SnackBar.
///
/// The sheet uses the same visual chrome (drag handle, tinted icon
/// disc, rounded top corners 24) as the smaller settings sheets so the
/// two feel like the same widget at different sizes — see
/// `_SettingsSheet` in `profile_screen.dart` for the smaller variant.
Future<int?> showScanHistorySelectSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const ScanHistorySelectSheet(),
  );
}

class ScanHistorySelectSheet extends StatefulWidget {
  const ScanHistorySelectSheet({super.key});

  @override
  State<ScanHistorySelectSheet> createState() => _ScanHistorySelectSheetState();
}

class _ScanHistorySelectSheetState extends State<ScanHistorySelectSheet> {
  /// Checked rows. We hold a `Set` because membership checks are O(1)
  /// and the row builder needs to know "is this row currently selected"
  /// on every snapshot rebuild.
  ///
  /// We intentionally do NOT garbage-collect this set inside the
  /// StreamBuilder's `builder` callback. Earlier this sheet ran an
  /// `addPostFrameCallback` GC there, and on Firestore's rapid
  /// initial-then-delete emission pattern the queued callbacks can
  /// fire `setState` while the render tree is mid-parent-data update,
  /// which trips `!semantics.parentDataDirty` and floods the
  /// console with render-object stack traces. The Set is only ever
  /// mutated by user taps (`onToggle`) and by a fresh delete, both
  /// of which are single-frame mutations and safe.
  final Set<String> _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final fmt = AppLocaleScope.of(context).formatNumber;
    final repo = CheckerRepository();

    return SafeArea(
      child: ConstrainedBox(
        // Cap the sheet at 85% of the screen so a long history still
        // shows the bottom bar without pushing the close affordance off
        // the screen. We compute against the viewport because the
        // modal is `isScrollControlled: true`.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header — drag handle + title. Kept file-private (no
            // _SettingsSheet import) so the visual language can drift
            // without forcing this sheet to follow.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      t('profile.historySelectTitle'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: AppTheme.textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Streamed list. We use a plain StreamBuilder (no `key`,
            // no `_streamEpoch` counter) because Flutter re-subscribes
            // to the stream naturally when the parent rebuilds with a
            // new stream reference, and mutating `_streamEpoch` via
            // `setState` to force a retry can desync render-object
            // parent-data with the semantics tree on slow rebuilds.
            //
            // The Retry button below simply calls `setState(() {})`,
            // which keeps the existing subscription alive — Firestore
            // snapshots streams already self-heal on transient errors
            // (offline → online), so we don't need to force the
            // disposal path.
            Flexible(
              child: StreamBuilder<List<HistoryEntry>>(
                stream: repo.watchRecent(limit: 200),
                builder: (context, snapshot) {
                  // Error path first — without this, a Firestore
                  // permission-denied / index-missing / offline error
                  // would silently leave the spinner up forever, which
                  // is the failure mode the user reported ("stuck on
                  // loading"). Show an actionable message and a Retry
                  // button.
                  if (snapshot.hasError) {
                    debugPrint(
                      '[ScanHistorySelectSheet] stream error: '
                      '${snapshot.error}',
                    );
                    return Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            color: AppTheme.textSecondary,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            t('profile.historySelectLoadError'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton.icon(
                            // Plain setState is enough: Firestore's
                            // snapshots stream self-recovers on
                            // transient errors and re-emits on the
                            // next snapshot once connectivity is
                            // back. Forcing a StreamBuilder key swap
                            // to "retry" is the change that
                            // reintroduced the
                            // `!semantics.parentDataDirty` bug, so
                            // we keep this idempotent.
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(t('profile.historySelectRetry')),
                          ),
                        ],
                      ),
                    );
                  }
                  // Loading gate. Firestore's `.snapshots()` stream
                  // reports `ConnectionState.active` once subscribed,
                  // NOT `done`, so the old "wait for done" check
                  // stayed true forever on real data. Show the spinner
                  // only while genuinely waiting for the first event
                  // AND we don't yet have anything to render.
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    );
                  }
                  final entries = snapshot.data ?? const <HistoryEntry>[];
                  if (entries.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        t('profile.historySelectEmpty'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 64, endIndent: 16),
                    itemBuilder: (_, i) => _SelectRow(
                      entry: entries[i],
                      selected: _selected.contains(entries[i].checkId),
                      onToggle: () {
                        final id = entries[i].checkId;
                        setState(() {
                          if (_selected.contains(id)) {
                            _selected.remove(id);
                          } else {
                            _selected.add(id);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),

            // Bottom bar — count + destructive Delete CTA. Always
            // visible above the keyboard; we don't scroll this region.
            _BottomBar(
              countLabel: t('profile.historySelectCount')
                  .replaceAll('{n}', fmt(_selected.length)),
              deleteLabel: t('profile.historySelectDelete'),
              enabled: _selected.isNotEmpty,
              onDelete: _selected.isEmpty
                  ? null
                  : () => _confirmAndDelete(context, fmt),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    String Function(num) fmt,
  ) async {
    final t = AppLocaleScope.of(context).tr;
    final repo = CheckerRepository();
    final ids = _selected.toList(growable: false);
    final n = ids.length;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (n == 0) {
      // Nothing selected when the user tapped — close the dialog chain
      // gracefully. This is a safety net: the Delete button is
      // disabled when `_selected` is empty, but a defensive check
      // here costs nothing and prevents a `permission-denied` from a
      // degenerate deleteMany([]) call.
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            t('profile.historySelectDeleteConfirm').replaceAll(
              '{n}',
              fmt(n),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t('profile.commonCancel')),
            ),
            // Destructive gradient CTA — same red family as the
            // logout button on Profile.
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.riskHigh, AppTheme.riskCritical],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(t('profile.commonDelete')),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      final deleted = await repo.deleteMany(ids);
      // Clear the local selection only after the server confirms the
      // delete succeeded. Doing it here (instead of in a stream
      // builder callback) keeps `_selected` mutations single-frame
      // and avoids the `addPostFrameCallback` GC that used to trip
      // `!semantics.parentDataDirty`.
      _selected.clear();
      if (mounted) setState(() {});
      // Pop the sheet with the count so callers (Privacy sheet) can
      // chain a SnackBar if they want.
      navigator.pop(deleted);
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            t('profile.historyDeletedToast').replaceAll('{n}', fmt(deleted)),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(e.toString()),
        ),
      );
    }
  }
}

/// Single row in the selection list. Visually mirrors the
/// `_RecentScanTile` on the Home dashboard so users recognise the data
/// they're about to delete.
class _SelectRow extends StatelessWidget {
  const _SelectRow({
    required this.entry,
    required this.selected,
    required this.onToggle,
  });

  final HistoryEntry entry;
  final bool selected;
  final VoidCallback onToggle;

  IconData _iconFor(ScanType t) {
    switch (t) {
      case ScanType.message:
        return Icons.chat_bubble_outline_rounded;
      case ScanType.url:
        return Icons.link_rounded;
      case ScanType.screenshot:
        return Icons.image_outlined;
      case ScanType.phone:
        return Icons.phone_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = RiskStyle.of(entry.result.level);
    // Plain GestureDetector with `HitTestBehavior.opaque`. We
    // intentionally do NOT wrap this in `Material` or `InkWell`
    // because both interact with the ListView's render-object
    // parent-data lifecycle — wrapping them around a row in a
    // SliverChild rebuild can produce `!semantics.parentDataDirty`
    // assertions when the semantics tree gets out of sync with the
    // rapidly-attaching/detaching rows. GestureDetector alone
    // captures the tap on the whole row including the checkbox and
    // the risk pill, with no splash feedback (we don't need it on
    // this sheet — the checkbox itself is the visual confirmation).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Custom round checkbox — brand-tinted when selected.
            // Animates between checked / unchecked states.
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppTheme.primary : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppTheme.primary
                      : AppTheme.borderSubtle,
                  width: 1.6,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: AppTheme.tintSurface),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconFor(entry.type),
                color: style.color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    entry.result.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.originalText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: style.color,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                style.badge,
                style: TextStyle(
                  color: style.onColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky bottom bar — count on the left, destructive Delete button on
/// the right. Sits outside the scroll region so it's always reachable.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.countLabel,
    required this.deleteLabel,
    required this.enabled,
    required this.onDelete,
  });

  final String countLabel;
  final String deleteLabel;
  final bool enabled;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              countLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Destructive gradient button — disabled state dims the
          // gradient so users see at a glance that nothing will
          // happen if they tap.
          Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.riskHigh, AppTheme.riskCritical],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: AppTheme.riskCritical
                              .withValues(alpha: 0.20),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: ElevatedButton(
                onPressed: onDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(deleteLabel),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
