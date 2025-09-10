import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/assign_workers_models.dart';

class AssignWorkersService {
  static const String postAssignmentUrl = 'https://powerprox.sltidc.lk/POSTDocketAssignment2.php';
  final String uploadedBy; // Store the user who is making the assignment

  AssignWorkersService({required this.uploadedBy});

  Future<AssignmentResponse> postAssignment(AssignmentRequest request) async {
    try {
      print('Sending assignment request: ${json.encode(request.toJson())}');
      
      final response = await http.post(
        Uri.parse(postAssignmentUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(request.toJson()),
      );

      print('Assignment response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
          return AssignmentResponse.fromJson(data);
        } catch (e) {
          throw Exception('Failed to parse server response: $e');
        }
      } else {
        throw Exception('Failed to post assignment: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error in postAssignment: $e');
      rethrow;
    }
  }

  /// Assigns multiple workers to multiple dockets
  Future<List<AssignmentResponse>> assignWorkersToDockets({
    required List<String> docketIds,
    required List<String> workers,
  }) async {
    final List<AssignmentResponse> results = [];
    final currentTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    for (final docketId in docketIds) {
      for (final worker in workers) {
        try {
          final req = AssignmentRequest(
            docketID: docketId,
            assignedPersons: worker,
            assignedTime: currentTime,
            reassigned: false,
            uploadedBy: uploadedBy,
            uploadedTime: currentTime,
          );
          
          final res = await postAssignment(req);
          results.add(res);
          
          // Small delay to avoid overwhelming the server
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          print('Error assigning worker $worker to docket $docketId: $e');
          results.add(AssignmentResponse(
            status: 'error',
            message: 'Failed to assign worker: $e',
          ));
        }
      }
    }
    
    return results;
  }
}