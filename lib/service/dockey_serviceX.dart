import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/docketsX.dart';

class DocketServiceX {
  final String baseUrl = "https://powerprox.sltidc.lk/GETDocketDetailsX.php";

  // Fetch a single docket by ID
  Future<Docket?> fetchDocketById(String docketId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?id=$docketId'),
        headers: {'Accept': 'application/json'},
      );

      print('Fetch docket by ID status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          print('Empty response when fetching docket by ID');
          return null;
        }

        dynamic jsonData = json.decode(responseBody);

        if (jsonData is List) {
          return jsonData.isNotEmpty ? Docket.fromJson(jsonData.first) : null;
        } else if (jsonData is Map<String, dynamic>) {
          return Docket.fromJson(jsonData);
        }
      }
      return null;
    } catch (e) {
      print('Error in fetchDocketById: $e');
      return null;
    }
  }

  Future<List<Docket>> fetchDockets() async {
    try {
      // Use the baseUrl directly since it's already the complete endpoint
      // Remove Content-Type header for GET requests to avoid CORS preflight
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Accept': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      // Print just a small part of the response to avoid flooding the logs
      print('Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final String responseBody = response.body;

        if (responseBody.isEmpty) {
          print('Empty response body');
          return [];
        }

        dynamic jsonData = json.decode(responseBody);

        // Handle both array and object responses
        if (jsonData is List) {
          return jsonData
              .map((json) => Docket.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (jsonData is Map<String, dynamic>) {
          // If the API returns an object with a data field containing the array
          if (jsonData.containsKey('data') && jsonData['data'] is List) {
            List dataList = jsonData['data'];
            return dataList
                .map((json) => Docket.fromJson(json as Map<String, dynamic>))
                .toList();
          } else if (jsonData.containsKey('dockets') &&
              jsonData['dockets'] is List) {
            List docketsList = jsonData['dockets'];
            return docketsList
                .map((json) => Docket.fromJson(json as Map<String, dynamic>))
                .toList();
          } else {
            // Single docket object
            return [Docket.fromJson(jsonData)];
          }
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception(
          'Failed to load dockets. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in fetchDockets: $e');
      throw Exception('Failed to load dockets: $e');
    }
  }

  // Method to assign dockets
  Future<bool> assignDockets(List<String> docketIds, String assignedTo) async {
    try {
      final response = await http.post(
        Uri.parse(
          baseUrl.replaceAll('GETDocketDetails2.php', 'AssignDockets.php'),
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'docketIds': docketIds, 'assignedTo': assignedTo}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] == true;
      } else {
        throw Exception(
          'Failed to assign dockets. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in assignDockets: $e');
      return false;
    }
  }

  // Method to update docket status
  Future<bool> updateDocketStatus(String docketId, String status) async {
    try {
      final response = await http.post(
        Uri.parse(
          baseUrl.replaceAll('GETDocketDetails2.php', 'UpdateDocketStatus.php'),
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': docketId, 'status': status}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] == true;
      } else {
        throw Exception(
          'Failed to update docket status. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in updateDocketStatus: $e');
      return false;
    }
  }

  // Method to update location details
  Future<bool> updateLocationDetails(
    String docketId,
    String locationDetails,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          baseUrl.replaceAll(
            'GETDocketDetails2.php',
            'UpdateLocationDetails.php',
          ),
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': docketId, 'locationDetails': locationDetails}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] == true;
      } else {
        throw Exception(
          'Failed to update location details. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in updateLocationDetails: $e');
      return false;
    }
  }
}
