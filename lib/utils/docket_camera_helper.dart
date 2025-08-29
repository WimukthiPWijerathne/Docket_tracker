import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'file_helper.dart';
import '../pages/image_preview_page.dart';

/// Docket type → abbreviation mapping
final Map<String, String> docketTypeMap = {
  "Service line maintanance": "SLM",
  "Meter testing": "MT",
  "Estimate": "Est",
  "Per visit": "PV",
  "Pole disconnection": "PD",
  "Material remove": "MR",
  "Meter replacement only": "MRO",
  "Visit with Contractor": "VC",
  "Pole top maintanance": "PTM",
};

/// Opens the camera, compresses the image, and saves it with a renamed file.
/// Returns the compressed [File], or null if cancelled/error.
Future<File?> openCameraForDocket(String docketType) async {
  developer.log(
    'Opening camera for docket type: $docketType',
    name: 'DocketCamera',
  );

  final ImagePicker imagePicker = ImagePicker();

  try {
    final XFile? captured = await imagePicker.pickImage(
      source: ImageSource.camera,
    );

    if (captured == null) {
      developer.log('User cancelled camera', name: 'DocketCamera');
      return null;
    }

    // Get abbreviation for docket type
    final abbr = docketTypeMap[docketType] ?? "UNK";

    // Generate timestamped filename
    final now = DateTime.now();
    final formattedDate =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_"
        "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
    final newFileName = "${abbr}_$formattedDate.jpg";

    // Get app storage directory
    final folderPath = await getAppStoragePath();
    final targetPath = "$folderPath/$newFileName";

    // Compress and save the image
    final XFile? compressedXFile =
        await FlutterImageCompress.compressAndGetFile(
          captured.path,
          targetPath,
          quality: 20, // Adjust quality between 0-100
        );

    if (compressedXFile != null) {
      final file = File(compressedXFile.path);
      if (file.existsSync()) {
        developer.log("Compressed & saved: ${file.path}", name: "DocketCamera");
        return file;
      } else {
        developer.log("File check failed: does not exist at ${file.path}", name: "DocketCamera");
        return null;
      }
    } else {
      developer.log("Compression failed", name: "DocketCamera");
      return null;
    }
  } catch (error, stackTrace) {
    developer.log(
      'Error capturing/compressing image: $error',
      name: 'DocketCamera',
      stackTrace: stackTrace,
    );
    return null;
  }
}

/// Opens a custom camera page with overlay and returns captured, compressed file.
Future<XFile?> openCustomCameraForDocket(
  BuildContext context, {
  required String docketType,
}) async {
  try {
    final XFile? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DocketCameraPage(docketType: docketType),
      ),
    );
    return result;
  } catch (e, st) {
    developer.log(
      'Error opening custom camera: $e',
      name: 'DocketCamera',
      stackTrace: st,
    );
    return null;
  }
}

class _DocketCameraPage extends StatefulWidget {
  final String docketType;
  const _DocketCameraPage({required this.docketType});

  @override
  State<_DocketCameraPage> createState() => _DocketCameraPageState();
}

class _DocketCameraPageState extends State<_DocketCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _isTakingPicture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      final CameraDescription backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final CameraController controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
      if (mounted) setState(() {});
    } catch (e, st) {
      developer.log(
        'Camera init error: $e',
        name: 'DocketCamera',
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> _onCapturePressed() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isTakingPicture) return;
    setState(() => _isTakingPicture = true);
    try {
      final XFile rawFile = await _controller!.takePicture();

      if (!mounted) return;
      // Navigate to preview page with the captured XFile, without saving yet
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ImagePreviewPage(
            capturedFile: rawFile,
            docketType: widget.docketType,
          ),
        ),
      );
    } catch (e, st) {
      developer.log('Capture error: $e', name: 'DocketCamera', stackTrace: st);
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                _controller == null ||
                !_controller!.value.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                const _DocketFrameOverlay(
                  frameWidth: 300,
                  frameHeight: 400,
                  cornerRadius: 8,
                  borderWidth: 4,
                  borderColor: Colors.white,
                  overlayOpacity: 0.7,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Place docket inside the frame',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _onCapturePressed,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Modular overlay that only highlights, does not block the preview.
class _DocketFrameOverlay extends StatelessWidget {
  final double frameWidth;
  final double frameHeight;
  final double cornerRadius;
  final double borderWidth;
  final Color borderColor;
  final double overlayOpacity;

  const _DocketFrameOverlay({
    required this.frameWidth,
    required this.frameHeight,
    this.cornerRadius = 8,
    this.borderWidth = 3,
    this.borderColor = Colors.black,
    this.overlayOpacity = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Rect frameRect = Rect.fromLTWH(
            (constraints.maxWidth - frameWidth) / 2,
            (constraints.maxHeight - frameHeight) / 2,
            frameWidth,
            frameHeight,
          );

          return SizedBox.expand(
            child: CustomPaint(
              painter: _DarkenOutsidePainter(
                frameRect: frameRect,
                cornerRadius: cornerRadius,
                borderWidth: borderWidth,
                borderColor: borderColor,
                overlayColor: Colors.black.withOpacity(overlayOpacity),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DarkenOutsidePainter extends CustomPainter {
  final Rect frameRect;
  final double cornerRadius;
  final double borderWidth;
  final Color borderColor;
  final Color overlayColor;

  _DarkenOutsidePainter({
    required this.frameRect,
    required this.cornerRadius,
    required this.borderWidth,
    required this.borderColor,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final RRect rrect = RRect.fromRectAndRadius(
      frameRect,
      Radius.circular(cornerRadius),
    );

    // Darken outside the frame using even-odd path (no blend modes)
    final Path overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rrect);
    final Paint overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(overlayPath, overlayPaint);

    // Draw the frame border on top
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _DarkenOutsidePainter oldDelegate) {
    return frameRect != oldDelegate.frameRect ||
        cornerRadius != oldDelegate.cornerRadius ||
        borderWidth != oldDelegate.borderWidth ||
        borderColor != oldDelegate.borderColor ||
        overlayColor != oldDelegate.overlayColor;
  }
}
