import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../services/checker_repository.dart';
import 'risk_result_page.dart';

/// Recent checks for the signed-in user, streamed from Firestore.
///
/// Renders every kind of check (message / URL / screenshot / phone)
/// in one timeline. Each row shows the risk color + badge, a small
/// scan-type chip so the user can tell what kind of check it was,
/// and the first line of the original text (truncated for privacy).
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  String _tr(BuildContext context, String key) =>
      AppLocaleScope.of(context).tr(key);

  String _dateLabel(DateTime? ts) {
    if (ts == null) return 'just now';
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final y = ts.year.toString().padLeft(4, '0');
    final m = ts.month.toString().padLeft(2, '0');
    final d = ts.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Per-scan-type icon + localized label key, in one place so the
  /// list and any future detail view stay in sync.
  ({IconData icon, String labelKey}) _typeMeta(ScanType t) {
    switch (t) {
      case ScanType.message:
        return (icon: Icons.chat_bubble_outline, labelKey: 'history.typeMessage');
      case ScanType.url:
        return (icon: Icons.link_rounded, labelKey: 'history.typeUrl');
      case ScanType.screenshot:
        return (
          icon: Icons.image_outlined,
          labelKey: 'history.typeScreenshot',
        );
      case ScanType.phone:
        return (icon: Icons.phone_outlined, labelKey: 'history.typePhone');
    }
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
    final repo = CheckerRepository();
    try {
      await repo.clearAll();
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
      ),
      body: StreamBuilder<List<HistoryEntry>>(
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
            padding: const EdgeInsets.all(16),
            itemCount: checks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final entry = checks[i];
              final result = entry.result;
              final style = RiskStyle.of(result.level);
              final createdAt = entry.createdAt is Timestamp
                  ? (entry.createdAt as Timestamp).toDate()
                  : null;
              final typeMeta = _typeMeta(entry.type);
              return Material(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RiskResultPage(result: result),
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
                            borderRadius: BorderRadius.circular(10),
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: style.color,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      style.badge,
                                      style: TextStyle(
                                        color: style.onColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Scan-type chip: keeps message/url/
                                  // screenshot/phone rows visually
                                  // distinguishable at a glance.
                                  _ScanTypeChip(
                                    icon: typeMeta.icon,
                                    label: _tr(context, typeMeta.labelKey),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _dateLabel(createdAt),
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
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
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'score ${result.score} \u00b7 '
                                '${(result.confidence * 100).toStringAsFixed(0)}% '
                                '\u00b7 ${result.reasons.length} '
                                'signal${result.reasons.length == 1 ? "" : "s"}',
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
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
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
