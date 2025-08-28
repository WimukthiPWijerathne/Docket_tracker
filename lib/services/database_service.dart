import 'dart:convert';
import 'package:http/http.dart' as http;

class DatabaseService {
  static Future<bool> uploadDocketDetails(String docketType, String imageName) async {
    try {
      print('DATABASE: Starting upload for $imageName');
      
      final requestBody = {
        'Depot': 'Paliyagoda',
        'DocketType': docketType,
        'ImageName': imageName,
        'UploadedBy': 'CSE001',
        'AssignedTo': 'WORKER001',
        'DocketSerial': 'DS${DateTime.now().millisecondsSinceEpoch}',
      };
      
      print('DATABASE: Request body - $requestBody');
      
      final response = await http.post(
        Uri.parse('https://powerprox.sltidc.lk/POSTDocketDetails.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      
      print('DATABASE: Response ${response.statusCode} - ${response.body}');
      print('DATABASE: Request headers - ${response.request?.headers}');
      print('DATABASE: Response headers - ${response.headers}');
      return response.statusCode == 200;
      
    } catch (e) {
      print('DATABASE: Error - $e');
      return false;
    }
  }
}
