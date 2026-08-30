import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/risk_result.dart';
import '../../services/checker_repository.dart';
import '../../services/free_quota_service.dart';
import '../../services/screenshot_analyzer.dart';
import '../../services/subscription_service.dart';
import '../../services/screenshot_hybrid_analyzer.dart';
import '../../widgets/ai_unavailable_banner.dart';
import '../../widgets/quota_exhausted_dialog.dart';
import '../../widgets/risk_disclaimer.dart';

/// Screenshot Scanner screen — two-stage OCR → Analyze flow.
///
/// Stage 1 (OCR + preview): the user picks a screenshot, ML Kit's
/// on-device Latin script recognizer extracts the text, and it
/// renders immediately so the user can review what was read before
/// the analyzer runs.
///
/// Stage 2 (Analyze): the user taps the primary CTA, the hybrid
/// analyzer (message + URL engines, Gemini only when local
/// confidence < 0.80) runs over the extracted text, and the full
/// result surface renders.
///
/// Quota gates (monthly + per-kind screenshot) run at stage 1 so
/// the expensive OCR never fires when we'd refuse. Tapping Analyze
/// does not consume additional quota.
class ScreenshotScannerScreen extends StatefulWidget {
  const ScreenshotScannerScreen({super.key});

  @override
  State<ScreenshotScannerScreen> createState() =>
      _ScreenshotScannerScreenState();
}

class _ScreenshotScannerScreenState
    extends State<ScreenshotScannerScreen> {
  final ImagePicker _picker = ImagePicker();

  // Latin covers English + the Romanized chunks commonly seen in
  // Bangladeshi chat screenshots. Bengali (`TextRecognitionScript.bengali`
  // in v0.13+) needs a sandbox accuracy pass before we flip the default.
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  final ScreenshotHybridAnalyzer _analyzer = ScreenshotHybridAnalyzer();

  File? _image;
  String _extractedText = '';
  ScreenshotAnalysis? _result;
  _Stage _stage = _Stage.idle;

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickImage() async {
    XFile? image;
    try {
      image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      // image_picker throws `photo_access_denied` (Android) / `photos`
      // (iOS) when the user hasn't granted gallery access.
      _showMessage(_tr('screenshotScanner.permissionDenied'));
      debugPrint('[ScreenshotScanner] picker denied: ${e.message}');
      return;
    } catch (e) {
      if (!mounted) return;
      _showMessage(_tr('screenshotScanner.errorGeneric'));
      debugPrint('[ScreenshotScanner] picker error: $e');
      return;
    }

    if (image == null) return;

    setState(() => _image = File(image!.path));
    await _runOcr(image.path);
  }

  Future<void> _runOcr(String path) async {
    // Snapshot both scopes synchronously so the
    // `use_build_context_synchronously` lint doesn't fire when we
    // reach `QuotaExhaustedSheet.show(context)` after an `await`.
    final quota = FreeQuotaScope.of(context);
    final subscription = SubscriptionScope.of(context);

    final allowed = await quota.consume();
    if (!allowed) {
      if (!mounted) return;
      await QuotaExhaustedSheet.show(context);
      _resetToIdle();
      return;
    }

    final kindAllowed =
        await subscription.recordScan(ScanType.screenshot);
    if (!kindAllowed) {
      if (!mounted) return;
      await QuotaExhaustedSheet.show(context);
      _resetToIdle();
      return;
    }

    setState(() {
      _extractedText = '';
      _result = null;
      _stage = _Stage.ocrProcessing;
    });

    String text;
    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      text = recognizedText.text.trim();
    } catch (e, st) {
      if (!mounted) return;
      debugPrint('[ScreenshotScanner] OCR failed: $e');
      debugPrintStack(stackTrace: st, maxFrames: 4);
      _showMessage(_tr('screenshotScanner.errorGeneric'));
      _resetToIdle();
      return;
    }

    if (text.isEmpty) {
      if (!mounted) return;
      _showMessage(_tr('screenshotScanner.emptyText'));
      _resetToIdle();
      return;
    }

    if (!mounted) return;
    setState(() {
      _extractedText = text;
      _stage = _Stage.ocrComplete;
    });
  }

  Future<void> _runAnalysis() async {
    if (_stage != _Stage.ocrComplete || _extractedText.isEmpty) return;

    setState(() => _stage = _Stage.analyzing);

    final ScreenshotAnalysis result;
    try {
      result = await _analyzer.analyze(_extractedText);
    } catch (e, st) {
      if (!mounted) return;
      debugPrint('[ScreenshotScanner] analyze failed: $e');
      debugPrintStack(stackTrace: st, maxFrames: 4);
      _showMessage(_tr('screenshotScanner.errorGeneric'));
      setState(() => _stage = _Stage.ocrComplete);
      return;
    }

    // Best-effort history. Truncate the OCR text so the history row
    // stays a hint, not a full transcript.
    try {
      final preview = _extractedText.length > _kHistoryPreviewChars
          ? _extractedText.substring(0, _kHistoryPreviewChars)
          : _extractedText;
      await CheckerRepository().saveScan(
        result: RiskResult(
          level: result.messageResult.level,
          score: result.score,
          confidence: result.messageResult.confidence,
          reasons: result.reasons,
          recommendations: result.recommendations,
          category: result.category,
          usedAi: result.messageResult.usedAi,
        ),
        originalText: preview,
        type: ScanType.screenshot,
      );
    } catch (e) {
      debugPrint('[ScreenshotScanner] history save failed: $e');
    }

    if (!mounted) return;
    setState(() {
      _result = result;
      _stage = _Stage.complete;
    });
  }

  // Quota already spent at OCR stage stays spent; this only clears
  // local screen state so the user can pick a new image.
  void _resetToIdle() {
    if (!mounted) return;
    setState(() {
      _image = null;
      _extractedText = '';
      _result = null;
      _stage = _Stage.idle;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  String _tr(String key) => AppLocaleScope.of(context).tr(key);

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('screenshotScanner.appBarTitle')),
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
                t('screenshotScanner.heading'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t('screenshotScanner.subheading'),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              _buildImagePicker(t),
              if (_stage == _Stage.ocrProcessing) ...[
                const SizedBox(height: 16),
                _ProcessingIndicator(
                  caption: t('screenshotScanner.processing'),
                ),
              ],
              if (_stage == _Stage.ocrComplete) ...[
                const SizedBox(height: 16),
                Text(
                  t('screenshotScanner.extractedPreviewHint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                _buildExtractedTextPanel(_extractedText),
                const SizedBox(height: 14),
                _AnalyzeCta(onPressed: _runAnalysis, label: t('screenshotScanner.analyzeCta')),
                const SizedBox(height: 8),
                _ReScanLink(onPressed: _pickImage, label: t('screenshotScanner.reScanCta')),
              ],
              if (_stage == _Stage.analyzing) ...[
                const SizedBox(height: 16),
                _ProcessingIndicator(
                  caption: t('screenshotScanner.analyzing'),
                ),
                const SizedBox(height: 12),
                _buildExtractedTextPanel(_extractedText),
              ],
              if (_stage == _Stage.complete && _result != null) ...[
                const SizedBox(height: 24),
                _buildResultHeader(context, _result!),
                if (_result!.aiWasUnavailable) ...[
                  const SizedBox(height: 12),
                  AiUnavailableBanner(
                    text: t('result.aiUnavailable'),
                  ),
                ],
                if (_result!.reasons.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildReasonsPanel(_result!),
                ],
                if (_result!.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildRecommendationsPanel(_result!),
                ],
                const SizedBox(height: 16),
                _buildScanAnother(t),
                const SizedBox(height: 12),
                RiskDisclaimer(text: t('result.disclaimer')),
              ],
              // Always-visible safety notice — mirrors the URL checker so
              // both screens communicate their privacy/limitation guidance
              // before the user even starts a scan.
              const SizedBox(height: 16),
              _buildSafetyNotice(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker(AppLocaleTr t) {
    final isBusy = _stage == _Stage.ocrProcessing ||
        _stage == _Stage.analyzing;
    return GestureDetector(
      onTap: isBusy ? null : _pickImage,
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          gradient: AppTheme.headerGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: AppTheme.tintBorderStrong),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_image == null)
              _buildPickerPlaceholder(t)
            else
              Image.file(_image!, fit: BoxFit.cover),
            if (_image != null && !isBusy)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  ),
                  child: IconButton(
                    tooltip: t('screenshotScanner.scanAnother'),
                    onPressed: _pickImage,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            // OCR-time spinner overlay sits on top of the image so
            // the user sees progress even when the gallery image is
            // mostly white/black.
            if (_stage == _Stage.ocrProcessing)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerPlaceholder(AppLocaleTr t) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          t('screenshotScanner.pickerTitle'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t('screenshotScanner.pickerFormats'),
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.80),
          ),
        ),
      ],
    );
  }

  Widget _buildResultHeader(BuildContext context, ScreenshotAnalysis result) {
    final level = _scoreToRiskLevel(result.score);
    final color = _colorForLevel(level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
        border: Border.all(color: color.withValues(alpha: AppTheme.tintBorder)),
      ),
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
              _iconForLevel(level),
              color: color,
              size: 38,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _titleForLevel(level),
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
          const SizedBox(height: 10),
          _buildAiBadge(result.messageResult.usedAi),
          if (result.urlResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildLinksDetectedPanel(result, AppLocaleScope.of(context).tr),
          ],
        ],
      ),
    );
  }

  Widget _buildLinksDetectedPanel(
    ScreenshotAnalysis result,
    AppLocaleTr t,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusXs),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.link_rounded,
                size: 16,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                t('screenshotScanner.linksDetected'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...result.urlResults.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                u.url,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractedTextPanel(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr('screenshotScanner.extractedHeader'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusXs),
            ),
            child: SelectableText(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonsPanel(ScreenshotAnalysis result) {
    final color = _colorForLevel(_scoreToRiskLevel(result.score));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr('screenshotScanner.why'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...result.reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(reason)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsPanel(ScreenshotAnalysis result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: AppTheme.tintPanel),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.secondary.withValues(alpha: AppTheme.tintBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tr('screenshotScanner.recommendationsHeader'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...result.recommendations.map(
            (rec) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 20,
                    color: AppTheme.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rec,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanAnother(AppLocaleTr t) {
    return OutlinedButton.icon(
      onPressed: _pickImage,
      icon: const Icon(Icons.refresh_rounded),
      label: Text(t('screenshotScanner.scanAnother')),
    );
  }

  Widget _buildSafetyNotice(AppLocaleTr t) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t('screenshotScanner.safetyNotice'),
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

  Widget _buildAiBadge(bool usedAi) {
    final key = usedAi
        ? 'screenshotScanner.aiAssisted'
        : 'screenshotScanner.localOnly';
    final color = usedAi ? AppTheme.primary : AppTheme.textSecondary;
    final icon = usedAi
        ? Icons.auto_awesome_rounded
        : Icons.verified_user_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppTheme.tintSurface),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: color.withValues(alpha: AppTheme.tintBorder)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _tr(key),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Score-to-tier thresholds are tighter than the URL checker so a
  // single flagged URL can still push a screenshot into "medium".
  RiskLevel _scoreToRiskLevel(int score) {
    if (score >= 80) return RiskLevel.critical;
    if (score >= 60) return RiskLevel.high;
    if (score >= 35) return RiskLevel.medium;
    if (score >= 15) return RiskLevel.low;
    return RiskLevel.safe;
  }

  Color _colorForLevel(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
      case RiskLevel.low:
        return level == RiskLevel.safe ? AppTheme.success : AppTheme.secondary;
      case RiskLevel.medium:
        return AppTheme.warning;
      case RiskLevel.high:
        return AppTheme.riskHigh;
      case RiskLevel.critical:
        return AppTheme.danger;
    }
  }

  IconData _iconForLevel(RiskLevel level) {
    switch (level) {
      case RiskLevel.safe:
        return Icons.verified_rounded;
      case RiskLevel.low:
        return Icons.shield_outlined;
      case RiskLevel.medium:
        return Icons.warning_amber_rounded;
      case RiskLevel.high:
      case RiskLevel.critical:
        return Icons.gpp_bad_rounded;
    }
  }

  String _titleForLevel(RiskLevel level) {
    final key = switch (level) {
      RiskLevel.safe => 'screenshotScanner.titleSafe',
      RiskLevel.low => 'screenshotScanner.titleLow',
      RiskLevel.medium => 'screenshotScanner.titleMedium',
      RiskLevel.high => 'screenshotScanner.titleHigh',
      RiskLevel.critical => 'screenshotScanner.titleCritical',
    };
    return _tr(key);
  }
}

const int _kHistoryPreviewChars = 200;

typedef AppLocaleTr = String Function(String key);

/// Spinner + caption pill used while ML Kit OCR or the analyzer
/// runs.
class _ProcessingIndicator extends StatelessWidget {
  const _ProcessingIndicator({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 12),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary gradient CTA between the OCR preview and analysis. Same
/// visual vocabulary as the message checker / Go Premium buttons.
class _AnalyzeCta extends StatelessWidget {
  const _AnalyzeCta({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
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
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReScanLink extends StatelessWidget {
  const _ReScanLink({required this.onPressed, required this.label});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: Text(label),
      ),
    );
  }
}

enum _Stage {
  idle,
  ocrProcessing,
  ocrComplete,
  analyzing,
  complete,
}
