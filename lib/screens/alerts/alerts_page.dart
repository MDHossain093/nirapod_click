import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/locale/app_locale.dart';
import '../../core/locale/localizer.dart';
import '../../core/theme/app_theme.dart';
import '../../models/admin_alert.dart';
import '../../models/safety_alert.dart';
import '../../services/alert_service.dart';
import '../../services/checker_repository.dart';
import '../history/risk_result_page.dart';

/// Stream of alerts the user has *not yet seen*, in reverse chronological
/// order (newest first). Same Today/Yesterday grouping as the iOS-style
/// list views elsewhere in the app.
///
/// Reached from the [AlertBadgeBell] on Home. Unlike [HistoryPage]
/// this screen is read-only — there is no row menu, no clear button,
/// no scan-type filter. The bell already aggregates the count, so the
/// screen is just "show me what I missed."
class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key, this.service});

  /// Injected for tests; defaults to the app-wide singleton.
  final AlertService? service;

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  late final AlertService _service;
  Future<void>? _ready;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AlertService.instance;
    _ready = _ensureFreshAuth();
    // Mark visible IDs as seen on entry. The bell also does this
    // optimistically, but doing it here too covers the case where the
    // user opened the screen via a deep link or future entry point.
    _service.ensureStarted();
  }

  /// Same race-cure pattern as [HistoryPage] — force a token refresh
  /// before the stream opens so the first read after sign-in doesn't
  /// hit a stale ID token and return `permission-denied`.
  ///
  /// Bounded by a 5-second timeout so a hanging Firebase token
  /// refresh (offline / slow network / backend hiccup) doesn't leave
  /// the spinner on screen forever. The stream will surface the real
  /// error if the token truly is stale — the timeout is only there to
  /// guarantee the UI moves past the loading state.
  static const Duration _authReadyTimeout = Duration(seconds: 5);

  Future<void> _ensureFreshAuth() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.getIdToken(true).timeout(_authReadyTimeout);
    } catch (_) {
      // Don't block the UI — the stream will surface the real error.
    }
  }

  /// Truncate at a word boundary so we don't end on a partial word.
  /// Falls back to the hard slice if the input has no spaces (e.g. URLs).
  String _preview(String text, {int max = 80}) {
    if (text.length <= max) return text;
    final cut = text.lastIndexOf(' ', max);
    return '${cut > 0 ? text.substring(0, cut) : text.substring(0, max)}…';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('alerts.appBarTitle')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
          ),
        ),
      ),
      // We seed the body with [_service.lastAlerts] (a synchronous
      // snapshot) so the very first frame already has something to
      // render — the badge bell on Home has typically already received
      // an emission by the time the user opens this page, and a fresh
      // `StreamBuilder` on a broadcast stream only sees values emitted
      // *after* subscribe. Without the seed, the page would flicker
      // empty → spinner → content for a frame or two.
      //
      // The spinner inside [_Body] is only shown when we genuinely
      // have *no* data AND the stream hasn't emitted yet — and it
      // gives up after a short window so a stuck Firestore query
      // never traps the UI on a perpetual loading screen.
      body: FutureBuilder<void>(
        future: _ready,
        builder: (context, readySnap) {
          if (readySnap.connectionState != ConnectionState.done) {
            // Pre-ready: still try to render anything we have cached
            // from the bell subscription. Only fall back to the
            // spinner if there's literally nothing yet.
            final cached = _service.lastAlerts;
            if (cached.isNotEmpty) {
              return _Body(
                service: _service,
                preview: _preview,
                initialAlerts: cached,
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          return _Body(
            service: _service,
            preview: _preview,
            initialAlerts: _service.lastAlerts,
          );
        },
      ),
    );
  }
}

/// Body widget for [AlertsPage]. Owns the live stream subscription
/// and degrades gracefully when Firestore is unreachable: it seeds
/// with [initialAlerts] (synchronous snapshot from the singleton),
/// then listens for fresh emissions, and stops showing a spinner
/// once any non-empty data has been delivered. A stuck fetch
/// (permission-denied, offline, hung listener) is bounded — the
/// loading affordance disappears after [_loadingGracePeriod] even
/// if no emission has arrived, so the user always sees either real
/// content or the empty-state card rather than a perpetual wheel.
class _Body extends StatefulWidget {
  const _Body({
    required this.service,
    required this.preview,
    required this.initialAlerts,
  });

  final AlertService service;
  final String Function(String) preview;
  final List<SafetyAlert> initialAlerts;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// How long we keep showing the spinner after first build when
  /// nothing has been delivered yet. Long enough to outlast a slow
  /// Firestore cold-start on flaky networks; short enough that a
  /// hung listener doesn't trap the user on a perpetual wheel.
  static const Duration _loadingGracePeriod = Duration(seconds: 6);

  late List<SafetyAlert> _alerts;
  bool _streamEmitted = false;
  Object? _streamError;
  Timer? _graceTimer;
  bool _graceExpired = false;
  StreamSubscription<List<SafetyAlert>>? _sub;

  @override
  void initState() {
    super.initState();
    _alerts = widget.initialAlerts;
    // If we already have content (typical: bell seeded it), no need
    // to start a grace timer — the screen has data on the first frame.
    if (_alerts.isNotEmpty) {
      _streamEmitted = true;
    }
    _sub = widget.service.watchAlerts().listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _alerts = list;
          _streamEmitted = true;
          _streamError = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        // Don't replace the rendered list with an error screen if
        // we already have content to show — just record the error
        // for diagnostics and let the user keep reading. Only when
        // we have *nothing* does the error UI surface (handled in
        // build()).
        debugPrint('[AlertsPage] stream error: $e');
        setState(() {
          _streamError = e;
          _streamEmitted = true;
        });
      },
    );
    // Only start the grace timer when we have no content to show —
    // otherwise the screen would briefly flicker a spinner even
    // though we already have data.
    if (_alerts.isEmpty) {
      _graceTimer = Timer(_loadingGracePeriod, () {
        if (!mounted) return;
        setState(() => _graceExpired = true);
      });
    }
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;

    // Decide what to render:
    //  1. If we have alerts → list.
    //  2. Else if the stream errored with no cached data → error text.
    //  3. Else if the stream has emitted (even an empty list) → empty state.
    //  4. Else if the grace period expired → empty state (better than
    //     a perpetual wheel when Firestore is unreachable).
    //  5. Else → spinner.
    if (_alerts.isNotEmpty) {
      return _AlertsList(alerts: _alerts, preview: widget.preview);
    }
    if (_streamError != null && _streamEmitted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t('alerts.loadError')
                .replaceAll('{error}', '$_streamError'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_streamEmitted || _graceExpired) {
      return _EmptyState();
    }
    return const Center(child: CircularProgressIndicator());
  }
}

/// Full-bleed empty state — matches the visual idiom of
/// [HistoryPage]'s empty state (large tinted icon + title + body) so
/// the two screens feel like siblings.
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.riskCritical.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 48,
                color: AppTheme.riskCritical,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('alerts.emptyTitle'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('alerts.emptyBody'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the alerts. Admin-published items are pinned to the top
/// under their own header; scan-derived items are grouped by Today /
/// Yesterday / Earlier this week / Earlier below. We use a single
/// ListView (rather than NestedScrollView) because the headers don't
/// need to stick — at the scale of a personal alert list (≤ 50
/// entries), the user can scroll freely.
class _AlertsList extends StatelessWidget {
  const _AlertsList({required this.alerts, required this.preview});

  final List<SafetyAlert> alerts;
  final String Function(String) preview;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;

    // Split the merged stream into admin vs scan lists while
    // preserving order. AdminAlertItem instances live above
    // ScanAlert instances because AlertService pins them that way.
    final adminAlerts = <AdminAlertItem>[];
    final scanAlerts = <ScanAlert>[];
    for (final a in alerts) {
      if (a is AdminAlertItem) {
        adminAlerts.add(a);
      } else if (a is ScanAlert) {
        scanAlerts.add(a);
      }
    }

    final now = DateTime.now();
    final groups = <String, List<ScanAlert>>{
      'today': <ScanAlert>[],
      'yesterday': <ScanAlert>[],
      'earlierThisWeek': <ScanAlert>[],
      'earlier': <ScanAlert>[],
    };
    for (final scan in scanAlerts) {
      final dt = scan.createdAt;
      final bucket = dt == null
          ? 'today'
          : dayBucket(dt is DateTime ? dt : now, now: now);
      groups[bucket]!.add(scan);
    }

    final orderedKeys = const [
      'today',
      'yesterday',
      'earlierThisWeek',
      'earlier',
    ];

    final items = <Widget>[];

    // ---- Admin-published banner cards ----
    if (adminAlerts.isNotEmpty) {
      items.add(_SectionHeader(
        label: t('alerts.adminHeader'),
      ));
      for (final a in adminAlerts) {
        items.add(_AdminAlertCard(item: a));
        items.add(const SizedBox(height: 8));
      }
      items.add(const SizedBox(height: 16));
    }

    // ---- Scan-derived alerts grouped by recency ----
    for (final key in orderedKeys) {
      final rows = groups[key]!;
      if (rows.isEmpty) continue;
      items.add(_SectionHeader(label: t('alerts.group.$key')));
      for (final scan in rows) {
        items.add(_AlertRow(entry: scan.entry, preview: preview));
        items.add(const SizedBox(height: 8));
      }
      items.add(const SizedBox(height: 12));
    }
    if (items.isNotEmpty && items.last is SizedBox) items.removeLast();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: items,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// One row in the alerts list. Mirrors the HistoryPage row shape but
/// with the red critical color locked in (every row is an alert, and
/// every alert is at least `critical`).
class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.entry, required this.preview});

  final HistoryEntry entry;
  final String Function(String) preview;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final result = entry.result;
    final style = RiskStyle.of(result.level);
    final typeMeta = scanTypeMeta(entry.type);
    final hasOriginal = entry.originalText.trim().isNotEmpty;

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RiskResultPage(
                result: result,
                originalText: entry.originalText,
              ),
            ),
          );
        },
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
                            result.level.localizedBadge,
                            style: TextStyle(
                              color: style.onColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ScanTypeChip(
                          icon: typeMeta.icon,
                          label: t(typeMeta.labelKey),
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
                    if (hasOriginal)
                      Text(
                        preview(entry.originalText),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      )
                    else
                      Text(
                        result.category,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'score ${AppLocaleScope.of(context).formatNumber(result.score)} \u00b7 '
                      '${AppLocaleScope.of(context).formatPercent(result.confidence)} '
                      '\u00b7 ${AppLocaleScope.of(context).formatNumber(result.reasons.length)} '
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
  }
}

/// Pill that renders the scan type next to the risk badge. Same visual
/// idiom as the one in `HistoryPage`, kept private here because the two
/// pages have slightly different padding needs (alerts rows are denser).
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
      // Wrap (not Row) so when the outer Wrap constrains the chip
      // tighter than its intrinsic width — e.g. a long "Phone Number"
      // label fitting next to a risk badge on a narrow row — the icon
      // + label can break onto two lines instead of overflowing the
      // chip's horizontal bound (matches the History page fix).
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

/// Admin-published safety banner. Distinct from scan-derived rows so
/// the visual treatment can be louder (full-bleed color band) and the
/// tap target can dismiss the alert in place rather than navigating
/// away. Mirrors the same Today/Yesterday grouping as scan alerts via
/// the section header in [_AlertsList].
class _AdminAlertCard extends StatelessWidget {
  const _AdminAlertCard({required this.item});

  final AdminAlertItem item;

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
    final alert = item.alert;
    final isBn = AppLocaleScope.of(context).locale == AppLocale.bangla;
    final title = (isBn && alert.titleBn.isNotEmpty)
        ? alert.titleBn
        : alert.titleEn;
    final body =
        (isBn && alert.bodyBn.isNotEmpty) ? alert.bodyBn : alert.bodyEn;

    final color = switch (alert.severity) {
      AdminAlert.severityCritical => AppTheme.riskCritical,
      AdminAlert.severityWarning => AppTheme.riskHigh,
      _ => AppTheme.primary,
    };
    final icon = switch (alert.severity) {
      AdminAlert.severityCritical => Icons.error_rounded,
      AdminAlert.severityWarning => Icons.warning_amber_rounded,
      _ => Icons.campaign_rounded,
    };
    final severityLabel = switch (alert.severity) {
      AdminAlert.severityCritical => t('alerts.severity.critical'),
      AdminAlert.severityWarning => t('alerts.severity.warning'),
      _ => t('alerts.severity.info'),
    };

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMd - 1.2),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    severityLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Text(
                  t('alerts.adminBadge'),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
