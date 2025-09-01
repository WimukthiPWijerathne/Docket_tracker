// ...existing code...
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:async';

class ApiService {

  /// Uploads a docket image to the server with the specified subdirectory
  /// 
  /// [imageFile] - The image file to upload
  /// [fileName] - The name to save the file as on the server
  /// [subdirectory] - The subdirectory to store the image in (1-4):
  ///                  1 - Service Line Maintenance
  ///                  2 - Meter Testing
  ///                  3 - Estimation
  ///                  4 - All other
  static Future<bool> uploadDocketImage(
    File imageFile, 
    String fileName, 
    int subdirectory,
  ) async {
    try {
      print('DEBUG: Starting upload of ${imageFile.path} as $fileName to subdirectory $subdirectory');
      print('DEBUG: File exists: ${await imageFile.exists()}');
      
      if (!await imageFile.exists()) {
        print('ERROR: File does not exist at path: ${imageFile.path}');
        return false;
      }
      
      var uri = Uri.parse('http://124.43.136.185:8000/api/upload-testdocket');
      print('DEBUG: Uploading to URL: $uri');
      
      var request = http.MultipartRequest('POST', uri);
      
      // Add the image file with the correct field name
      var multipartFile = await http.MultipartFile.fromPath(
        'images',  // Field name should match server expectation
        imageFile.path,
      );
      request.files.add(multipartFile);
      
      // Add other fields as per server requirements
      request.fields['id'] = fileName;
      request.fields['subdirectory'] = subdirectory.toString();
      
      print('DEBUG: Sending request with fields: ${request.fields}');
      print('DEBUG: File size: ${await imageFile.length()} bytes');
      
      // Send the request with timeout
      var response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('ERROR: Upload timed out after 30 seconds');
          throw TimeoutException('Upload timed out');
        },
      );
      
      final responseBody = await response.stream.bytesToString();
      final statusCode = response.statusCode;
      
      print('DEBUG: Server response status: $statusCode');
      print('DEBUG: Server response: $responseBody');
      
      if (statusCode == 200) {
        print('DEBUG: File uploaded successfully!');
        // Handle the case where server adds an extra .jpg extension
        final actualFileName = fileName.endsWith('.jpg') ? '$fileName.jpg' : fileName;
        print('DEBUG: Access URL: http://124.43.136.185:8000/api/fetch-testdocket-image/$subdirectory/$actualFileName');
        return true;
      } else {
        print('ERROR: Upload failed with status $statusCode: $responseBody');
        return false;
      }
    } catch (e, stackTrace) {
      print('ERROR: Exception during upload: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  // ...existing code...
}
