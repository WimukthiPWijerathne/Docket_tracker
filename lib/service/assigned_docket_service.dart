import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/assigned_docket.dart';

class AssignedDocketService {
  final String baseUrl = "https://powerprox.sltidc.lk/GETDocketAssignment2.php"; // Update with your actual endpoint

  // Fetch all assigned dockets
  Future<List<AssignedDocket>> fetchAssignedDockets() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Accept': 'application/json',
        },
      );

      print('Assigned Dockets Response status: ${response.statusCode}');
      print('Assigned Dockets Response body: ${response.body}');

      if (response.statusCode == 200) {
        final String responseBody = response.body;
        
        if (responseBody.isEmpty) {
          print('Empty response body for assigned dockets');
          return [];
        }

        dynamic jsonData = json.decode(responseBody);
        
        // Handle both array and object responses
        if (jsonData is List) {
          return jsonData.map((json) => AssignedDocket.fromJson(json as Map<String, dynamic>)).toList();
        } else if (jsonData is Map<String, dynamic>) {
          // If the API returns an object with a data field containing the array
          if (jsonData.containsKey('data') && jsonData['data'] is List) {
            List dataList = jsonData['data'];
            return dataList.map((json) => AssignedDocket.fromJson(json as Map<String, dynamic>)).toList();
          } else if (jsonData.containsKey('assignedDockets') && jsonData['assignedDockets'] is List) {
            List assignedDocketsList = jsonData['assignedDockets'];
            return assignedDocketsList.map((json) => AssignedDocket.fromJson(json as Map<String, dynamic>)).toList();
          } else {
            // Single assigned docket object
            return [AssignedDocket.fromJson(jsonData)];
          }
        } else {
          throw Exception('Unexpected response format for assigned dockets');
        }
      } else {
        throw Exception('Failed to load assigned dockets. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchAssignedDockets: $e');
      throw Exception('Failed to load assigned dockets: $e');
    }
  }

  // Fetch assigned dockets by person ID
  Future<List<AssignedDocket>> fetchAssignedDocketsByPerson(String personId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?personId=$personId'),
        headers: {'Accept': 'application/json'},
      );

      print('Fetch assigned dockets by person status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          print('Empty response when fetching assigned dockets by person');
          return [];
        }

        dynamic jsonData = json.decode(responseBody);
        
        if (jsonData is List) {
          return jsonData.map((json) => AssignedDocket.fromJson(json as Map<String, dynamic>)).toList();
        } else if (jsonData is Map<String, dynamic>) {
          if (jsonData.containsKey('data') && jsonData['data'] is List) {
            List dataList = jsonData['data'];
            return dataList.map((json) => AssignedDocket.fromJson(json as Map<String, dynamic>)).toList();
          } else {
            return [AssignedDocket.fromJson(jsonData)];
          }
        }
      }
      return [];
    } catch (e) {
      print('Error in fetchAssignedDocketsByPerson: $e');
      return [];
    }
  }

  // Fetch a single assigned docket by assignment ID
  Future<AssignedDocket?> fetchAssignedDocketById(String assignmentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?assignmentId=$assignmentId'),
        headers: {'Accept': 'application/json'},
      );

      print('Fetch assigned docket by ID status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          print('Empty response when fetching assigned docket by ID');
          return null;
        }

        dynamic jsonData = json.decode(responseBody);
        
        if (jsonData is List) {
          return jsonData.isNotEmpty ? AssignedDocket.fromJson(jsonData.first) : null;
        } else if (jsonData is Map<String, dynamic>) {
          return AssignedDocket.fromJson(jsonData);
        }
      }
      return null;
    } catch (e) {
      print('Error in fetchAssignedDocketById: $e');
      return null;
    }
  }

  // Mark assigned docket as completed
  Future<bool> markAsCompleted(String assignmentId) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl.replaceAll('GETAssignedDockets.php', 'CompleteAssignedDocket.php')),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'assignmentId': assignmentId,
          'completedTime': DateTime.now().toIso8601String(),
        }),
      );

      print('Mark as completed status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] == true;
      } else {
        throw Exception('Failed to mark docket as completed. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in markAsCompleted: $e');
      return false;
    }
  }

  // Reassign docket
  Future<bool> reassignDocket(String assignmentId, String newAssignedPersons) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl.replaceAll('GETAssignedDockets.php', 'ReassignDocket.php')),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'assignmentId': assignmentId,
          'newAssignedPersons': newAssignedPersons,
          'reassignedTime': DateTime.now().toIso8601String(),
        }),
      );

      print('Reassign docket status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] == true;
      } else {
        throw Exception('Failed to reassign docket. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in reassignDocket: $e');
      return false;
    }
  }

  // Get assignment statistics
  Future<Map<String, int>> getAssignmentStatistics() async {
    try {
      final assignedDockets = await fetchAssignedDockets();
      
      final stats = <String, int>{
        'total': assignedDockets.length,
        'completed': assignedDockets.where((d) => d.isCompleted).length,
        'ongoing': assignedDockets.where((d) => d.isOngoing).length,
        'reassigned': assignedDockets.where((d) => d.hasBeenReassigned).length,
      };
      
      return stats;
    } catch (e) {
      print('Error in getAssignmentStatistics: $e');
      return {
        'total': 0,
        'completed': 0,
        'ongoing': 0,
        'reassigned': 0,
      };
    }
  }
}