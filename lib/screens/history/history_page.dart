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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_tr(context, 'history.appBarTitle')),
        actions: [
          IconButton(
            tooltip: _tr(context, 'history.clearAction'),
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _confirmClear(context),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
          ),
        ),
      ),
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
            padding: const EdgeInsets.all(20),
            itemCount: checks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final entry = checks[i];
              final result = entry.result;
              final style = RiskStyle.of(result.level);
              final typeMeta = scanTypeMeta(entry.type);
              return Material(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RiskResultPage(
                        result: result,
                        originalText: entry.originalText,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: style.color.withValues(alpha: 0.12),
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
                                          label: _tr(context, typeMeta.labelKey),
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
                        const Icon(
                          Icons.chevron_right,
                          color: AppTheme.textSecondary,
                        ),
                      ],
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
