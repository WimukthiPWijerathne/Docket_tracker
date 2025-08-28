// ...existing code...
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:async';

class ApiService {
  static Future<bool> uploadDocketDetails(
    Map<String, dynamic> docketData,
  ) async {
    print('DEBUG: Uploading docket details to API');
    print('DEBUG: Request data: $docketData');
    var uri = Uri.parse('https://powerprox.sltidc.lk/POSTDocketDetails.php');
    print('DEBUG: API URL: $uri');
    try {
      final response = await http.post(uri, body: docketData);
      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');
      if (response.statusCode == 200) {
        developer.log('DocketDetails upload successful!', name: 'ApiService');
        return true;
      } else {
        developer.log(
          'DocketDetails upload failed with status [33m${response.statusCode}[0m: ${response.body}',
          name: 'ApiService',
        );
        return false;
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error uploading DocketDetails: $e',
        name: 'ApiService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  static Future<bool> uploadDocketImage(File imageFile, String fileName) async {
    print(
      'DEBUG: ApiService.uploadDocketImage called with file: ${imageFile.path}',
    );
    var uri = Uri.parse('http://124.43.136.185:8000/api/upload-testdocket');
    var request = http.MultipartRequest('POST', uri);

    // Add required fields based on API response
    request.fields['id'] = DateTime.now().millisecondsSinceEpoch.toString();
    request.fields['subdirectory'] = 'dockets';

    var multipartFile = await http.MultipartFile.fromPath(
      'images',
      imageFile.path,
    );
    request.files.add(multipartFile);
    print(
      'DEBUG: About to send HTTP request to $uri with fields: ${request.fields}',
    );

    try {
      var response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        developer.log('Upload successful!', name: 'ApiService');
        return true;
      } else {
        print(
          'DEBUG: Upload failed with status ${response.statusCode}: $responseBody',
        );
        developer.log(
          'Upload failed with status ${response.statusCode}: $responseBody',
          name: 'ApiService',
        );
        return false;
      }
    } catch (e, stackTrace) {
      print('DEBUG: Exception during upload: $e');
      developer.log(
        'Error uploading image: $e',
        name: 'ApiService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ...existing code...
}
