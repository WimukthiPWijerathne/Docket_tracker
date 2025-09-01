import 'dart:convert';
import 'package:http/http.dart' as http;

class DocketAssignmentService {
  static const String baseUrl = 'https://powerprox.sltidc.lk';
  static const String assignmentEndpoint = '/POSTDocketAssignment.php';

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
      
      final requestBody = {
        'docketID': docketId,
        'assignedPersons': assignedPerson,
        'assignedTime': assignedTime,
        'reassigned': reassigned,
        'uploadedBy': uploadedBy,
        'uploadedTime': uploadedTime,
      };

      print('Sending assignment request:');
      print('URL: $url');
      print('Body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = jsonDecode(response.body);
          
          // Check if the response indicates success
          if (responseData is Map<String, dynamic>) {
            // Handle different success response formats
            if (responseData.containsKey('success') && responseData['success'] == true) {
              return true;
            } else if (responseData.containsKey('status') && responseData['status'] == 'success') {
              return true;
            } else if (responseData.containsKey('message')) {
              final message = responseData['message'].toString().toLowerCase();
              if (message.contains('success') || message.contains('assigned')) {
                return true;
              }
            }
          }
          
          // If we can't determine success from the response, assume it worked if status is 200
          return true;
        } catch (e) {
          print('Error parsing response JSON: $e');
          // If JSON parsing fails but status is 200, assume success
          return true;
        }
      } else if (response.statusCode == 201) {
        // 201 Created is also a success status
        return true;
      } else {
        print('Assignment failed with status code: ${response.statusCode}');
        print('Error response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception during assignment: $e');
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