import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../../models/WorkPhoto.dart';
import '../../../models/WorkLog.dart';
import '../../../services/api_service.dart';

enum PhotoKind { before, after, extra }

String _kindToStr(PhotoKind k) {
  switch (k) {
    case PhotoKind.before:
      return 'BEFORE';
    case PhotoKind.after:
      return 'AFTER';
    case PhotoKind.extra:
      return 'EXTRA';
  }
}

class WorkLogService {
  // --- API endpoints ---
  static const String baseUrl = 'https://powerprox.sltidc.lk';

  // Work Log endpoints
  static String get getWorkLogUrl => '$baseUrl/GETDocketWorkLog.php';
  static String get postWorkLogUrl => '$baseUrl/POSTDocketWorkLog.php';
  static String get updateWorkLogUrl => '$baseUrl/UPDATEDocketWorkLog.php';

  // Work Photo endpoints
  static String get getWorkPhotosUrl => '$baseUrl/GETDocketWorkPhoto.php';
  static String get postWorkPhotoUrl => '$baseUrl/POSTDocketWorkPhoto.php';
  static String get updateWorkPhotoUrl => '$baseUrl/UPDATEDocketWorkPhoto.php';

  // ==================== NEW WORK LOG API METHODS ====================

  /// Get work logs - GET request
  static Future<List<WorkLog>> getWorkLogs({
    String? assignmentId,
    String? docketId,
    String? employeeNo,
  }) async {
    try {
      String url = getWorkLogUrl;
      Map<String, String> queryParams = {};

      if (assignmentId != null)
        queryParams['assignmentID'] = assignmentId; // Use capital ID
      if (docketId != null)
        queryParams['docketID'] = docketId; // Use capital ID
      if (employeeNo != null) queryParams['employeeNo'] = employeeNo;

      if (queryParams.isNotEmpty) {
        url +=
            '?' +
            queryParams.entries
                .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
                .join('&');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        if (jsonData is List) {
          return jsonData
              .map<WorkLog>((item) => WorkLog.fromJson(item))
              .toList();
        } else if (jsonData is Map<String, dynamic>) {
          return [WorkLog.fromJson(jsonData)];
        }
      }

      throw 'Failed to get work logs: ${response.statusCode} - ${response.body}';
    } catch (e) {
      throw 'Error getting work logs: $e';
    }
  }

  /// Create work log - POST request
  static Future<WorkLog> createWorkLog({
    required String assignmentId,
    required String docketId,
    required String employeeNo,
    String? acknowledgedAt,
    String? attendingAt,
    String? startedAt,
    String? completedAt,
    String? remarks,
  }) async {
    try {
      final requestBody = {
        'assignmentID': assignmentId, // Use capital ID
        'docketID': docketId, // Use capital ID
        'employeeNo': employeeNo,
      };

      if (acknowledgedAt != null)
        requestBody['acknowledgedAt'] = acknowledgedAt;
      if (attendingAt != null) requestBody['attendingAt'] = attendingAt;
      if (startedAt != null) requestBody['startedAt'] = startedAt;
      if (completedAt != null) requestBody['completedAt'] = completedAt;
      if (remarks != null) requestBody['remarks'] = remarks;

      print('DEBUG: Creating work log with URL: $postWorkLogUrl');
      print('DEBUG: Request body: $requestBody');

      final response = await http.post(
        Uri.parse(postWorkLogUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('DEBUG: Create response status: ${response.statusCode}');
      print('DEBUG: Create response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        print('DEBUG: Parsed create response data: $jsonData');

        // Check if the response indicates an error
        if (jsonData is Map<String, dynamic> && jsonData['success'] == false) {
          final errorMessage = jsonData['message'] ?? 'Unknown error';
          print('DEBUG: API returned error: $errorMessage');
          throw 'API Error: $errorMessage';
        }

        // Check if the response has the expected work log data
        if (jsonData is Map<String, dynamic> &&
            (jsonData['id'] == null || jsonData['id'].toString().isEmpty)) {
          print('DEBUG: API returned empty work log data');
          throw 'API Error: No work log ID returned from server';
        }

        final workLog = WorkLog.fromJson(jsonData);
        print('DEBUG: Created WorkLog object: $workLog');
        return workLog;
      }

      throw 'Failed to create work log: ${response.statusCode} - ${response.body}';
    } catch (e) {
      print('DEBUG: Exception in createWorkLog: $e');
      throw 'Error creating work log: $e';
    }
  }

  /// Update work log - PUT/POST request
  static Future<WorkLog> updateWorkLog({
    required String workLogId,
    String? assignmentId,
    String? docketId,
    String? employeeNo,
    String? acknowledgedAt,
    String? attendingAt,
    String? startedAt,
    String? completedAt,
    String? remarks,
  }) async {
    try {
      final requestBody = {'id': workLogId};

      if (assignmentId != null)
        requestBody['assignmentID'] = assignmentId; // Use capital ID
      if (docketId != null)
        requestBody['docketID'] = docketId; // Use capital ID
      if (employeeNo != null) requestBody['employeeNo'] = employeeNo;
      if (acknowledgedAt != null)
        requestBody['acknowledgedAt'] = acknowledgedAt;
      if (attendingAt != null) requestBody['attendingAt'] = attendingAt;
      if (startedAt != null) requestBody['startedAt'] = startedAt;
      if (completedAt != null) requestBody['completedAt'] = completedAt;
      if (remarks != null) requestBody['remarks'] = remarks;

      print('DEBUG: Updating work log with URL: $updateWorkLogUrl');
      print('DEBUG: Request body: $requestBody');

      final response = await http.post(
        Uri.parse(updateWorkLogUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('DEBUG: Parsed response data: $jsonData');
        return WorkLog.fromJson(jsonData);
      }

      throw 'Failed to update work log: ${response.statusCode} - ${response.body}';
    } catch (e) {
      print('DEBUG: Exception in updateWorkLog: $e');
      throw 'Error updating work log: $e';
    }
  }

  // ==================== WORK PHOTO API METHODS ====================

  /// Get work photos - GET request
  static Future<List<WorkPhoto>> getWorkPhotos({
    String? workLogId,
    String? kind,
  }) async {
    try {
      String url = getWorkPhotosUrl;
      Map<String, String> queryParams = {};

      if (workLogId != null) queryParams['workLogId'] = workLogId;
      if (kind != null) queryParams['kind'] = kind;

      if (queryParams.isNotEmpty) {
        url +=
            '?' +
            queryParams.entries
                .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
                .join('&');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        if (jsonData is List) {
          return jsonData
              .map<WorkPhoto>((item) => WorkPhoto.fromJson(item))
              .toList();
        } else if (jsonData is Map<String, dynamic>) {
          return [WorkPhoto.fromJson(jsonData)];
        }
      }

      throw 'Failed to get work photos: ${response.statusCode} - ${response.body}';
    } catch (e) {
      throw 'Error getting work photos: $e';
    }
  }

  /// Generates a proper filename for work photos based on the pattern used in add docket
  static String _generateWorkPhotoFileName({
    required String docketSerial,
    required String kind,
    required int sequence,
  }) {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyyMMdd_HHmmss').format(now);
    final fileName =
        "${docketSerial}_${kind}_${sequence}_$formattedDate"; // Remove .jpg - let ApiService add it
    print('DEBUG: Generated filename (no extension): $fileName');
    return fileName;
  }

  /// Compresses an image file before uploading
  static Future<File?> _compressImage(
    String originalPath,
    String targetPath,
  ) async {
    try {
      final XFile? compressedXFile =
          await FlutterImageCompress.compressAndGetFile(
            originalPath,
            targetPath,
            quality: 80, // Good quality for work photos
          );

      if (compressedXFile != null) {
        final file = File(compressedXFile.path);
        if (await file.exists()) {
          return file;
        }
      }
      return null;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  /// Upload work photo using api_service.dart approach with proper subdirectories
  static Future<WorkPhoto> uploadWorkPhoto({
    required String workLogId,
    required String kind, // BEFORE, AFTER, EXTRA
    required String filePath,
    required String caption,
    required String sequence,
    required String uploadedBy,
  }) async {
    try {
      // Compress the image before uploading
      final tempDir = await getTemporaryDirectory();
      final originalFile = File(filePath);
      final compressedPath =
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final compressedFile = await _compressImage(filePath, compressedPath);
      final fileToUpload = compressedFile ?? originalFile;

      print('DEBUG: Original file size: ${await originalFile.length()} bytes');
      print(
        'DEBUG: Compressed file size: ${await fileToUpload.length()} bytes',
      );

      // Generate proper filename using the established pattern
      final fileName = _generateWorkPhotoFileName(
        docketSerial: workLogId, // Using workLogId as identifier
        kind: kind,
        sequence: int.parse(sequence),
      );

      // Determine subdirectory based on photo kind
      int subdirectory;
      switch (kind.toUpperCase()) {
        case 'BEFORE':
          subdirectory = 1;
          break;
        case 'AFTER':
          subdirectory = 2;
          break;
        case 'EXTRA':
          subdirectory = 3;
          break;
        default:
          subdirectory = 3; // Default to extra
      }

      print(
        'DEBUG: Uploading $kind photo to subdirectory $subdirectory with filename: $fileName',
      );

      // Use ApiService to upload the photo
      final uploadSuccess = await ApiService.uploadDocketImage(
        fileToUpload,
        fileName,
        subdirectory,
      );

      // Clean up compressed file if it was created
      if (compressedFile != null && await compressedFile.exists()) {
        try {
          await compressedFile.delete();
        } catch (e) {
          print('Warning: Could not delete compressed file: $e');
        }
      }

      if (uploadSuccess) {
        print(
          'DEBUG: Photo uploaded successfully to file system using ApiService!',
        );
        print(
          'DEBUG: Access URL: http://124.43.181.243:8000/api/fetch-testdocket-image/$subdirectory/$fileName.jpg',
        );

        // Now save the photo metadata to the database
        final workPhoto = await _saveWorkPhotoToDatabase(
          workLogId: workLogId,
          kind: kind,
          imageName:
              '$fileName.jpg', // ApiService adds .jpg extension, so we save the full name
          caption: caption,
          sequence: sequence,
          uploadedBy: uploadedBy,
        );

        print('DEBUG: Photo metadata saved to database successfully!');
        print('DEBUG: Database Photo ID: ${workPhoto.id}');

        return workPhoto;
      } else {
        throw 'Failed to upload photo using ApiService';
      }
    } catch (e) {
      throw 'Error uploading work photo: $e';
    }
  }

  /// Save work photo metadata to database
  static Future<WorkPhoto> _saveWorkPhotoToDatabase({
    required String workLogId,
    required String kind,
    required String imageName,
    required String caption,
    required String sequence,
    required String uploadedBy,
  }) async {
    try {
      // Format datetime to match database format (MySQL datetime)
      final now = DateTime.now();
      final formattedDateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      final requestBody = {
        'workLogId': workLogId,
        'kind': kind,
        'imageName': imageName,
        'caption': caption,
        'sequence': sequence,
        'uploadedBy': uploadedBy,
        'uploadedAt': formattedDateTime,
        'updatedAt': formattedDateTime,
      };

      print('DEBUG: Sending to database - URL: $postWorkPhotoUrl');
      print('DEBUG: Request body: $requestBody');

      final response = await http.post(
        Uri.parse(postWorkPhotoUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('DEBUG: Database save response status: ${response.statusCode}');
      print('DEBUG: Database save response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);

        // Check if response indicates success
        if (jsonData is Map<String, dynamic>) {
          // If API returns success status
          if (jsonData.containsKey('success') && jsonData['success'] == false) {
            throw 'API Error: ${jsonData['message'] ?? 'Unknown error'}';
          }

          // If response contains the work photo data, return it
          if (jsonData.containsKey('id') || jsonData.containsKey('workLogId')) {
            return WorkPhoto.fromJson(jsonData);
          }

          // If response is just a success confirmation, create a WorkPhoto object
          // with the data we sent (since some APIs just return success without data)
          return WorkPhoto(
            id:
                jsonData['id']?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            workLogId: workLogId,
            kind: kind,
            imageName: imageName,
            caption: caption,
            sequence: sequence,
            uploadedBy: uploadedBy,
            uploadedAt: formattedDateTime,
            updatedAt: formattedDateTime,
          );
        }

        return WorkPhoto.fromJson(jsonData);
      }

      throw 'Failed to save work photo to database: ${response.statusCode} - ${response.body}';
    } catch (e) {
      print('DEBUG: Exception in _saveWorkPhotoToDatabase: $e');
      throw 'Error saving work photo to database: $e';
    }
  }

  /// Update work photo - PUT/POST request
  static Future<WorkPhoto> updateWorkPhoto({
    required String photoId,
    String? workLogId,
    String? kind,
    String? imageName,
    String? caption,
    String? sequence,
    String? uploadedBy,
  }) async {
    try {
      final requestBody = {'id': photoId};

      if (workLogId != null) requestBody['workLogId'] = workLogId;
      if (kind != null) requestBody['kind'] = kind;
      if (imageName != null) requestBody['imageName'] = imageName;
      if (caption != null) requestBody['caption'] = caption;
      if (sequence != null) requestBody['sequence'] = sequence;
      if (uploadedBy != null) requestBody['uploadedBy'] = uploadedBy;

      final response = await http.post(
        Uri.parse(updateWorkPhotoUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return WorkPhoto.fromJson(jsonData);
      }

      throw 'Failed to update work photo: ${response.statusCode} - ${response.body}';
    } catch (e) {
      throw 'Error updating work photo: $e';
    }
  }

  // ==================== DEBUG/TEST METHODS ====================

  /// Test database connection for work photos
  static Future<bool> testDatabaseConnection() async {
    try {
      print('DEBUG: Testing database connection...');
      print('DEBUG: GET URL: $getWorkPhotosUrl');
      print('DEBUG: POST URL: $postWorkPhotoUrl');

      // Try to get existing work photos to test connection
      final response = await http.get(
        Uri.parse(getWorkPhotosUrl),
        headers: {'Content-Type': 'application/json'},
      );

      print('DEBUG: Test connection response status: ${response.statusCode}');
      print('DEBUG: Test connection response body: ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('DEBUG: Database connection test failed: $e');
      return false;
    }
  }

  // ==================== CONVENIENCE METHODS ====================

  /// Get work photos by kind (BEFORE, AFTER, EXTRA)
  static Future<List<WorkPhoto>> getWorkPhotosByKind({
    required String workLogId,
    required PhotoKind kind,
  }) async {
    return getWorkPhotos(workLogId: workLogId, kind: _kindToStr(kind));
  }

  /// Upload work photo using PhotoKind enum
  static Future<WorkPhoto> uploadWorkPhotoWithKind({
    required String workLogId,
    required PhotoKind kind,
    required String filePath,
    required String caption,
    required int sequence,
    required String uploadedBy,
  }) async {
    return uploadWorkPhoto(
      workLogId: workLogId,
      kind: _kindToStr(kind),
      filePath: filePath,
      caption: caption,
      sequence: sequence.toString(),
      uploadedBy: uploadedBy,
    );
  }

  /// Get image URL for a work photo
  static String getImageUrl(WorkPhoto workPhoto) {
    // If imageName already contains a full URL, return it
    if (workPhoto.imageName.startsWith('http://') ||
        workPhoto.imageName.startsWith('https://')) {
      return workPhoto.imageName;
    }

    // Clean up image name to fix legacy double extensions
    String cleanImageName = workPhoto.imageName;
    if (cleanImageName.endsWith('.jpg.jpg')) {
      cleanImageName = cleanImageName.substring(
        0,
        cleanImageName.length - 4,
      ); // Remove the extra .jpg
      print(
        'DEBUG: Fixed legacy double extension: ${workPhoto.imageName} -> $cleanImageName',
      );
    }

    // Determine subdirectory based on photo kind
    final subdirectory = workPhoto.kind == 'BEFORE'
        ? '1'
        : workPhoto.kind == 'AFTER'
        ? '2'
        : workPhoto.kind == 'EXTRA'
        ? '3'
        : '4';

    // Construct full URL
    final url =
        'http://124.43.181.243:8000/api/fetch-testdocket-image/$subdirectory/$cleanImageName';
    print('DEBUG getImageUrl: ${workPhoto.imageName} -> $url');
    return url;
  }
}
