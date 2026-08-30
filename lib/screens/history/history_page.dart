import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/locale/app_locale.dart';
import '../../core/locale/localizer.dart';
import '../../core/theme/app_theme.dart';
import '../../services/alert_service.dart';
import '../../services/checker_repository.dart';
import 'risk_result_page.dart';

/// Recent checks for the signed-in user, streamed from Firestore.
///
/// Renders every kind of check (message / URL / screenshot / phone)
/// in one timeline. Each row shows the risk color + badge, a small
/// scan-type chip so the user can tell what kind of check it was,
/// and the first line of the original text (truncated for privacy).
///
/// **Delete flow**:
///   * The trash icon in the app bar opens a small action sheet with
///     two options:
///     - "Select to delete" → enters an inline multi-select mode
///       where every row grows a leading checkbox. The trash icon
///       then deletes the user's selection; a Cancel button exits
///       the mode.
///     - "Delete all" → confirm dialog → wipes the user's history.
///   * The previous design routed both options through a separate
///     modal sheet on the Profile → Privacy screen. That sheet had a
///     recurring spinner-hang bug (Firestore DNS failure left it
///     stuck), and the pop-then-push navigation race produced
///     `!semantics.parentDataDirty` assertion floods on real
///     devices. The new flow renders the selection UI in place — no
///     second modal — so the spinner hang and the navigation race
///     are both impossible.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  /// Resolved at [initState] time and re-emitted by a [StreamBuilder]
  /// so the underlying Firestore query always sees a fresh ID token.
  /// The FlutterFire SDK refreshes tokens lazily, but the first read
  /// after sign-in can race and return `permission-denied` because
  /// the cached token is stale. Forcing one refresh here cures that
  /// race without adding any UI cost (it happens once per page open,
  /// typically < 200 ms).
  Future<void>? _ready;

  /// Whether the user is currently in the inline multi-select mode
  /// (triggered by "Select to delete" from the trash-icon menu).
  /// While true, every row renders a leading checkbox and the trash
  /// icon in the app bar deletes the selected rows instead of
  /// opening its action sheet.
  bool _selectionMode = false;

  /// Ids currently checked while in multi-select mode. Held as a
  /// `Set` because the row builder asks "is this row selected" on
  /// every rebuild — O(1) lookup matters when the list re-emits
  /// from the Firestore snapshot stream.
  final Set<String> _selectedIds = <String>{};

  /// The currently visible list of history entries. We cache them
  /// out of the StreamBuilder's `builder` closure so the multi-select
  /// toolbar (Delete / Cancel) at the bottom can read them without
  /// reaching back into the stream's internal state. Updated on
  /// every successful snapshot emission.
  List<HistoryEntry> _entries = const <HistoryEntry>[];

  @override
  void initState() {
    super.initState();
    _ready = _ensureFreshAuth();
  }

  Future<void> _ensureFreshAuth() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[HistoryPage] No signed-in user; query will fail.');
        return;
      }
      debugPrint('[HistoryPage] Forcing fresh ID token for uid=${user.uid}.');
      await user.getIdToken(true);
      debugPrint('[HistoryPage] ID token refreshed.');
    } catch (e) {
      // Don't block the UI on a refresh failure — the underlying
      // stream will surface the real error if it still matters.
      debugPrint('[HistoryPage] Token refresh failed: $e');
    }
  }

  String _tr(BuildContext context, String key) =>
      AppLocaleScope.of(context).tr(key);

  /// Enter multi-select mode. Called from the trash-icon menu's
  /// "Select to delete" action. Resets the selection set so the user
  /// starts from a clean slate each time.
  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
    });
  }

  /// Exit multi-select mode without deleting anything. Called from
  /// the Cancel button on the selection toolbar.
  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  /// Toggle the membership of [id] in the selection set. Called from
  /// each row's checkbox tap.
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  /// Open the trash-icon action sheet — two options: enter selection
  /// mode, or delete everything. We only show this menu while NOT
  /// already in selection mode (in selection mode the trash icon
  /// deletes the current selection instead).
  Future<void> _showDeleteMenu(BuildContext context) async {
    final t = AppLocaleScope.of(context).tr;
    final fmt = AppLocaleScope.of(context).formatNumber;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.sheetCornerRadius)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle — same affordance as every other sheet
                // so users get the visual cue "this is a dismissable
                // surface".
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  t('history.deleteMenuTitle'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                _DeleteMenuOption(
                  icon: Icons.checklist_rounded,
                  label: t('history.deleteSelectMode'),
                  // Subtitle reassures the user what they're getting
                  // into — without it, "Select to delete" reads
                  // ambiguous (select WHAT?). EN/BN copy lives in the
                  // locale file.
                  subtitle: _entries.isEmpty
                      ? t('history.historySelectEmpty')
                      : t('history.selectionCount')
                          .replaceAll('{n}', fmt(_entries.length)),
                  color: AppTheme.primary,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    if (_entries.isEmpty) {
                      // No rows to select — don't enter an empty
                      // mode. Surface a quick toast so the user
                      // understands why nothing happened.
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(t('history.historySelectEmpty')),
                        ),
                      );
                      return;
                    }
                    _enterSelectionMode();
                  },
                ),
                const SizedBox(height: 10),
                _DeleteMenuOption(
                  icon: Icons.delete_sweep_rounded,
                  label: t('history.clearConfirm'),
                  subtitle: t('history.clearDialogBody'),
                  color: AppTheme.riskCritical,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _confirmClear(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_tr(context, 'history.clearDialogTitle')),
          content: Text(_tr(context, 'history.clearDialogBody')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_tr(context, 'history.cancel')),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_tr(context, 'history.clearConfirm')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    // If we're in selection mode (the user opened the menu from
    // there), exit it first — the delete-all wipes the underlying
    // data, so the selection set is meaningless now.
    if (_selectionMode) {
      _exitSelectionMode();
    }
    final repo = CheckerRepository();
    try {
      await repo.clearAll();
      // Wipe the seen-IDs set so the alert badge doesn't ghost-count
      // alerts whose underlying documents just got deleted. Without
      // this, an alert could remain "unread" forever even though its
      // doc is gone (and would therefore never appear again).
      await AlertService.instance.clearSeen();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tr(context, 'history.clearedToast'))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  /// Confirm dialog → delete the currently selected rows → exit
  /// selection mode. Mirrors the standalone sheet's optimistic UI:
  /// exit selection mode FIRST so the user gets instant feedback,
  /// then run the Firestore deletes in the background and surface
  /// any error via a follow-up SnackBar.
  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final t = AppLocaleScope.of(context).tr;
    final fmt = AppLocaleScope.of(context).formatNumber;
    if (_selectedIds.isEmpty) return;
    final n = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            t('history.selectionDeleteConfirm').replaceAll('{n}', fmt(n)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(_tr(context, 'history.cancel')),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(_tr(context, 'history.clearConfirm')),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    // Snapshot the ids + exit selection mode immediately. The user
    // sees the rows drop out of the selection-mode toolbar before
    // Firestore has finished the round-trip — same "pop first, work
    // later" pattern the standalone sheet uses to keep the UI
    // responsive on slow networks.
    final ids = _selectedIds.toList(growable: false);
    final messenger = ScaffoldMessenger.of(context);
    _exitSelectionMode();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          t('history.selectionDeletedToast').replaceAll('{n}', fmt(n)),
        ),
      ),
    );

    // Fire-and-forget. Errors surface as a follow-up SnackBar; the
    // `mounted` check guards against the user having navigated away
    // before the delete resolves (e.g. system-back → logout).
    // ignore: unawaited_futures, discarded_futures
    () async {
      try {
        await CheckerRepository().deleteMany(ids);
      } catch (e) {
        if (!messenger.mounted) return;
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(e.toString()),
          ),
        );
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final fmt = AppLocaleScope.of(context).formatNumber;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _selectionMode
          ? _buildSelectionAppBar(t, fmt)
          : _buildDefaultAppBar(t),
      body: FutureBuilder<void>(
        future: _ready,
        builder: (context, readySnap) {
          // While the ID token is being refreshed we keep showing the
          // spinner — the underlying Firestore stream opens only after
          // the refresh resolves, so it can use a guaranteed-fresh
          // token. This eliminates the "stale token → permission-denied
          // on first read after sign-in" race.
          if (readySnap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<List<HistoryEntry>>(
            stream: CheckerRepository().watchRecent(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load history.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final checks = snapshot.data ?? const <HistoryEntry>[];
              // Cache for the trash-icon menu subtitle / disabled
              // checks. Done outside the inner builder so a transient
              // empty snapshot (right after a delete commits) doesn't
              // momentarily flip the menu's "Select to delete" option
              // into a no-op state.
              _entries = checks;
              if (checks.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 64,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _tr(context, 'history.emptyTitle'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _tr(context, 'history.emptyBody'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                itemCount: checks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final entry = checks[i];
                  final result = entry.result;
                  final style = RiskStyle.of(result.level);
                  final typeMeta = scanTypeMeta(entry.type);
                  final selected =
                      _selectionMode && _selectedIds.contains(entry.checkId);
                  return _HistoryRow(
                    entry: entry,
                    style: style,
                    typeMeta: typeMeta,
                    selectionMode: _selectionMode,
                    selected: selected,
                    onTap: _selectionMode
                        ? () => _toggleSelection(entry.checkId)
                        : null,
                    onLongPress: _selectionMode
                        ? null
                        : () {
                            // Long-press is a discoverable shortcut
                            // into selection mode. Power users
                            // discover it; novice users can ignore it
                            // and use the trash icon's menu.
                            _enterSelectionMode();
                            _toggleSelection(entry.checkId);
                          },
                    onChevronTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RiskResultPage(
                          result: result,
                          originalText: entry.originalText,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Default app bar — single trash icon that opens the action sheet.
  /// Shown whenever the user is NOT in selection mode.
  PreferredSizeWidget _buildDefaultAppBar(String Function(String) t) {
    return AppBar(
      title: Text(t('history.appBarTitle')),
      actions: [
        IconButton(
          tooltip: t('history.clearAction'),
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: () => _showDeleteMenu(context),
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.headerGradient,
        ),
      ),
    );
  }

  /// Selection-mode app bar. Replaces the default title with the
  /// current selection count + a Cancel action, and turns the trash
  /// icon into a destructive "delete the selection" affordance.
  PreferredSizeWidget _buildSelectionAppBar(
    String Function(String) t,
    String Function(num) fmt,
  ) {
    final canDelete = _selectedIds.isNotEmpty;
    return AppBar(
      // Disable the back arrow's auto-pop so a system-back press
      // exits selection mode cleanly via the Cancel button instead
      // of popping the page out from under the user mid-flow.
      automaticallyImplyLeading: false,
      leading: TextButton(
        onPressed: _exitSelectionMode,
        child: Text(
          t('history.cancel'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      leadingWidth: 80,
      title: Text(
        t('history.selectionCount').replaceAll('{n}', fmt(_selectedIds.length)),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 17,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        IconButton(
          tooltip: t('history.clearAction'),
          // Destructive color when the user has a selection, ghost
          // when they don't — same visual language as the standalone
          // sheet's bottom bar.
          icon: Icon(
            Icons.delete_outline_rounded,
            color: canDelete
                ? Colors.white
                : Colors.white.withValues(alpha: 0.45),
          ),
          onPressed: canDelete ? () => _confirmDeleteSelected(context) : null,
        ),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.headerGradient,
        ),
      ),
    );
  }
}

// -- Row widget ---------------------------------------------------------

/// One history entry. Renders either the "tap → open detail" UI or
/// the "tap → toggle checkbox" UI depending on [selectionMode]. The
/// detail chevron is hidden in selection mode because tapping the row
/// is the checkbox interaction in that mode.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.style,
    required this.typeMeta,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onChevronTap,
  });

  final HistoryEntry entry;
  final RiskStyle style;
  final ({IconData icon, String labelKey}) typeMeta;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onChevronTap;

  @override
  Widget build(BuildContext context) {
    final result = entry.result;
    final t = AppLocaleScope.of(context).tr;
    return Material(
      color: selected
          ? AppTheme.primary.withValues(alpha: AppTheme.tintSubtle)
          : AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.borderSubtle,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode) ...[
                // Leading checkbox area. We use AnimatedContainer so
                // the toggle gives the user a visual cue that their
                // tap registered, even before the row's border color
                // animates in.
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 4),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOut,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppTheme.primary
                          : Colors.transparent,
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
                ),
                const SizedBox(width: 8),
              ],
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: AppTheme.tintPanelSoft),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(style.icon, color: style.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Risk pill + scan-type chip pinned
                        // together on the left via a tight
                        // inner Row that wraps if needed. The
                        // date goes in a Flexible after, so
                        // any long localized date string
                        // (e.g. Bangla "২ ঘন্টা আগে") can
                        // ellipsize without pushing the row
                        // past the screen edge.
                        Flexible(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: style.color,
                                  borderRadius:
                                      BorderRadius.circular(
                                          AppTheme.radiusXs),
                                ),
                                child: Text(
                                  result.level.localizedBadge,
                                  style: TextStyle(
                                    color: style.onColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              _ScanTypeChip(
                                icon: typeMeta.icon,
                                label: t(typeMeta.labelKey),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            relativeDateLabel(entry.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.category,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.originalText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'score ${AppLocaleScope.of(context).formatNumber(result.score)} \u00b7 '
                      '${AppLocaleScope.of(context).formatPercent(result.confidence)} '
                      '\u00b7 ${AppLocaleScope.of(context).formatNumber(result.reasons.length)} '
                      'signal${result.reasons.length == 1 ? "" : "s"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!selectionMode)
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: onChevronTap,
                  // Tight visual hit area — the row itself is the
                  // primary tap target.
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row inside the trash-icon action sheet. Mirrors the visual
/// language of `_MenuItem` on the Profile screen (icon disc on the
/// left, label + subtitle in the middle, chevron on the right) so
/// the user recognises the affordance.
class _DeleteMenuOption extends StatelessWidget {
  const _DeleteMenuOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: color.withValues(alpha: AppTheme.tintBorderStrong),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: AppTheme.tintSurface),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.65),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny pill that renders the scan type next to the risk badge.
/// Kept private to the page since it's a 1:1 visual companion.
class _ScanTypeChip extends StatelessWidget {
  const _ScanTypeChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: AppTheme.tintSubtle),
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      ),
      // Wrap (not Row) so when the outer Wrap constrains the chip
      // tighter than its intrinsic width — e.g. the long Bangla /
      // English "Phone Number" label fitting next to a high-risk
      // badge on a narrow row — the icon + label can break onto two
      // lines instead of overflowing the chip's horizontal bound
      // (which used to throw a RenderFlex overflow assertion at run
      // time on phone-number scan history rows).
      child: Wrap(
        spacing: 4,
        runSpacing: 0,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(icon, size: 12, color: AppTheme.primary),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
