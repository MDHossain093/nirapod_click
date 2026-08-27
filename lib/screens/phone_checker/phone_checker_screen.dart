import 'package:flutter/material.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/phone_risk_result.dart';
import '../../models/risk_result.dart';
import '../../services/checker_repository.dart';
import '../../services/free_quota_service.dart';
import '../../services/phone_risk_engine.dart';
import '../../services/report_service.dart';
import '../../widgets/quota_exhausted_dialog.dart';
import '../../widgets/risk_disclaimer.dart';

/// Phone Number Checker screen.
///
/// Flow:
///   1. user types a BD mobile number into the field
///   2. taps **Check Number**
///   3. the screen pulls community-report counts from Firestore via
///      [ReportService.getPhoneReportCounts]
///   4. [PhoneRiskEngine.analyze] combines local rules + community
///      reports into a final risk score
///   5. the result card shows operator, score, reasons, and
///      what-to-do recommendations
///   6. user can submit their own report against the number via
///      [ReportService.submitPhoneReport]; after a successful
///      submission the check is re-run so the score updates.
///
/// The screen is purely orchestration: it owns the controller and
/// the loading flag, and delegates actual decision-making to the
/// engine and Firestore I/O to the service.
class PhoneCheckerScreen extends StatefulWidget {
  const PhoneCheckerScreen({super.key});

  @override
  State<PhoneCheckerScreen> createState() =>
      _PhoneCheckerScreenState();
}

class _PhoneCheckerScreenState extends State<PhoneCheckerScreen> {
  final _controller = TextEditingController();
  final _engine = PhoneRiskEngine();
  final _reportService = ReportService();

  PhoneRiskResult? _result;
  bool _isChecking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _tr(String key) => AppLocaleScope.of(context).tr(key);

  Future<void> _checkNumber() async {
    final number = _controller.text.trim();

    if (number.isEmpty) {
      _showMessage(_tr('phoneChecker.emptyInput'));
      return;
    }

    // Free-tier gate: same posture as the message / URL / screenshot
    // checkers. Premium bypasses; free users see the upgrade sheet
    // when the budget is gone.
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

    // Pull community reports from Firestore. If the fetch fails we
    // don't abort the whole check — we fall back to zero counts and
    // surface a friendly snackbar so the local rules still run.
    var reportCount = 0;
    var reportTypes = const <String>[];
    var reportsFailed = false;

    try {
      final counts = await _reportService.getPhoneReportCounts(number);
      reportCount = counts.total;
      reportTypes = counts.reportTypes;
    } catch (_) {
      reportsFailed = true;
    }

    // Small cosmetic delay so the spinner is perceptible even when
    // the verdict is instant. Local rule evaluation finishes in
    // microseconds; without this the user sees no feedback.
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    final result = _engine.analyze(
      number,
      reportCount: reportCount,
      reportTypes: reportTypes,
    );

    setState(() {
      _isChecking = false;
      _result = result;
    });

    // Best-effort history save (mirrors message-checker / URL-checker flow).
    if (result.isValid) {
      try {
        await CheckerRepository().saveScan(
          result: result.toRiskResult(),
          originalText: result.phoneNumber,
          type: ScanType.phone,
        );
      } catch (_) {
        // ignored — a Firestore hiccup shouldn't block showing the verdict.
      }
    }

    if (reportsFailed) {
      _showMessage(_tr('phoneChecker.reportsFetchFailed'));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  /// Opens a modal sheet for submitting a community report against
  /// the currently-checked phone number. Only callable after a
  /// successful check (the button is wired inside [_buildResult]).
  Future<void> _showReportDialog() async {
    // Defensive: the button lives inside the result card so this
    // should always be set, but guard anyway so a future refactor
    // can't surface a confusing error.
    if (_result == null || !_result!.isValid) {
      _showMessage(_tr('phoneChecker.reportInvalidPhone'));
      return;
    }

    String selectedType = 'scam';
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(_tr('phoneChecker.reportDialogTitle')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        labelText: _tr('phoneChecker.reportReasonLabel'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'scam',
                          child: Text(_tr('phoneChecker.reportReasonScam')),
                        ),
                        DropdownMenuItem(
                          value: 'payment',
                          child: Text(
                            _tr('phoneChecker.reportReasonPayment'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'otp',
                          child: Text(_tr('phoneChecker.reportReasonOtp')),
                        ),
                        DropdownMenuItem(
                          value: 'job',
                          child: Text(_tr('phoneChecker.reportReasonJob')),
                        ),
                        DropdownMenuItem(
                          value: 'harassment',
                          child: Text(
                            _tr('phoneChecker.reportReasonHarassment'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text(_tr('phoneChecker.reportReasonOther')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText:
                            _tr('phoneChecker.reportDetailsLabel'),
                        hintText: _tr('phoneChecker.reportDetailsHint'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(_tr('phoneChecker.reportCancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(_tr('phoneChecker.reportSubmit')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) {
      descriptionController.dispose();
      return;
    }

    try {
      await _reportService.submitPhoneReport(
        phone: _result!.phoneNumber,
        type: selectedType,
        description: descriptionController.text,
      );

      if (!mounted) return;
      _showMessage(_tr('phoneChecker.reportSuccess'));

      // Optimistic refresh: re-run the check so the just-submitted
      // report is reflected in the score without making the user
      // hit "Check" again.
      await _checkNumber();
    } catch (_) {
      if (!mounted) return;
      _showMessage(_tr('phoneChecker.reportFailure'));
    } finally {
      descriptionController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_tr('phoneChecker.appBarTitle')),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr('phoneChecker.heading'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _tr('phoneChecker.subheading'),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: _tr('phoneChecker.hint'),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),

              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  // Brand header gradient token — same `primary →
                  // secondary` as the AppBar + Go Premium + Profile
                  // upsell CTAs.
                  gradient: AppTheme.headerGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.30),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    onTap: _isChecking ? null : _checkNumber,
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
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.search_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _tr('phoneChecker.check'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
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

              const SizedBox(height: 28),

              if (_result != null) _buildResult(_result!),

              const SizedBox(height: 24),

              _buildSafetyNotice(),
              const SizedBox(height: 12),
              RiskDisclaimer(text: _tr('result.disclaimer')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(PhoneRiskResult result) {
    final color = _getColor(result.level);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.phone_rounded,
            size: AppTheme.tileIconXs,
            color: color,
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

          const SizedBox(height: 6),

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

          const SizedBox(height: 16),

          _infoRow(
            _tr('phoneChecker.numberLabel'),
            result.phoneNumber,
          ),

          _infoRow(
            _tr('phoneChecker.operatorLabel'),
            result.operator,
          ),

          _infoRow(
            _tr('phoneChecker.reportsLabel'),
            AppLocaleScope.of(context).formatNumber(result.reportCount),
          ),

          const SizedBox(height: 20),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _tr('phoneChecker.why'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (result.reasons.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No suspicious reports were found.',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),

          ...result.reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(reason)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _tr('phoneChecker.recommendationsHeader'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          const SizedBox(height: 12),

          ...result.recommendations.map(
            (recommendation) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppTheme.secondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(recommendation)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showReportDialog,
              icon: const Icon(Icons.flag_outlined),
              label: Text(_tr('phoneChecker.reportButton')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Label can grow long in Bangla; let it truncate at one
          // line so the value column stays right-aligned and the row
          // height stays predictable.
          Flexible(
            child: Text(
              '$label:',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: AppTheme.tintSurface),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _tr('phoneChecker.safetyNotice'),
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

  Color _getColor(PhoneRiskLevel level) {
    switch (level) {
      case PhoneRiskLevel.safe:
        return AppTheme.success;
      case PhoneRiskLevel.low:
        return AppTheme.secondary;
      case PhoneRiskLevel.medium:
        return AppTheme.warning;
      case PhoneRiskLevel.high:
        return AppTheme.riskHigh;
      case PhoneRiskLevel.critical:
        return AppTheme.danger;
    }
  }

  String _getTitle(PhoneRiskLevel level) {
    switch (level) {
      case PhoneRiskLevel.safe:
        return _tr('phoneChecker.titleSafe');
      case PhoneRiskLevel.low:
        return _tr('phoneChecker.titleLow');
      case PhoneRiskLevel.medium:
        return _tr('phoneChecker.titleMedium');
      case PhoneRiskLevel.high:
        return _tr('phoneChecker.titleHigh');
      case PhoneRiskLevel.critical:
        return _tr('phoneChecker.titleCritical');
    }
  }
}
