import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../services/api_service.dart';
import '../../utils/file_helper.dart';


class UploadService {

  /// Compresses and saves image with timestamped filename
  static Future<File?> compressAndSaveImage(
      String originalPath,
      String docketType,
      ) async {
    try {
      // Get abbreviation for docket type
      final docketTypeMap = {
        'Service Line Maintenance': 'SLM',
        'Meter Testing': 'MT',
        'Estimate': 'EST',
        'Per Visit': 'PV',
        'Pole Disconnection': 'PD',
        'Material Remove': 'MR',
        'Meter Replacement Only': 'MRO',
        'Visit with Contractor': 'VC',
        'Pole Top Maintenance': 'PTM',
      };

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
      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        originalPath,
        targetPath,
        quality: 20,
      );

      if (compressedXFile == null) {
        throw Exception('Failed to compress image');
      }

      developer.log(
        'UploadService: Image compressed and saved to ${compressedXFile.path}',
        name: 'UploadService',
      );

      return File(compressedXFile.path);
    } catch (e, stackTrace) {
      developer.log(
        'Error compressing image: $e',
        name: 'UploadService',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Uploads image file to server
  static Future<bool> uploadImageFile(File imageFile, String docketType) async {
    try {
      final fileName = imageFile.path.split('/').last;

      developer.log(
        'UploadService: Uploading file: $fileName',
        name: 'UploadService',
      );

      print('Uploading file: $fileName');
      print('File exists: ${await imageFile.exists()}');
      print('File size: ${await imageFile.length()} bytes');

      // Determine subdirectory based on docket type
      final subdirectoryMap = {
        'Service Line Maintenance': 1,
        'Meter Testing': 2,
        'Estimate': 3,
      };
      final subdirectory = subdirectoryMap[docketType] ?? 4;
      
      final uploadSuccess = await ApiService.uploadDocketImage(
        imageFile,
        fileName,
        subdirectory,
      );

      print('Image upload status: $uploadSuccess');
      return uploadSuccess;

    } catch (e, stackTrace) {
      developer.log(
        'Error uploading image: $e',
        name: 'UploadService',
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}