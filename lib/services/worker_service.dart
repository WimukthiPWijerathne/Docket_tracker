import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/worker_model.dart';

// Worker Service class


class WorkerService {
  static const String baseUrl = 'https://powerprox.sltidc.lk';
  
  Future<List<Worker>> fetchWorkers() async {
    try {
      final url = Uri.parse('$baseUrl/GETPeople.php');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);

        if (result['status'] == 'success') {
          final List data = result['data'];
          return data.map<Worker>((w) => Worker.fromJson(w)).toList();
        } else {
          throw Exception(result['message'] ?? 'Failed to load workers');
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