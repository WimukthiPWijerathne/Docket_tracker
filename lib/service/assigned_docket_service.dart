import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/assigned_docket.dart';

class AssignedDocketService {
  final String baseUrl = "http://13.61.22.169:3000/docket_assignment";
   

  // Helper method to combine dockets with the same ID
  List<AssignedDocket> _combineDuplicateDockets(List<AssignedDocket> dockets) {
    print('Combining ${dockets.length} dockets to remove duplicates');
    final Map<String, AssignedDocket> docketMap = {};
    
    for (var docket in dockets) {
      print('Processing docket ID: ${docket.docketID}, Assignment ID: ${docket.assignmentID}');
      print('Current assigned persons: ${docket.assignedPersons}');
      
      if (docketMap.containsKey(docket.docketID)) {
        // If docket already exists, combine assigned persons
        final existing = docketMap[docket.docketID]!;
        print('Found duplicate docket. Existing persons: ${existing.assignedPersons}');
        
        // Only add the person if they're not already in the list
        final existingPersons = existing.assignedPersonsList.toSet();
        final newPersons = docket.assignedPersonsList.toSet();
        final combinedPersons = {...existingPersons, ...newPersons}.join(', ');
        
        print('Combined persons: $combinedPersons');
        docketMap[docket.docketID] = existing.copyWith(assignedPersons: combinedPersons);
      } else {
        // Add new docket to map
        print('Adding new docket to map');
        docketMap[docket.docketID] = docket;
      }
      print('---');
    }
    
    final combinedDockets = docketMap.values.toList();
    print('Combined to ${combinedDockets.length} unique dockets');
    return combinedDockets;
  }

  // Fetch all assigned dockets
  Future<List<AssignedDocket>> fetchAssignedDockets() async {
    try {
      print('Fetching assigned dockets from: $baseUrl');
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Accept': 'application/json',
        },
      );

      print('Assigned Dockets Response status: ${response.statusCode}');
      print('Assigned Dockets Response body: ${response.body}');
      
      // Log the first few items to understand the structure
      try {
        final jsonData = json.decode(response.body);
        print('Parsed JSON type: ${jsonData.runtimeType}');
        if (jsonData is List) {
          print('Found ${jsonData.length} dockets in response');
          for (int i = 0; i < (jsonData.length > 5 ? 5 : jsonData.length); i++) {
            print('Docket $i: ${jsonData[i]}');
          }
        } else if (jsonData is Map) {
          print('Response is a map with keys: ${jsonData.keys}');
          if (jsonData.containsKey('data') && jsonData['data'] is List) {
            print('Found ${jsonData['data'].length} dockets in data field');
          }
        }
      } catch (e) {
        print('Error parsing response JSON: $e');
      }

      if (response.statusCode == 200) {
        final String responseBody = response.body;
        
        if (responseBody.isEmpty) {
          print('Empty response body for assigned dockets');
          return [];
        }

        dynamic jsonData = json.decode(responseBody);
        
        // Handle both array and object responses
        List<AssignedDocket> dockets = [];
        
        if (jsonData is List) {
          dockets = jsonData
              .map<AssignedDocket>((json) => AssignedDocket.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (jsonData is Map<String, dynamic>) {
          if (jsonData.containsKey('data') && jsonData['data'] is List) {
            List dataList = jsonData['data'];
            dockets = dataList
                .map<AssignedDocket>((json) => AssignedDocket.fromJson(json as Map<String, dynamic>))
                .toList();
          } else if (jsonData.containsKey('assignedDockets') && jsonData['assignedDockets'] is List) {
            List assignedDocketsList = jsonData['assignedDockets'];
            dockets = assignedDocketsList
                .map<AssignedDocket>((json) => AssignedDocket.fromJson(json as Map<String, dynamic>))
                .toList();
          } else {
            dockets = [AssignedDocket.fromJson(jsonData)];
          }
        }
        
        // Combine dockets with the same ID
        return _combineDuplicateDockets(dockets);
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
  // Mark assigned docket as completed
Future<bool> markAsCompleted(
  String assignmentId, {
  String? remarks,
  String? completionImageUrl,
  String? completedTime,
}) async {
  try {
    final response = await http.post(
      Uri.parse(baseUrl.replaceAll('GETDocketAssignment2.php', 'UPDATEDocketAssignment2.php')),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'assignmentID': assignmentId, // Make sure this matches what API expects
        'completedTime': completedTime ?? DateTime.now().toIso8601String(),
        if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        if (completionImageUrl != null && completionImageUrl.isNotEmpty) 'completionImageUrl': completionImageUrl,
      }),
    );

    print('Mark as completed status: ${response.statusCode}');
    print('Request body: ${json.encode({
      'assignmentID': assignmentId,
      'completedTime': completedTime ?? DateTime.now().toIso8601String(),
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      if (completionImageUrl != null && completionImageUrl.isNotEmpty) 'completionImageUrl': completionImageUrl,
    })}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      try {
        final responseData = json.decode(response.body);
        return responseData['success'] == true || responseData['status'] == 'success';
      } catch (e) {
        print('Error parsing response: $e');
        // If response is not JSON, check if it contains success indicators
        return response.body.toLowerCase().contains('success');
      }
    } else {
      throw Exception('Failed to mark docket as completed. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in markAsCompleted: $e');
    rethrow;
  }
}

  // Reassign docket
  Future<bool> reassignDocket(String assignmentId, String newAssignedPersons) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl.replaceAll('GETDocketAssignment2.php', 'ReassignDocket.php')),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'assignmentID': assignmentId,  // Changed from assignmentId to assignmentID
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