import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../screens/alerts/alerts_page.dart';
import '../services/alert_service.dart';

/// Header bell button for the safety alerts system.
///
/// Owns its own [Stream] subscription so only this widget rebuilds when
/// the unread count changes — important because [HomePage] is a
/// [StatelessWidget] that would otherwise rebuild on every alert.
///
/// Material 3 doesn't ship a built-in bell-with-badge widget, so the
/// badge is a `Stack` + `Positioned` red circle over the existing
/// 44×44 white icon container. The badge hides itself when the count
/// is zero so we don't show an empty red dot.
class AlertBadgeBell extends StatefulWidget {
  const AlertBadgeBell({super.key, this.service});

  /// Injected for tests; defaults to a fresh process-singleton service
  /// in production.
  final AlertService? service;

  @override
  State<AlertBadgeBell> createState() => _AlertBadgeBellState();
}

class _AlertBadgeBellState extends State<AlertBadgeBell> {
  late final AlertService _service;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AlertService.instance;
    // Kick off the subscription synchronously so the first emission
    // populates the badge without a frame of `0` flash. We don't await
    // — the listener will deliver values as they arrive.
    _service.ensureStarted();
    _count = _service.lastBadgeCount;
    _service.watchBadgeCount().listen((c) {
      if (!mounted) return;
      // Guard against identical-count emissions — the upstream
      // `_emitMergedAlerts` already dedupes the badge stream, but
      // this widget historically crashed with
      // `!semantics.parentDataDirty` when multiple rapid
      // `setState` calls stacked within a single frame. Defensive
      // double-guard: skip rebuild if the count hasn't actually
      // moved. (`AlertService` also caches and skips identical
      // broadcasts upstream, but we keep this in case a future
      // caller publishes directly into the stream.)
      if (c == _count) return;
      setState(() => _count = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasBadge = _count > 0;
    final label = _count > 99 ? '99+' : '$_count';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            // Compact so the IconButton honours the 44×44 Container
            // instead of expanding to 48 dp (visualDensity is the
            // parameter that works here; materialTapTargetSize isn't
            // accepted by IconButton).
            visualDensity: VisualDensity.compact,
            tooltip: hasBadge
                ? '$label unread safety alert${_count == 1 ? '' : 's'}'
                : 'No unread alerts',
            onPressed: _onTap,
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: AppTheme.primary,
              size: 22,
            ),
          ),
          if (hasBadge)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                // min-width so single digits look balanced; explicit
                // height keeps it a circle even when the label grows
                // to "99+".
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppTheme.riskCritical,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onTap() async {
    // Force a fresh admin-alerts fetch so the page opens with the
    // latest data (bypasses any in-flight poll that's a few seconds
    // stale). Runs in parallel with markSeen so it's free.
    unawaited(_service.refreshAdminAlerts());

    // Optimistically mark currently-known alerts as seen so the badge
    // clears immediately rather than waiting for the screen to pop and
    // re-emit. We re-emit on return anyway as a safety net (see below).
    final visible = _service.lastAlerts.map((e) => e.id).toList();
    await _service.markSeen(visible);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertsPage(service: _service),
      ),
    );
    // On return, force a badge re-emit so any newly-arrived alerts
    // (added while the user was on the alerts screen) show up.
    if (!mounted) return;
    final current = _service.lastAlerts.map((e) => e.id).toList();
    await _service.markSeen(current);
  }
}
