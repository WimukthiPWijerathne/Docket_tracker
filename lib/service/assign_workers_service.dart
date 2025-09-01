import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/assign_workers_models.dart';

class AssignWorkersService {
  static const String postAssignmentUrl = 'https://powerprox.sltidc.lk/POSTDocketAssignment.php';

  Future<AssignmentResponse> postAssignment(AssignmentRequest request) async {
    final response = await http.post(
      Uri.parse(postAssignmentUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(request.toJson()),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body) as Map<String, dynamic>;
      return AssignmentResponse.fromJson(data);
    } else {
      throw Exception('Failed to post assignment: ${response.statusCode} ${response.body}');
    }
  }

  // Helper to post many combinations (each worker x each docket)
  Future<List<AssignmentResponse>> postAssignments({required List<String> docketIds, required List<String> workers}) async {
    final List<AssignmentResponse> results = [];
    for (final docketId in docketIds) {
      for (final worker in workers) {
        final req = AssignmentRequest(docketId: docketId, assignedTo: worker);
        final res = await postAssignment(req);
        results.add(res);
      }
    }
    return results;
  }
}