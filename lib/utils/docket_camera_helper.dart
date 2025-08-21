import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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

    // Get app storage directory (temporary for now)
    final dir = await getTemporaryDirectory();
    final targetPath = "${dir.path}/$newFileName";

    // Compress and save the image
    final XFile? compressedXFile =
        await FlutterImageCompress.compressAndGetFile(
          captured.path,
          targetPath,
          quality: 70, // Adjust quality between 0-100
        );

    if (compressedXFile != null) {
      final file = File(compressedXFile.path);
      developer.log("Compressed & saved: ${file.path}", name: "DocketCamera");
      return file;
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
