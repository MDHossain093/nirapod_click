import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/risk_result.dart';
import '../../models/url_risk_result.dart';
import '../../services/checker_repository.dart';
import '../../services/free_quota_service.dart';
import '../../services/url_hybrid_analyzer.dart';
import '../../widgets/ai_unavailable_banner.dart';
import '../../widgets/quota_exhausted_dialog.dart';
import '../../widgets/risk_disclaimer.dart';

/// URL Checker screen.
///
/// Flow: user pastes a URL → tap **Check URL** →
///
///   1. local [UrlRiskEngine] verdict fires immediately;
///   2. if the local verdict is high-confidence (≥ 0.80), keep it;
///   3. otherwise call Gemini through [UrlHybridAnalyzer] and show
///      the AI verdict (silent local fallback on AI failure).
///
/// This mirrors the message-side `HybridAnalyzer` behaviour. The
/// hybrid routing lives in [UrlHybridAnalyzer] so the screen stays
/// orchestration-only.
class UrlCheckerScreen extends StatefulWidget {
  const UrlCheckerScreen({super.key, this.initialValue});

  /// Optional URL to pre-fill the input field with on first build.
  ///
  /// Used by the QR checker screen after a URL-shaped QR is decoded.
  /// The user can edit or clear before tapping "Check", so a
  /// pre-fill never auto-runs the analyzer.
  final String? initialValue;

  @override
  State<UrlCheckerScreen> createState() =>
      _UrlCheckerScreenState();
}

class _UrlCheckerScreenState
    extends State<UrlCheckerScreen> {
  late final TextEditingController _controller;
  final _hybrid = UrlHybridAnalyzer();

  UrlRiskResult? _result;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkUrl() async {
    final url = _controller.text.trim();

    if (url.isEmpty) {
      _showMessage(_tr('urlChecker.emptyInput'));
      return;
    }

    // Free-tier gate. Premium users always pass through. Free users
    // see the upgrade sheet when their monthly budget is gone.
    final quota = FreeQuotaScope.of(context);
    final allowed = await quota.consume();
    if (!allowed) {
      if (!mounted) return;
      await QuotaExhaustedSheet.show(context);
      return;
    }

    setState(() {
      _isChecking = true;
      _result = null;
    });

    // Small cosmetic delay so the spinner is perceptible even when
    // the verdict comes back instantly. The AI path takes much
    // longer than this on its own, so the delay is effectively
    // invisible for ambiguous URLs.
    await Future.delayed(
      const Duration(milliseconds: 200),
    );

    final result = await _hybrid.analyzeUrl(url);

    if (!mounted) return;

    setState(() {
      _isChecking = false;
      _result = result;
    });

    // Best-effort history save (mirrors the message-checker flow).
    try {
      await CheckerRepository().saveScan(
        result: result.toRiskResult(),
        originalText: url,
        type: ScanType.url,
      );
    } catch (_) {
      // ignored — a Firestore hiccup shouldn't block showing the verdict.
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _tr(String key) =>
      AppLocaleScope.of(context).tr(key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_tr('urlChecker.appBarTitle')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.headerGradient,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                _tr('urlChecker.heading'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _tr('urlChecker.subheading'),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: _tr('urlChecker.hint'),
                  prefixIcon: const Icon(
                    Icons.link_rounded,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        // Brand header gradient token — same
                        // `primary → secondary` as the AppBar +
                        // Go Premium + Profile upsell CTAs.
                        gradient: AppTheme.headerGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: AppTheme.tintBorder),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                          onTap:
                              _isChecking ? null : _checkUrl,
                          child: Center(
                            child: _isChecking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.security_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _tr('urlChecker.check'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight:
                                              FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              if (_result != null)
                _buildResult(context, _result!),

              const SizedBox(height: 24),

              _buildSafetyNotice(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context, UrlRiskResult result) {
    final color = _getColor(result.level);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(
          color: color.withValues(alpha: AppTheme.tintBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          if (result.aiWasUnavailable) ...[
            AiUnavailableBanner(
              text: _tr('result.aiUnavailable'),
            ),
            const SizedBox(height: 16),
          ],
          Center(
            child: Column(
              children: [
                Container(
                  width: AppTheme.tileIconXl,
                  height: AppTheme.tileIconXl,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: AppTheme.tintSurface),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIcon(result.level),
                    color: color,
                    size: 38,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _getTitle(result.level),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  AppLocaleScope.of(context).formatScore(result.score),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  result.category,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _tr('urlChecker.confidence')
                      .replaceAll(
                    '{percent}',
                    AppLocaleScope.of(context)
                        .formatNumber((result.confidence * 100).round()),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 8),

                // Provenance badge so the user can tell whether the
                // verdict came from local rules or from Gemini.
                _buildSourceBadge(result.usedAi),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            _tr('urlChecker.urlLabel'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusXs),
            ),
            child: Text(
              result.url,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                wordSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            _tr('urlChecker.why'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          if (result.reasons.isEmpty)
            Text(
              _tr('urlChecker.noWarnings'),
              style: const TextStyle(
                color: AppTheme.textSecondary,
              ),
            ),

          ...result.reasons.map(
            (reason) => Padding(
              padding:
                  const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(reason),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          Text(
            _tr('urlChecker.recommendationsHeader'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          ...result.recommendations.map(
            (recommendation) => Padding(
              padding:
                  const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 20,
                    color: AppTheme.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(recommendation),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          RiskDisclaimer(text: _tr('result.disclaimer')),
        ],
      ),
    );
  }

  Widget _buildSafetyNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(
          alpha: AppTheme.tintSurface,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _tr('urlChecker.safetyNotice'),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(bool usedAi) {
    final key =
        usedAi ? 'urlChecker.aiAssisted' : 'urlChecker.localOnly';
    final color = usedAi ? AppTheme.primary : AppTheme.textSecondary;
    final icon = usedAi
        ? Icons.auto_awesome_rounded
        : Icons.bolt_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.tintSurface),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            _tr(key),
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(UrlRiskLevel level) {
    switch (level) {
      case UrlRiskLevel.safe:
        return AppTheme.success;
      case UrlRiskLevel.low:
        return AppTheme.secondary;
      case UrlRiskLevel.medium:
        return AppTheme.warning;
      case UrlRiskLevel.high:
        return AppTheme.riskHigh;
      case UrlRiskLevel.critical:
        return AppTheme.danger;
    }
  }

  IconData _getIcon(UrlRiskLevel level) {
    switch (level) {
      case UrlRiskLevel.safe:
        return Icons.verified_rounded;
      case UrlRiskLevel.low:
        return Icons.shield_outlined;
      case UrlRiskLevel.medium:
        return Icons.warning_amber_rounded;
      case UrlRiskLevel.high:
      case UrlRiskLevel.critical:
        return Icons.gpp_bad_rounded;
    }
  }

  String _getTitle(UrlRiskLevel level) {
    switch (level) {
      case UrlRiskLevel.safe:
        return _tr('urlChecker.titleSafe');
      case UrlRiskLevel.low:
        return _tr('urlChecker.titleLow');
      case UrlRiskLevel.medium:
        return _tr('urlChecker.titleMedium');
      case UrlRiskLevel.high:
        return _tr('urlChecker.titleHigh');
      case UrlRiskLevel.critical:
        return _tr('urlChecker.titleCritical');
    }
  }
}
