import 'dart:convert';
import 'dart:io';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../../../models/ImageModel.dart';
import '../../../models/WorkPhoto.dart';
import '../../../models/WorkLog.dart';

enum PhotoKind { before, after, extra }

enum MilestoneField { acknowledgedAt, attendingAt, startedAt, completedAt }

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

  // Legacy endpoints (keeping for backward compatibility)
  static const String base = 'https://your.api.host'; // TODO
  static String get ensureUrl => '$base/worklog/ensure';
  static String get milestoneUrl => '$base/worklog/milestone';
  static String get remarksUrl => '$base/worklog/remarks';
  static String get completeUrl => '$base/worklog/complete';
  static String get listUrl => '$base/worklog/photos';
  static String get uploadUrl => '$base/worklog/photo';

  /// Ensure a work log exists and return its id as string.
  static Future<String> ensureWorkLogId({
    required String assignmentID,
    required String docketID,
    required String employeeNo,
    String? onStartedIfNew,
  }) async {
    // TODO: call your API. A sample JSON body:
    // {"assignmentID": "...", "docketID": "...", "employeeNo": "...", "startedAt": "...?"}
    // Response: {"workLogId":"123"} or {"id":"123"}
    final r = await http.post(
      Uri.parse(ensureUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'assignmentID': assignmentID,
        'docketID': docketID,
        'employeeNo': employeeNo,
        if (onStartedIfNew != null) 'startedAt': onStartedIfNew,
      }),
    );
    if (r.statusCode != 200) {
      throw 'ensureWorkLogId failed ${r.statusCode}';
    }
    final m = jsonDecode(r.body);
    return (m['workLogId'] ?? m['id'] ?? '').toString();
  }

  /// Set a milestone time as string, e.g. '2025-09-14 12:00:00'
  static Future<void> setMilestone({
    required String assignmentID,
    required String employeeNo,
    required MilestoneField field,
    required String value,
  }) async {
    final fieldName = _fieldName(field);
    final r = await http.post(
      Uri.parse(milestoneUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'assignmentID': assignmentID,
        'employeeNo': employeeNo,
        fieldName: value,
      }),
    );
    if (r.statusCode != 200) {
      throw 'setMilestone failed ${r.statusCode}';
    }
  }

  static String _fieldName(MilestoneField f) {
    switch (f) {
      case MilestoneField.acknowledgedAt:
        return 'acknowledgedAt';
      case MilestoneField.attendingAt:
        return 'attendingAt';
      case MilestoneField.startedAt:
        return 'startedAt';
      case MilestoneField.completedAt:
        return 'completedAt';
    }
  }

  static Future<void> saveRemarks({
    required String assignmentID,
    required String employeeNo,
    required String remarks,
  }) async {
    final r = await http.post(
      Uri.parse(remarksUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'assignmentID': assignmentID,
        'employeeNo': employeeNo,
        'remarks': remarks,
      }),
    );
    if (r.statusCode != 200) {
      throw 'saveRemarks failed ${r.statusCode}';
    }
  }

  static Future<void> complete({
    required String assignmentID,
    required String employeeNo,
    required String completedAt,
  }) async {
    final r = await http.post(
      Uri.parse(completeUrl),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'assignmentID': assignmentID,
        'employeeNo': employeeNo,
        'completedAt': completedAt,
      }),
    );
    if (r.statusCode != 200) {
      throw 'complete failed ${r.statusCode}';
    }
  }

  /// List photos for a work log per kind.
  static Future<List<ImageModel>> listPhotos({
    required String workLogId,
    required PhotoKind kind,
  }) async {
    final r = await http.get(
      Uri.parse('$listUrl?workLogId=$workLogId&kind=${_kindToStr(kind)}'),
    );
    if (r.statusCode != 200) return <ImageModel>[];
    final data = jsonDecode(r.body);
    if (data is! List) return <ImageModel>[];
    return data.map<ImageModel>((e) => ImageModel.fromJson(e)).toList();
  }

  /// Upload a photo (multipart) and return ImageModel.
  /// Acknowledge a work log
  static Future<void> acknowledgeWorkLog({
    required String assignmentID,
    required String docketID,
    required String employeeNo,
    required String acknowledgedAt,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(postWorkLogUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'assignmentID': assignmentID,
          'docketID': docketID,
          'employeeNo': employeeNo,
          'status': '1', // Assuming '1' means acknowledged
          'acknowledgedAt': acknowledgedAt,
          'createdAt': acknowledgedAt,
          'updatedAt': acknowledgedAt,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to acknowledge work log: ${response.body}');
      }

      // If you need to parse and return the created work log:
      // final responseData = jsonDecode(response.body);
      // return responseData;
    } catch (e) {
      throw Exception('Error acknowledging work log: $e');
    }
  }

  static Future<ImageModel> uploadPhoto({
    required String workLogId,
    required PhotoKind kind,
    required String filePath,
    required int sequence,
    required String uploadedBy,
    String? caption,
  }) async {
    // TODO: connect to your actual uploader. Below is a generic multipart sample:
    final req = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    req.fields['workLogId'] = workLogId;
    req.fields['kind'] = _kindToStr(kind);
    req.fields['sequence'] = sequence.toString();
    req.fields['uploadedBy'] = uploadedBy;
    if (caption != null) req.fields['caption'] = caption;

    req.files.add(await http.MultipartFile.fromPath('file', filePath));
    final resp = await req.send();
    final body = await http.Response.fromStream(resp);

    if (body.statusCode != 200) {
      throw 'uploadPhoto failed ${body.statusCode}';
    }
    final json = jsonDecode(body.body);
    return ImageModel.fromJson(json);
  }

  // ==================== NEW WORK LOG API METHODS ====================

  /// Get work logs - GET request
  static Future<List<WorkLog>> getWorkLogs({
    String? assignmentId,
    String? docketID,
    String? employeeNo,
  }) async {
    try {
      final uri = Uri.parse(getWorkLogUrl).replace(
        queryParameters: {
          if (assignmentId != null) 'assignmentID': assignmentId,
          if (docketID != null) 'docketID': docketID,
          if (employeeNo != null) 'employeeNo': employeeNo,
        }..removeWhere((key, value) => value == null || value.isEmpty),
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to load work logs: ${response.statusCode}');
      }

      final dynamic responseData = jsonDecode(response.body);
      
      if (responseData is List) {
        return responseData.map<WorkLog>((item) => WorkLog.fromJson(item)).toList();
      } else if (responseData is Map<String, dynamic>) {
        return [WorkLog.fromJson(responseData)];
      }
      
      throw Exception('Unexpected response format');
    } catch (e) {
      print('Error fetching work logs: $e');
      rethrow;
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
        'assignmentId': assignmentId,
        'docketId': docketId,
        'employeeNo': employeeNo,
      };

      if (acknowledgedAt != null)
        requestBody['acknowledgedAt'] = acknowledgedAt;
      if (attendingAt != null) requestBody['attendingAt'] = attendingAt;
      if (startedAt != null) requestBody['startedAt'] = startedAt;
      if (completedAt != null) requestBody['completedAt'] = completedAt;
      if (remarks != null) requestBody['remarks'] = remarks;

      final response = await http.post(
        Uri.parse(postWorkLogUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        return WorkLog.fromJson(jsonData);
      }

      throw 'Failed to create work log: ${response.statusCode} - ${response.body}';
    } catch (e) {
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

      if (assignmentId != null) requestBody['assignmentId'] = assignmentId;
      if (docketId != null) requestBody['docketId'] = docketId;
      if (employeeNo != null) requestBody['employeeNo'] = employeeNo;
      if (acknowledgedAt != null)
        requestBody['acknowledgedAt'] = acknowledgedAt;
      if (attendingAt != null) requestBody['attendingAt'] = attendingAt;
      if (startedAt != null) requestBody['startedAt'] = startedAt;
      if (completedAt != null) requestBody['completedAt'] = completedAt;
      if (remarks != null) requestBody['remarks'] = remarks;

      final response = await http.post(
        Uri.parse(updateWorkLogUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return WorkLog.fromJson(jsonData);
      }

      throw 'Failed to update work log: ${response.statusCode} - ${response.body}';
    } catch (e) {
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

  /// Upload work photo - POST request with multipart
  static Future<WorkPhoto> uploadWorkPhoto({
    required String workLogId,
    required String kind, // BEFORE, AFTER, EXTRA
    required String filePath,
    required String caption,
    required String sequence,
    required String uploadedBy,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(postWorkPhotoUrl),
      );

      // Add form fields
      request.fields['workLogId'] = workLogId;
      request.fields['kind'] = kind;
      request.fields['caption'] = caption;
      request.fields['sequence'] = sequence;
      request.fields['uploadedBy'] = uploadedBy;

      // Add file - verify file exists
      final file = File(filePath);
      if (!await file.exists()) {
        throw 'File does not exist: $filePath';
      }

      request.files.add(await http.MultipartFile.fromPath('image', filePath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        return WorkPhoto.fromJson(jsonData);
      }

      throw 'Failed to upload work photo: ${response.statusCode} - ${response.body}';
    } catch (e) {
      throw 'Error uploading work photo: $e';
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
}
