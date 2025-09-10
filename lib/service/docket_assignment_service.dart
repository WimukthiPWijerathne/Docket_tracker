import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DocketAssignmentService {
  static const String baseUrl = 'https://powerprox.sltidc.lk';
  static const String assignmentEndpoint = '/POSTDocketAssignment2.php';

  /// Assigns a worker to a docket with proper error handling and logging
  Future<bool> assignWorkerToDocket({
    required String docketId,
    required String assignedPerson,
    required String assignedTime,
    required bool reassigned,
    required String uploadedBy,
    required String uploadedTime,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$assignmentEndpoint');
      
      // Format the request body to match the database schema
      final requestBody = {
        'docketID': docketId,
        'assignedPersons': assignedPerson,
        'assignedTime': assignedTime,
        'reassigned': reassigned ? 1 : 0, // Convert boolean to int for MySQL
        'uploadedBy': uploadedBy,
        'uploadedTime': uploadedTime,
      };

      print('🔄 Sending assignment request to: $url');
      print('📝 Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('📥 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final responseData = jsonDecode(response.body);
          
          // Handle different success response formats
          if (responseData is Map<String, dynamic>) {
            if ((responseData['success'] == true) ||
                (responseData['status'] == 'success') ||
                (responseData['message']?.toString().toLowerCase().contains('success') == true)) {
              print('✅ Successfully assigned worker to docket');
              return true;
            }
            
            // Check for database errors in the response
            if (responseData['error'] != null) {
              print('❌ Database error: ${responseData['error']}');
              return false;
            }
          }
          
          // If we can't determine success from the response, log a warning but assume success
          print('⚠️ Could not determine success from response, but received status ${response.statusCode}');
          return true;
          
        } catch (e) {
          print('❌ Error parsing response JSON: $e');
          return false;
        }
      } else {
        print('❌ Assignment failed with status code: ${response.statusCode}');
        print('❌ Error response: ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Exception during assignment:');
      print('❌ Error: $e');
      print('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  // Method to assign multiple workers to multiple dockets in batch
  Future<List<AssignmentResult>> batchAssignWorkers({
    required List<String> docketIds,
    required List<String> workers,
    required String uploadedBy,
    required String uploadedTime,
  }) async {
    final results = <AssignmentResult>[];
    final currentTime = DateTime.now().toIso8601String();

    for (final docketId in docketIds) {
      for (final worker in workers) {
        try {
          final success = await assignWorkerToDocket(
            docketId: docketId,
            assignedPerson: worker,
            assignedTime: currentTime,
            reassigned: false, // You can modify this logic as needed
            uploadedBy: uploadedBy,
            uploadedTime: uploadedTime,
          );

          results.add(AssignmentResult(
            docketId: docketId,
            worker: worker,
            isSuccess: success,
            errorMessage: success ? null : 'Assignment failed',
          ));
        } catch (e) {
          results.add(AssignmentResult(
            docketId: docketId,
            worker: worker,
            isSuccess: false,
            errorMessage: e.toString(),
          ));
        }
      }
    }

    return results;
  }

  // Method to check if a docket already has assignments (for reassigned flag)
  Future<bool> checkDocketHasAssignments(String docketId) async {
    // You would implement this based on your backend API
    // For now, returning false as default
    return false;
  }
}

class AssignmentResult {
  final String docketId;
  final String worker;
  final bool isSuccess;
  final String? errorMessage;

  AssignmentResult({
    required this.docketId,
    required this.worker,
    required this.isSuccess,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'AssignmentResult(docketId: $docketId, worker: $worker, isSuccess: $isSuccess, errorMessage: $errorMessage)';
  }
}