import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/risk_result.dart';
import '../../services/checker_repository.dart';
import '../../services/screenshot_analyzer.dart';
import '../../services/screenshot_hybrid_analyzer.dart';
import '../../widgets/ai_unavailable_banner.dart';
import '../../widgets/risk_disclaimer.dart';

/// Screenshot Scanner screen.
///
/// Flow:
///   1. User picks a screenshot from the gallery.
///   2. ML Kit [TextRecognizer] runs on-device OCR (Latin script).
///   3. The extracted text is fed to [ScreenshotAnalyzer], which runs
///      the message rule engine over the whole text **and** the URL
///      rule engine over every embedded URL.
///   4. The combined [ScreenshotAnalysis] is rendered with the same
///      header-card visual language as the URL Checker, plus a
///      "Links detected" panel listing every embedded URL that was
///      scanned.
///
/// First version was local-only — Gemini is now wired through
/// [ScreenshotHybridAnalyzer] (confidence-gated: only fires when the
/// local message+URL pipeline is below the 0.80 confidence threshold).
class ScreenshotScannerScreen extends StatefulWidget {
  const ScreenshotScannerScreen({super.key});

  @override
  State<ScreenshotScannerScreen> createState() =>
      _ScreenshotScannerScreenState();
}

class _ScreenshotScannerScreenState
    extends State<ScreenshotScannerScreen> {
  final ImagePicker _picker = ImagePicker();

  // Latin script covers both English and the Romanized chunks
  // commonly seen in Bangladeshi chat screenshots. Bengali script is
  // pending an ML Kit script-check (TextRecognitionScript.bengali
  // exists in v0.13+, but accuracy needs a sandbox test before we
  // flip the default).
  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  final ScreenshotHybridAnalyzer _analyzer = ScreenshotHybridAnalyzer();

  File? _image;
  String _extractedText = '';
  ScreenshotAnalysis? _result;
  bool _isProcessing = false;

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
      // image_picker throws PlatformException with code
      // 'photo_access_denied' (Android) / 'photos' (iOS) when the
      // user has not granted gallery access.
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

    setState(() {
      _image = File(image!.path);
      _extractedText = '';
      _result = null;
    });

    await _processImage(image.path);
  }

  Future<void> _processImage(String path) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final inputImage = InputImage.fromFilePath(path);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text.trim();

      if (text.isEmpty) {
        if (!mounted) return;
        _showMessage(_tr('screenshotScanner.emptyText'));
        setState(() {
          _extractedText = '';
          _result = null;
        });
        return;
      }

      // Hybrid analyzer: pure-Dart first, Gemini only when the local
      // message+URL pipeline lands below the 0.80 confidence gate.
      final result = await _analyzer.analyze(text);

      if (!mounted) return;
      setState(() {
        _extractedText = text;
        _result = result;
      });

      // Best-effort history save. Truncate the extracted text so the
      // history row stays a hint, not a full transcript.
      try {
        final preview = text.length > 200
            ? text.substring(0, 200)
            : text;
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
      } catch (_) {
        // ignored
      }
    } catch (e, st) {
      if (!mounted) return;
      debugPrint('[ScreenshotScanner] OCR failed: $e');
      debugPrintStack(stackTrace: st, maxFrames: 4);
      _showMessage(_tr('screenshotScanner.errorGeneric'));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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

  String _tr(String key) => AppLocaleScope.of(context).tr(key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_tr('screenshotScanner.appBarTitle')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _tr('screenshotScanner.heading'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _tr('screenshotScanner.subheading'),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _buildImagePicker(),
              if (_isProcessing) ...[
                const SizedBox(height: 24),
                const _ProcessingIndicator(),
              ],
              if (_result != null) ...[
                const SizedBox(height: 24),
                _buildResultHeader(_result!),
                if (_result!.aiWasUnavailable) ...[
                  const SizedBox(height: 12),
                  AiUnavailableBanner(
                    text: _tr('result.aiUnavailable'),
                  ),
                ],
              ],
              if (_extractedText.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildExtractedTextPanel(_extractedText),
              ],
              if (_result != null && _result!.reasons.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildReasonsPanel(_result!),
              ],
              if (_result != null &&
                  _result!.recommendations.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildRecommendationsPanel(_result!),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                _buildScanAnother(),
                const SizedBox(height: 8),
                _buildSafetyNotice(),
                const SizedBox(height: 12),
                RiskDisclaimer(text: _tr('result.disclaimer')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // IMAGE PICKER
  // ─────────────────────────────────────────────────────────────

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _isProcessing ? null : _pickImage,
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusXxl),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.2),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _image == null ? _buildPickerPlaceholder() : _buildPreview(),
      ),
    );
  }

  Widget _buildPickerPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _tr('screenshotScanner.pickerTitle'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _tr('screenshotScanner.pickerFormats'),
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          _image!,
          fit: BoxFit.cover,
        ),
        Positioned(
          right: 10,
          top: 10,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              tooltip: _tr('screenshotScanner.scanAnother'),
              onPressed: _isProcessing ? null : _pickImage,
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // RESULT HEADER (score + verdict chip)
  // ─────────────────────────────────────────────────────────────

  Widget _buildResultHeader(ScreenshotAnalysis result) {
    final level = _getRiskLevel(result.score);
    final color = _getColor(level);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIcon(level),
              color: color,
              size: 38,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _getTitle(level),
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${result.score} / 100',
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
            style: const TextStyle(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _buildAiBadge(result.messageResult.usedAi),
          if (result.urlResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
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
                        _tr('screenshotScanner.linksDetected'),
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
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // EXTRACTED TEXT PANEL
  // ─────────────────────────────────────────────────────────────

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
              borderRadius: BorderRadius.circular(12),
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

  // ─────────────────────────────────────────────────────────────
  // WHY? PANEL
  // ─────────────────────────────────────────────────────────────

  Widget _buildReasonsPanel(ScreenshotAnalysis result) {
    final color = _getColor(_getRiskLevel(result.score));
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

  // ─────────────────────────────────────────────────────────────
  // RECOMMENDATIONS PANEL
  // ─────────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────────
  // FOOTER (rescan + safety notice)
  // ─────────────────────────────────────────────────────────────

  Widget _buildScanAnother() {
    return OutlinedButton.icon(
      onPressed: _isProcessing ? null : _pickImage,
      icon: const Icon(Icons.refresh_rounded),
      label: Text(_tr('screenshotScanner.scanAnother')),
    );
  }

  Widget _buildSafetyNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: AppTheme.tintPanel),
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
              _tr('screenshotScanner.safetyNotice'),
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

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  /// Small pill that surfaces whether the verdict came from the local
  /// rule engine or Gemini. Mirrors the URL checker's badge shape.
  Widget _buildAiBadge(bool usedAi) {
    final isAi = usedAi;
    final key = isAi
        ? 'screenshotScanner.aiAssisted'
        : 'screenshotScanner.localOnly';
    final color = isAi ? AppTheme.primary : AppTheme.textSecondary;
    final icon = isAi
        ? Icons.auto_awesome_rounded
        : Icons.verified_user_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
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

  /// Convert a raw 0–100 score to a coarse risk tier.
  ///
  /// Tiers (slightly more conservative than the URL checker so a single
  /// flagged URL can still push a screenshot into "medium"):
  ///   - 80+  : critical
  ///   - 60+  : high
  ///   - 35+  : medium
  ///   - 15+  : low
  ///   - else : safe
  String _getRiskLevel(int score) {
    if (score >= 80) return 'critical';
    if (score >= 60) return 'high';
    if (score >= 35) return 'medium';
    if (score >= 15) return 'low';
    return 'safe';
  }

  Color _getColor(String level) {
    switch (level) {
      case 'safe':
        return AppTheme.success;
      case 'low':
        return AppTheme.secondary;
      case 'medium':
        return AppTheme.warning;
      case 'high':
        return AppTheme.riskHigh;
      case 'critical':
        return AppTheme.danger;
    }
    return AppTheme.textSecondary;
  }

  IconData _getIcon(String level) {
    switch (level) {
      case 'safe':
        return Icons.verified_rounded;
      case 'low':
        return Icons.shield_outlined;
      case 'medium':
        return Icons.warning_amber_rounded;
      case 'high':
      case 'critical':
        return Icons.gpp_bad_rounded;
    }
    return Icons.help_outline_rounded;
  }

  String _getTitle(String level) {
    switch (level) {
      case 'safe':
        return _tr('screenshotScanner.titleSafe');
      case 'low':
        return _tr('screenshotScanner.titleLow');
      case 'medium':
        return _tr('screenshotScanner.titleMedium');
      case 'high':
        return _tr('screenshotScanner.titleHigh');
      case 'critical':
        return _tr('screenshotScanner.titleCritical');
    }
    return _tr('screenshotScanner.titleSafe');
  }
}

/// Lightweight "loading" pill used while ML Kit is recognizing text.
class _ProcessingIndicator extends StatelessWidget {
  const _ProcessingIndicator();

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;
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
            t('screenshotScanner.processing'),
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
