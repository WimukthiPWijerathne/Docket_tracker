import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DatabaseService {
  static Future<bool> uploadDocketDetails(String docketType, String imageName) async {
    try {
      print('DATABASE: Starting upload for $imageName');
      
      final now = DateTime.now();
      final uploadedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      // Use exact keys observed from server output
      final requestBody = {
        'Depot': 'Paliyagoda',
        'DocketType': docketType,
        'ImageName': imageName,
        'uploadedBy': 'CSE001',
        'AssignedTo': '0',
        'UploadedTime': uploadedTime,
        'DocketSerial': 'DS${now.millisecondsSinceEpoch}',
      };
      
      print('DATABASE: JSON Request body - $requestBody');

      // Send JSON as required by backend
      final responseJson = await http.post(
        Uri.parse('https://powerprox.sltidc.lk/POSTDocketDetails2.php'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      print('DATABASE: JSON Response ${responseJson.statusCode} - ${responseJson.body}');
      print('DATABASE: JSON Request headers - ${responseJson.request?.headers}');
      print('DATABASE: JSON Response headers - ${responseJson.headers}');
      return responseJson.statusCode == 200;
      
    } catch (e) {
      print('DATABASE: Error - $e');
      return false;
    }
  }
}

