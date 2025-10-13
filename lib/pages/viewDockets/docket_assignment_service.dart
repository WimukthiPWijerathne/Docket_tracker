import 'dart:convert';
import 'package:http/http.dart' as http;
import 'docket_assignment_model.dart';

class DocketAssignmentServiceView {
  final String baseUrl = 'https://powerprox.sltidc.lk/GETDocketAssignmentX.php';

  /// Fetch assignments for a given docket ID. The API may return a list
  /// or a single object; handle both.
  Future<List<DocketAssignmentModel>> fetchByDocketId(String docketId) async {
    try {
      final uri = Uri.parse(
        baseUrl,
      ).replace(queryParameters: {'docketId': docketId});

      final r = await http.get(uri, headers: {'Accept': 'application/json'});
      if (r.statusCode != 200) {
        throw Exception('Failed to fetch assignments: ${r.statusCode}');
      }

      if (r.body.isEmpty) return [];

      final data = json.decode(r.body);

      if (data is List) {
        return data
            .map<DocketAssignmentModel>(
              (j) => DocketAssignmentModel.fromJson(j as Map<String, dynamic>),
            )
            .toList();
      } else if (data is Map<String, dynamic>) {
        // Some responses may wrap data in a 'data' or 'assignedDockets' key
        if (data.containsKey('data') && data['data'] is List) {
          return (data['data'] as List)
              .map((j) => DocketAssignmentModel.fromJson(j))
              .toList();
        }
        if (data.containsKey('assignedDockets') &&
            data['assignedDockets'] is List) {
          return (data['assignedDockets'] as List)
              .map((j) => DocketAssignmentModel.fromJson(j))
              .toList();
        }

        // Single object
        return [DocketAssignmentModel.fromJson(data)];
      }

      return [];
    } catch (e) {
      print('Error in fetchByDocketId: $e');
      return [];
    }
  }
}
