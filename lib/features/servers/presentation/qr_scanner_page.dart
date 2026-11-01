import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../../../theme/app_theme.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/motion.dart';

/// Full-screen camera that pops with the first QR code's text. Always dark,
/// like the system camera, regardless of the app theme.
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  var _done = false;
  var _running = false;

  /// Set when the camera can't start; replaces the frame and hint.
  String? _error;

  static const _frameSize = 240.0;

  void _onCamera(CameraController? controller, Exception? error) {
    if (!mounted) return;
    setState(() {
      if (error == null) {
        _running = controller != null;
        return;
      }
      final denied =
          error is CameraException && error.code.startsWith('CameraAccess');
      _error = denied
          ? context.l10n.cameraDenied
          : context.l10n.cameraUnavailable(
              error is CameraException
                  ? error.description ?? error.code
                  : error.toString(),
            );
    });
  }

  void _onScan(Code code) {
    final value = code.text;
    if (value == null || _done) return;
    _done = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(context.l10n.scanQrTitle),
        titleTextStyle: text.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ReaderWidget(
            onScan: _onScan,
            onControllerCreated: _onCamera,
            codeFormat: Format.qrCode,
            showScannerOverlay: false,
            showFlashlight: false,
            showToggleCamera: false,
            showGallery: false,
            scanDelay: const Duration(milliseconds: 300),
            loading: const ColoredBox(color: Colors.black),
          ),
          // Frame and hint only while the camera is live.
          Builder(
            builder: (context) {
              if (_error case final error?) {
                return _Message(
                  icon: Icons.no_photography_outlined,
                  text: error,
                );
              }
              if (!_running) {
                return _Message(
                  icon: Icons.photo_camera_outlined,
                  text: context.l10n.startingCamera,
                );
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  IgnorePointer(
                    child: Center(
                      // Fades and settles in once the camera is live.
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1.08, end: 1),
                        duration: AppMotion.slow,
                        curve: AppMotion.standard,
                        builder: (context, scale, child) => Opacity(
                          opacity: ((1.08 - scale) / 0.08).clamp(0.0, 1.0),
                          child: Transform.scale(scale: scale, child: child),
                        ),
                        child: const CustomPaint(
                          size: Size.square(_frameSize),
                          painter: _CornersPainter(),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.xxl,
                    right: AppSpacing.xxl,
                    bottom:
                        MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: AppRadius.mdAll,
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: ColoredBox(
                            color: Colors.black38,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md,
                              ),
                              child: Text(
                                context.l10n.pointCamera,
                                textAlign: TextAlign.center,
                                style: text.bodyMedium?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 40),
            const SizedBox(height: AppSpacing.lg),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four rounded corner brackets, like the system camera's code finder.
class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 36.0;
    const r = AppRadius.lg;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    for (final (x, y, sx, sy) in [
      (0.0, 0.0, 1.0, 1.0),
      (w, 0.0, -1.0, 1.0),
      (0.0, h, 1.0, -1.0),
      (w, h, -1.0, -1.0),
    ]) {
      final path = Path()
        ..moveTo(x, y + sy * arm)
        ..lineTo(x, y + sy * r)
        ..arcToPoint(
          Offset(x + sx * r, y),
          radius: const Radius.circular(r),
          clockwise: sx * sy > 0,
        )
        ..lineTo(x + sx * arm, y);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CornersPainter old) => false;
}
