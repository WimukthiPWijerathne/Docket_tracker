// lib/utils/captureImage.dart
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../imageDetailsGrabbing/imageDataCollection.dart';

/// Entry point: open camera → capture → go to preview.
/// Use this from your "Add Docket" button: await openDocketCamera(context);
Future<void> openDocketCamera(BuildContext context) async {
  try {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _DocketCameraPage()));
  } catch (e, st) {
    developer.log(
      'openDocketCamera error: $e',
      name: 'DocketCamera',
      stackTrace: st,
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Camera failed: $e')));
  }
}

class _DocketCameraPage extends StatefulWidget {
  const _DocketCameraPage();

  @override
  State<_DocketCameraPage> createState() => _DocketCameraPageState();
}

class _DocketCameraPageState extends State<_DocketCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _isTakingPicture = false;
  // Last overlay frame rect (in logical pixels relative to the preview widget)
  Rect? _lastFrameRect;
  // Logical size of the preview widget when frame was calculated
  Size? _lastPreviewLogicalSize;

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
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized)
      return;

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
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
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _isTakingPicture) return;

    setState(() => _isTakingPicture = true);
    try {
      final rawFile = await ctrl.takePicture();

      if (!mounted) return;

      XFile fileToPreview = rawFile;
      if (_lastFrameRect != null && _lastPreviewLogicalSize != null) {
        final cropped = await _cropCapturedToFrame(
          rawFile.path,
          _lastFrameRect!,
          _lastPreviewLogicalSize!,
        );
        if (cropped != null) fileToPreview = cropped;
      }

      // 👉 Go to preview. Do renaming/compression there.
      // Make sure your ImagePreviewPage accepts: ImagePreviewPage({required XFile capturedFile, String? docketType})
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ImagePreviewPage(capturedFile: fileToPreview),
        ),
      );
    } catch (e, st) {
      developer.log('Capture error: $e', name: 'DocketCamera', stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Capture failed: $e')));
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

                // Simple overlay (optional)
                _DocketFrameOverlay(
                  // increased slightly to give a larger capture area for dockets
                  frameWidth: 340,
                  frameHeight: 480,
                  cornerRadius: 8,
                  borderWidth: 4,
                  borderColor: Colors.white,
                  overlayOpacity: 0.7,
                  onFrameRect: (rect, logicalSize) {
                    _lastFrameRect = rect;
                    _lastPreviewLogicalSize = logicalSize;
                  },
                ),

                // Shutter + hint
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
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Close
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

/// Overlay that darkens outside a rounded rect "frame"
class _DocketFrameOverlay extends StatelessWidget {
  final double frameWidth;
  final double frameHeight;
  final double cornerRadius;
  final double borderWidth;
  final Color borderColor;
  final double overlayOpacity;
  final void Function(Rect frameRect, Size logicalSize)? onFrameRect;

  const _DocketFrameOverlay({
    required this.frameWidth,
    required this.frameHeight,
    this.cornerRadius = 8,
    this.borderWidth = 3,
    this.borderColor = Colors.black,
    this.overlayOpacity = 0.5,
    this.onFrameRect,
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
          // notify caller about frame position & preview logical size
          if (onFrameRect != null) {
            try {
              onFrameRect!(
                frameRect,
                Size(constraints.maxWidth, constraints.maxHeight),
              );
            } catch (_) {}
          }
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
    final rrect = RRect.fromRectAndRadius(
      frameRect,
      Radius.circular(cornerRadius),
    );

    // Darken outside the frame
    final overlayPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rrect);

    final overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(overlayPath, overlayPaint);

    // Border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _DarkenOutsidePainter old) {
    return frameRect != old.frameRect ||
        cornerRadius != old.cornerRadius ||
        borderWidth != old.borderWidth ||
        borderColor != old.borderColor ||
        overlayColor != old.overlayColor;
  }
}

/// Crop the captured image file to the provided [frameRect] which is expressed
/// in logical pixels relative to the preview widget size [previewLogicalSize].
/// Returns an [XFile] pointing to a temporary JPEG containing the cropped area,
/// or null on failure.
Future<XFile?> _cropCapturedToFrame(
  String capturedPath,
  Rect frameRect,
  Size previewLogicalSize,
) async {
  try {
    final bytes = await File(capturedPath).readAsBytes();

    // Decode image to get actual pixel size
    final codec = await ui.instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    final ui.Image srcImage = frameInfo.image;
    final int srcW = srcImage.width;
    final int srcH = srcImage.height;

    // Map logical preview coords -> image pixel coords
    final double scaleX = srcW / previewLogicalSize.width;
    final double scaleY = srcH / previewLogicalSize.height;

    final int srcLeft = (frameRect.left * scaleX).clamp(0, srcW - 1).toInt();
    final int srcTop = (frameRect.top * scaleY).clamp(0, srcH - 1).toInt();
    final int srcWidth = (frameRect.width * scaleX)
        .clamp(0, srcW - srcLeft)
        .toInt();
    final int srcHeight = (frameRect.height * scaleY)
        .clamp(0, srcH - srcTop)
        .toInt();

    // Draw the cropped region into a new image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();
    final srcRect = Rect.fromLTWH(
      srcLeft.toDouble(),
      srcTop.toDouble(),
      srcWidth.toDouble(),
      srcHeight.toDouble(),
    );
    final dstRect = Rect.fromLTWH(
      0,
      0,
      srcWidth.toDouble(),
      srcHeight.toDouble(),
    );
    canvas.drawImageRect(srcImage, srcRect, dstRect, paint);
    final picture = recorder.endRecording();
    final ui.Image cropped = await picture.toImage(srcWidth, srcHeight);

    final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    final pngBytes = byteData.buffer.asUint8List();

    // Compress PNG to JPEG to reduce size using flutter_image_compress
    final tempDir = await getTemporaryDirectory();
    final outPath = p.join(
      tempDir.path,
      'docket_cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final compressed = await FlutterImageCompress.compressWithList(
      pngBytes,
      format: CompressFormat.jpeg,
      quality: 85,
    );
    final outFile = File(outPath);
    await outFile.writeAsBytes(compressed);
    return XFile(outFile.path);
  } catch (e, st) {
    developer.log(
      'cropCapturedToFrame error: $e',
      name: 'DocketCamera',
      stackTrace: st,
    );
    return null;
  }
}

//v1
// import 'dart:developer' as developer;
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:flutter_image_compress/flutter_image_compress.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:camera/camera.dart';
// import '../../../utils/file_helper.dart';
// import '../imageDataCollection.dart';
//
// /// Docket type → abbreviation mapping
// final Map<String, String> docketTypeMap = {
//   "Service line maintanance": "SLM",
//   "Meter testing": "MT",
//   "Estimate": "Est",
//   "Per visit": "PV",
//   "Pole disconnection": "PD",
//   "Material remove": "MR",
//   "Meter replacement only": "MRO",
//   "Visit with Contractor": "VC",
//   "Pole top maintanance": "PTM",
// };
//
// /// Opens the camera, compresses the image, and saves it with a renamed file.
// /// Returns the compressed [File], or null if cancelled/error.
// Future<File?> openCameraForDocket(String docketType) async {
//   developer.log(
//     'Opening camera for docket type: $docketType',
//     name: 'DocketCamera',
//   );
//
//   final ImagePicker imagePicker = ImagePicker();
//
//   try {
//     final XFile? captured = await imagePicker.pickImage(
//       source: ImageSource.camera,
//     );
//
//     if (captured == null) {
//       developer.log('User cancelled camera', name: 'DocketCamera');
//       return null;
//     }
//
//     // Get abbreviation for docket type
//     final abbr = docketTypeMap[docketType] ?? "UNK";
//
//     // Generate timestamped filename
//     final now = DateTime.now();
//     final formattedDate =
//         "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_"
//         "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
//     final newFileName = "${abbr}_$formattedDate.jpg";
//
//     // Get app storage directory
//     final folderPath = await getAppStoragePath();
//     final targetPath = "$folderPath/$newFileName";
//
//     // Compress and save the image
//     final XFile? compressedXFile =
//         await FlutterImageCompress.compressAndGetFile(
//           captured.path,
//           targetPath,
//           quality: 20, // Adjust quality between 0-100
//         );
//
//     if (compressedXFile != null) {
//       final file = File(compressedXFile.path);
//       if (file.existsSync()) {
//         developer.log("Compressed & saved: ${file.path}", name: "DocketCamera");
//         return file;
//       } else {
//         developer.log("File check failed: does not exist at ${file.path}", name: "DocketCamera");
//         return null;
//       }
//     } else {
//       developer.log("Compression failed", name: "DocketCamera");
//       return null;
//     }
//   } catch (error, stackTrace) {
//     developer.log(
//       'Error capturing/compressing image: $error',
//       name: 'DocketCamera',
//       stackTrace: stackTrace,
//     );
//     return null;
//   }
// }
//
// /// Opens a custom camera page with overlay and returns captured, compressed file.
// Future<XFile?> openCustomCameraForDocket(
//   BuildContext context, {
//   required String docketType,
// }) async {
//   try {
//     final XFile? result = await Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (_) => _DocketCameraPage(docketType: docketType),
//       ),
//     );
//     return result;
//   } catch (e, st) {
//     developer.log(
//       'Error opening custom camera: $e',
//       name: 'DocketCamera',
//       stackTrace: st,
//     );
//     return null;
//   }
// }
//
// class _DocketCameraPage extends StatefulWidget {
//   final String docketType;
//   const _DocketCameraPage({required this.docketType});
//
//   @override
//   State<_DocketCameraPage> createState() => _DocketCameraPageState();
// }
//
// class _DocketCameraPageState extends State<_DocketCameraPage>
//     with WidgetsBindingObserver {
//   CameraController? _controller;
//   Future<void>? _initFuture;
//   bool _isTakingPicture = false;
//
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _initFuture = _initializeCamera();
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _controller?.dispose();
//     super.dispose();
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     final CameraController? cameraController = _controller;
//     if (cameraController == null || !cameraController.value.isInitialized) {
//       return;
//     }
//     if (state == AppLifecycleState.inactive) {
//       cameraController.dispose();
//     } else if (state == AppLifecycleState.resumed) {
//       _initializeCamera();
//     }
//   }
//
//   Future<void> _initializeCamera() async {
//     try {
//       final List<CameraDescription> cameras = await availableCameras();
//       final CameraDescription backCamera = cameras.firstWhere(
//         (c) => c.lensDirection == CameraLensDirection.back,
//         orElse: () => cameras.first,
//       );
//       final CameraController controller = CameraController(
//         backCamera,
//         ResolutionPreset.high,
//         enableAudio: false,
//       );
//       _controller = controller;
//       await controller.initialize();
//       if (mounted) setState(() {});
//     } catch (e, st) {
//       developer.log(
//         'Camera init error: $e',
//         name: 'DocketCamera',
//         stackTrace: st,
//       );
//       rethrow;
//     }
//   }
//
//   Future<void> _onCapturePressed() async {
//     if (_controller == null || !_controller!.value.isInitialized) return;
//     if (_isTakingPicture) return;
//     setState(() => _isTakingPicture = true);
//     try {
//       final XFile rawFile = await _controller!.takePicture();
//
//       if (!mounted) return;
//       // Navigate to preview page with the captured XFile, without saving yet
//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute(
//           builder: (context) => ImagePreviewPage(
//             capturedFile: rawFile,
//             docketType: widget.docketType,
//           ),
//         ),
//       );
//     } catch (e, st) {
//       developer.log('Capture error: $e', name: 'DocketCamera', stackTrace: st);
//     } finally {
//       if (mounted) setState(() => _isTakingPicture = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: SafeArea(
//         child: FutureBuilder<void>(
//           future: _initFuture,
//           builder: (context, snapshot) {
//             if (snapshot.connectionState != ConnectionState.done ||
//                 _controller == null ||
//                 !_controller!.value.isInitialized) {
//               return const Center(child: CircularProgressIndicator());
//             }
//             return Stack(
//               fit: StackFit.expand,
//               children: [
//                 CameraPreview(_controller!),
//                 const _DocketFrameOverlay(
//                   frameWidth: 300,
//                   frameHeight: 400,
//                   cornerRadius: 8,
//                   borderWidth: 4,
//                   borderColor: Colors.white,
//                   overlayOpacity: 0.7,
//                 ),
//                 Positioned(
//                   left: 0,
//                   right: 0,
//                   bottom: 24,
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       const Text(
//                         'Place docket inside the frame',
//                         style: TextStyle(color: Colors.white, fontSize: 16),
//                         textAlign: TextAlign.center,
//                       ),
//                       const SizedBox(height: 16),
//                       GestureDetector(
//                         onTap: _onCapturePressed,
//                         child: Container(
//                           width: 68,
//                           height: 68,
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             shape: BoxShape.circle,
//                           ),
//                           child: Container(
//                             margin: const EdgeInsets.all(6),
//                             decoration: BoxDecoration(
//                               color: Colors.black,
//                               shape: BoxShape.circle,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 Positioned(
//                   left: 8,
//                   top: 8,
//                   child: IconButton(
//                     icon: const Icon(Icons.close, color: Colors.white),
//                     onPressed: () => Navigator.of(context).pop(),
//                   ),
//                 ),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
//
// /// Modular overlay that only highlights, does not block the preview.
// class _DocketFrameOverlay extends StatelessWidget {
//   final double frameWidth;
//   final double frameHeight;
//   final double cornerRadius;
//   final double borderWidth;
//   final Color borderColor;
//   final double overlayOpacity;
//
//   const _DocketFrameOverlay({
//     required this.frameWidth,
//     required this.frameHeight,
//     this.cornerRadius = 8,
//     this.borderWidth = 3,
//     this.borderColor = Colors.black,
//     this.overlayOpacity = 0.5,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return IgnorePointer(
//       child: LayoutBuilder(
//         builder: (context, constraints) {
//           final Rect frameRect = Rect.fromLTWH(
//             (constraints.maxWidth - frameWidth) / 2,
//             (constraints.maxHeight - frameHeight) / 2,
//             frameWidth,
//             frameHeight,
//           );
//
//           return SizedBox.expand(
//             child: CustomPaint(
//               painter: _DarkenOutsidePainter(
//                 frameRect: frameRect,
//                 cornerRadius: cornerRadius,
//                 borderWidth: borderWidth,
//                 borderColor: borderColor,
//                 overlayColor: Colors.black.withOpacity(overlayOpacity),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
//
// class _DarkenOutsidePainter extends CustomPainter {
//   final Rect frameRect;
//   final double cornerRadius;
//   final double borderWidth;
//   final Color borderColor;
//   final Color overlayColor;
//
//   _DarkenOutsidePainter({
//     required this.frameRect,
//     required this.cornerRadius,
//     required this.borderWidth,
//     required this.borderColor,
//     required this.overlayColor,
//   });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final RRect rrect = RRect.fromRectAndRadius(
//       frameRect,
//       Radius.circular(cornerRadius),
//     );
//
//     // Darken outside the frame using even-odd path (no blend modes)
//     final Path overlayPath = Path()
//       ..fillType = PathFillType.evenOdd
//       ..addRect(Offset.zero & size)
//       ..addRRect(rrect);
//     final Paint overlayPaint = Paint()
//       ..color = overlayColor
//       ..style = PaintingStyle.fill;
//     canvas.drawPath(overlayPath, overlayPaint);
//
//     // Draw the frame border on top
//     final Paint borderPaint = Paint()
//       ..color = borderColor
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = borderWidth;
//     canvas.drawRRect(rrect, borderPaint);
//   }
//
//   @override
//   bool shouldRepaint(covariant _DarkenOutsidePainter oldDelegate) {
//     return frameRect != oldDelegate.frameRect ||
//         cornerRadius != oldDelegate.cornerRadius ||
//         borderWidth != oldDelegate.borderWidth ||
//         borderColor != oldDelegate.borderColor ||
//         overlayColor != oldDelegate.overlayColor;
//   }
// }
