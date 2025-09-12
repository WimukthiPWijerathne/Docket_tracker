import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/worker_model.dart';

// Worker Service class


class WorkerService {
  static const String baseUrl = 'http://13.61.22.169:3000';
  
  Future<List<Worker>> fetchWorkers() async {
    try {
      final url = Uri.parse('$baseUrl/workers');
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );

      print('Fetch workers response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Handle different response formats
        if (responseData is List) {
          return responseData.map<Worker>((w) => Worker.fromJson(w)).toList();
        } else if (responseData is Map && responseData.containsKey('data')) {
          final List data = responseData['data'];
          return data.map<Worker>((w) => Worker.fromJson(w)).toList();
        } else {
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching workers: $e');
      rethrow;
    }
  }

  Future<List<Worker>> fetchAvailableWorkers() async {
    try {
      final allWorkers = await fetchWorkers();
      // Filter only available workers
      return allWorkers.where((worker) => worker.isAvailable).toList();
    } catch (e) {
      print('Error fetching available workers: $e');
      rethrow;
    }
  }

  Future<List<Worker>> fetchWorkersByDepot(String depot) async {
    try {
      final allWorkers = await fetchWorkers();
      if (depot == 'All') {
        return allWorkers;
      } else {
        return allWorkers.where((worker) => worker.depot == depot).toList();
      }
    } catch (e) {
      print('Error fetching workers by depot: $e');
      rethrow;
    }
  }
}