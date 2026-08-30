import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/locale/app_locale.dart';
import '../../core/theme/app_theme.dart';
import '../../models/qr_route.dart';
import '../../services/qr_payload_classifier.dart';
import '../message_checker/message_checker_screen.dart';
import '../phone_checker/phone_checker_screen.dart';
import '../url_checker/url_checker_screen.dart';

/// QR Code Checker screen.
///
/// Flow:
///   1. The screen asks for camera permission via `permission_handler`.
///   2. When granted, `MobileScanner` opens a full-bleed camera
///      preview with an overlay frame.
///   3. On the first successful QR detection, [QrPayloadClassifier]
///      runs against the decoded string. The result drives the
///      destination:
///        - `QrRoute.url`     → [UrlCheckerScreen] (pre-filled)
///        - `QrRoute.phone`   → [PhoneCheckerScreen] (pre-filled)
///        - `QrRoute.text`    → [MessageCheckerScreen] (pre-filled)
///   4. The destination is pushed on top of the QR screen so the
///      back button takes the user home if the scan was wrong.
///
/// Quota model: the QR scan itself is **free** — the QR screen does
/// not call `subscription.recordScan()`. The destination checker
/// (URL / phone / message) decrements its own counter when the user
/// taps the check button, mirroring the existing per-check quota.
///
/// "Enter QR text manually" fallback: visible at every stage so
/// users on cameras-blocked devices (Chromebooks, kiosks, or any
/// device where the OS denies camera access) can still paste a
/// QR string they typed or copied.
class QrCheckerScreen extends StatefulWidget {
  const QrCheckerScreen({super.key, this.skipAutoPermission = false});

  /// When `true`, the screen skips the automatic camera-permission
  /// check that normally runs from `initState`. Used by smoke tests
  /// that want to render the idle UI without depending on
  /// `permission_handler`'s platform-channel plumbing.
  ///
  /// Production callers should always leave this as `false` so the
  /// user is prompted for camera access as soon as the screen opens.
  final bool skipAutoPermission;

  @override
  State<QrCheckerScreen> createState() => _QrCheckerScreenState();
}

class _QrCheckerScreenState extends State<QrCheckerScreen> {
  /// Pure-Dart classifier. Cheap to construct; one per screen
  /// lifetime is fine.
  static const _classifier = QrPayloadClassifier();

  /// Stages drive the rendered UI without any extra state plumbing.
  /// `idle` is the very first build before the permission check
  /// has completed; everything else is post-permission.
  _Stage _stage = _Stage.idle;
  bool _permanentlyDenied = false;
  String? _scannedPreview;

  /// `MobileScannerController` is constructed lazily in [_startCamera]
  /// and disposed in [dispose]. We keep a nullable field so we can
  /// tell whether the camera was started (and therefore whether to
  /// `stop()` it on screen exit).
  MobileScannerController? _controller;

  @override
  void initState() {
    super.initState();
    // Skip the permission flow when the caller asked for it
    // (test-only escape hatch). Production callers always leave
    // it `false`, so the screen kicks off the permission check
    // and updates `_stage` once it resolves. We don't await so
    // the first frame renders immediately; the OS-level
    // permission dialog (if needed) takes a moment to appear
    // and we don't want to block the UI on it.
    if (!widget.skipAutoPermission) {
      _checkPermissionAndStart();
    }
  }

  @override
  void dispose() {
    // `stop()` before `dispose()` releases the camera so the next
    // screen (or the OS) can claim it immediately.
    _controller?.stop();
    _controller?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // PERMISSION FLOW
  // ─────────────────────────────────────────

  Future<void> _checkPermissionAndStart() async {
    // `permission_handler` returns one of: granted / denied /
    // permanentlyDenied / restricted. We treat permanentlyDenied and
    // restricted identically — the UI just shows "Open settings" with
    // an explicit deep link.
    final status = await Permission.camera.status;

    if (status.isGranted) {
      _startCamera();
      return;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.permissionDenied;
        _permanentlyDenied = true;
      });
      return;
    }

    // First-time or soft-denial: actually request and then re-check.
    final result = await Permission.camera.request();
    if (!mounted) return;

    if (result.isGranted) {
      _startCamera();
    } else if (result.isPermanentlyDenied || result.isRestricted) {
      setState(() {
        _stage = _Stage.permissionDenied;
        _permanentlyDenied = true;
      });
    } else {
      setState(() => _stage = _Stage.permissionDenied);
    }
  }

  void _startCamera() {
    setState(() => _stage = _Stage.scanning);
    _controller = MobileScannerController(
      // Restrict to QR for v1 — a wider format set slows detection
      // and we have no use for barcodes / Data Matrix / PDF417.
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 1000,
    );
  }

  // ─────────────────────────────────────────
  // DETECTION
  // ─────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    // Guard against multiple rapid detections firing while we're
    // still pushing the destination screen. `MobileScanner` can emit
    // several `BarcodeCapture`s per second once a code is in frame.
    if (_stage != _Stage.scanning) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    final classification = _classifier.classify(raw);

    // Show a brief "QR detected — checking…" flash so the user gets
    // visual confirmation before the destination takes over.
    setState(() {
      _stage = _Stage.detected;
      _scannedPreview = classification.extracted.isNotEmpty
          ? classification.extracted
          : classification.raw;
    });

    // Give the flash ~250 ms to render before we push. Without this
    // the navigation push happens inside the same frame and the
    // user just sees the destination appear with no acknowledgement
    // that the QR was read.
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      _routeToDestination(classification);
    });
  }

  void _routeToDestination(QrClassification classification) {
    final payload = classification.extracted;
    final Widget destination;
    switch (classification.route) {
      case QrRoute.url:
        destination = UrlCheckerScreen(initialValue: payload);
        break;
      case QrRoute.phone:
        destination = PhoneCheckerScreen(initialValue: payload);
        break;
      case QrRoute.text:
        destination = MessageCheckerScreen(initialValue: payload);
        break;
    }

    // Push the destination on top of the QR screen — the back button
    // from the destination returns to this screen so the user can
    // re-scan if the result looked wrong. We don't replace the route
    // because that would lose the back-stack context (the QR screen
    // is reached from the Check tab and should remain reachable).
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => destination),
    );

    // After the destination is on top, reset this screen's stage
    // back to `scanning` so when the user comes back they can scan
    // again without re-grabbing permission.
    setState(() {
      _stage = _Stage.scanning;
      _scannedPreview = null;
    });
  }

  // ─────────────────────────────────────────
  // MANUAL ENTRY (fallback for no-camera devices or paste-a-QR)
  // ─────────────────────────────────────────

  Future<void> _openManualEntry() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _ManualEntryDialog(tr: AppLocaleScope.of(ctx).tr),
    );
    if (result == null || result.trim().isEmpty || !mounted) return;

    final classification = _classifier.classify(result);
    if (classification.route == QrRoute.text &&
        classification.extracted.isEmpty) {
      _showMessage(AppLocaleScope.of(context).tr('qrChecker.unsupportedContent'));
      // Still route to the message checker so the user can decide.
    }
    _routeToDestination(classification);
  }

  // ─────────────────────────────────────────
  // UI BUILD
  // ─────────────────────────────────────────

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocaleScope.of(context).tr;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(t('qrChecker.appBarTitle')),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.headerGradient),
        ),
      ),
      body: SafeArea(child: _buildBody(t)),
    );
  }

  Widget _buildBody(String Function(String) t) {
    switch (_stage) {
      case _Stage.idle:
        return _PermissionPrompt(
          title: t('qrChecker.allowCamera'),
          body: t('qrChecker.subheading'),
          ctaLabel: t('qrChecker.allowCamera'),
          onCta: _checkPermissionAndStart,
          onManual: _openManualEntry,
          manualLabel: t('qrChecker.enterManually'),
        );
      case _Stage.permissionDenied:
        return _PermissionDeniedView(
          permanentlyDenied: _permanentlyDenied,
          body: _permanentlyDenied
              ? t('qrChecker.permissionPermanentlyDenied')
              : t('qrChecker.permissionDenied'),
          ctaLabel: t('qrChecker.openSettings'),
          onCta: () => openAppSettings(),
          onManual: _openManualEntry,
          manualLabel: t('qrChecker.enterManually'),
        );
      case _Stage.scanning:
      case _Stage.detected:
        return _ScannerView(
          controller: _controller!,
          detected: _stage == _Stage.detected,
          detectedPreview: _scannedPreview,
          onDetect: _onDetect,
          scanningHint: t('qrChecker.scanningHint'),
          detectedLabel: t('qrChecker.detected'),
          onManual: _openManualEntry,
          manualLabel: t('qrChecker.enterManually'),
        );
    }
  }
}

/// Stages drive the body widget. Kept as a private enum so the
/// outer state shape stays self-documenting.
enum _Stage { idle, permissionDenied, scanning, detected }

// ───────────────────────────────────────────────────────────────────
// Permission states
// ───────────────────────────────────────────────────────────────────

/// Initial / pre-permission state. Centered CTA + manual-entry
/// fallback. Visually identical to the permission-denied view but
/// without the "settings" red flag — the user hasn't refused yet.
class _PermissionPrompt extends StatelessWidget {
  const _PermissionPrompt({
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
    required this.onManual,
    required this.manualLabel,
  });

  final String title;
  final String body;
  final String ctaLabel;
  final VoidCallback onCta;
  final VoidCallback onManual;
  final String manualLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: AppTheme.tintSurface),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              size: 48,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          _PrimaryCtaButton(label: ctaLabel, onPressed: onCta),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onManual,
            child: Text(
              manualLabel,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Permission denied / permanently denied view. Visually mirrors the
/// prompt view but swaps the primary CTA for "Open settings" (which
/// deep-links via `openAppSettings()` from permission_handler).
class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.permanentlyDenied,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
    required this.onManual,
    required this.manualLabel,
  });

  final bool permanentlyDenied;
  final String body;
  final String ctaLabel;
  final VoidCallback onCta;
  final VoidCallback onManual;
  final String manualLabel;

  @override
  Widget build(BuildContext context) {
    final accent =
        permanentlyDenied ? AppTheme.danger : AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: AppTheme.tintSurface),
              shape: BoxShape.circle,
            ),
            child: Icon(
              permanentlyDenied
                  ? Icons.no_photography_outlined
                  : Icons.lock_outline_rounded,
              size: 48,
              color: accent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textPrimary,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          _PrimaryCtaButton(
            label: ctaLabel,
            onPressed: onCta,
            color: accent,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onManual,
            child: Text(
              manualLabel,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Live camera view
// ───────────────────────────────────────────────────────────────────

/// Full-bleed camera preview + overlay frame + "Detected" flash.
/// MobileScanner owns the camera lifecycle; we just wrap its
/// controller in our own state to drive the detected/scanning
/// visual transition.
class _ScannerView extends StatelessWidget {
  const _ScannerView({
    required this.controller,
    required this.detected,
    required this.detectedPreview,
    required this.onDetect,
    required this.scanningHint,
    required this.detectedLabel,
    required this.onManual,
    required this.manualLabel,
  });

  final MobileScannerController controller;
  final bool detected;
  final String? detectedPreview;
  final void Function(BarcodeCapture) onDetect;
  final String scanningHint;
  final String detectedLabel;
  final VoidCallback onManual;
  final String manualLabel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camera preview. `fit: BoxFit.cover` so the camera fills
        // the entire available space — the overlay frame is rendered
        // on top, not inside the camera view, so we don't depend on
        // the camera surface knowing about UI chrome.
        Positioned.fill(
          child: MobileScanner(
            controller: controller,
            onDetect: onDetect,
            fit: BoxFit.cover,
            // mobile_scanner v5+ errorBuilder signature is
            // `(BuildContext, MobileScannerException, Widget?)`.
            // We ignore both the error and the (optional) fallback
            // child — our _CameraErrorView handles the recovery UI
            // directly and the manual-entry affordance stays in
            // scope via the banner overlay below.
            errorBuilder: (_, error, child) => _CameraErrorView(
              onManual: onManual,
              manualLabel: manualLabel,
            ),
          ),
        ),
        // Subtle dim layer to make the overlay frame and hint text
        // pop without obscuring the QR code itself. The frame is a
        // cut-out in this dim layer — see the [CustomPaint] below.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _ScannerOverlayPainter()),
          ),
        ),
        // Bottom hint / detected banner. Switches between the
        // steady-state "Align the QR code" hint and the brief
        // "QR detected — checking…" flash once a code is decoded.
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _BottomBanner(
                detected: detected,
                detectedPreview: detectedPreview,
                scanningHint: scanningHint,
                detectedLabel: detectedLabel,
                onManual: onManual,
                manualLabel: manualLabel,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Camera-failure view. Reached when the OS denies camera access
/// at a level below what permission_handler can detect (e.g. the
/// user installed the app on a Chromebook with no camera, or the
/// hardware is in use by another app). Falls back to manual entry.
class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.onManual, required this.manualLabel});

  final VoidCallback onManual;
  final String manualLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: AppTheme.tintSurface),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.videocam_off_rounded,
              size: 40,
              color: AppTheme.danger,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onManual,
            child: Text(
              manualLabel,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a dim layer with a rounded-rectangle cut-out in the
/// middle — the classic "viewfinder" UI. Hand-rolled rather than
/// using `BackdropFilter` because backdrop blur is expensive on
/// low-end devices and the static dim reads just as well.
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final shorterSide = size.width < size.height ? size.width : size.height;
    final frameSize = shorterSide * 0.7;
    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameSize,
      height: frameSize,
    );

    final dimPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final framePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // Dim the entire screen, then punch a hole where the frame is.
    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()
      ..addRRect(RRect.fromRectAndRadius(frameRect, const Radius.circular(24)));
    final dimmed = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(dimmed, dimPaint);

    // Frame outline.
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(24)),
      framePaint,
    );

    // Four corner brackets to read as "aim here" rather than a
    // passive rectangle. The bracket length is a runtime double
    // (kept as a local so we can tune it later), so the `Offset`s
    // are non-const — Dart will JIT them once per paint pass.
    final cornerLen = 24.0;
    final cornerPaint = Paint()
      ..color = AppTheme.primary
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final tl = frameRect.topLeft;
    final tr = frameRect.topRight;
    final bl = frameRect.bottomLeft;
    final br = frameRect.bottomRight;
    canvas.drawLine(tl, tl + Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(tl, tl + Offset(0, cornerLen), cornerPaint);
    canvas.drawLine(tr, tr + Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(tr, tr + Offset(0, cornerLen), cornerPaint);
    canvas.drawLine(bl, bl + Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(bl, bl + Offset(0, -cornerLen), cornerPaint);
    canvas.drawLine(br, br + Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(br, br + Offset(0, -cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Bottom banner that toggles between "scanning…" and "QR detected".
/// The detected state shows the raw payload preview so the user
/// can sanity-check what was read before the destination screen
/// appears. Tappable to launch the manual-entry dialog — the
/// "Enter manually" affordance stays reachable at every stage.
class _BottomBanner extends StatelessWidget {
  const _BottomBanner({
    required this.detected,
    required this.detectedPreview,
    required this.scanningHint,
    required this.detectedLabel,
    required this.onManual,
    required this.manualLabel,
  });

  final bool detected;
  final String? detectedPreview;
  final String scanningHint;
  final String detectedLabel;
  final VoidCallback onManual;
  final String manualLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: detected
                ? AppTheme.success
                : Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (detected)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              Flexible(
                child: Text(
                  detected
                      ? detectedLabel
                      : scanningHint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Manual-entry link sits below the banner so the user can
        // reach it at any stage without covering the camera view.
        TextButton.icon(
          onPressed: onManual,
          icon: const Icon(
            Icons.keyboard_alt_outlined,
            color: Colors.white,
            size: 16,
          ),
          label: Text(
            manualLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          style: TextButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.45),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Manual entry dialog
// ───────────────────────────────────────────────────────────────────

/// Dialog shown when the user taps "Enter QR text manually". Returns
/// the entered string via Navigator.pop, or null if cancelled.
class _ManualEntryDialog extends StatefulWidget {
  const _ManualEntryDialog({required this.tr});

  final String Function(String) tr;

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tr('qrChecker.enterManually')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tr('qrChecker.enterManuallyHint'),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tr('qrChecker.enterManuallyCancel')),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.tr('qrChecker.enterManuallyCta')),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Reusable bits
// ───────────────────────────────────────────────────────────────────

/// Full-width primary CTA button. Same brand-gradient pattern as
/// the Login / SignUp CTAs so the visual language of "primary
/// action on a card" stays consistent across the app.
class _PrimaryCtaButton extends StatelessWidget {
  const _PrimaryCtaButton({
    required this.label,
    required this.onPressed,
    this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final gradient = color != null
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color!, color!],
          )
        : AppTheme.headerGradient;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        boxShadow: [
          BoxShadow(
            color: (color ?? AppTheme.primary)
                .withValues(alpha: AppTheme.tintBorderStrong),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
