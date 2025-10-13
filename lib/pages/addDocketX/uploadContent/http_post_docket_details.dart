// lib/pages/http_post_docket_details.dart
// lib/pages/http_post_docket_details.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
// import 'package:provider/provider.dart'; // Commented out as we're not using UserAccess

// import 'package:leco_docket_tracker/pages/loginScreen/fetchUserAccess.dart';

// By default assigned= 0 mean unassigned, 1 mean assigned,
// 2 mean complete, 3 mean reassigned, 4 mean having issue

class HttpPostDocketDetails extends StatefulWidget {
  final String docketType;
  final String fileName;
  final String? filePath; // optional; kept for parity
  final String? locationDetails;
  final String? docketSerial; // ✅ Fixed: lowercase to match convention

  const HttpPostDocketDetails({
    super.key,
    required this.docketType,
    required this.fileName,
    this.filePath,
    this.locationDetails,
    this.docketSerial,
  });

  @override
  State<HttpPostDocketDetails> createState() => _HttpPostDocketDetailsState();
}

class _HttpPostDocketDetailsState extends State<HttpPostDocketDetails> {
  @override
  void initState() {
    super.initState();
    // Auto-start database insert after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _uploadDocketDetails());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saving Details')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 20),
            Text('Saving docket details...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDocketDetails() async {
    try {
      // Comment out UserAccess for now to bypass user authentication
      // final ua = context.read<UserAccess>();
      //
      // final depot = (ua.depot?.trim().isNotEmpty ?? false)
      //     ? ua.depot!.trim()
      //     : 'Unknown';
      // final uploadedBy = ua.username ?? ua.employeeNumber ?? 'Unknown';
      // final assignedTo = ua.employeeNumber ?? 'UNASSIGNED';

      // Use hardcoded temporary values instead
      const depot = 'Temporary-Depot';
      const uploadedBy = 'Temporary-User';
      // const assignedTo = 'UNASSIGNED'; // not needed but keeping for reference

      debugPrint('📤 Uploading docket details:');
      debugPrint('  - Type: ${widget.docketType}');
      debugPrint('  - File: ${widget.fileName}');
      debugPrint('  - Serial: ${widget.docketSerial}'); // ✅ Debug
      debugPrint('  - Location: ${widget.locationDetails}');

      final ok = await _uploadDocketDetailsToDatabase(
        widget.docketType,
        widget.fileName,
        depot: depot,
        uploadedBy: uploadedBy,
        status: '0',
        locationDetails: widget.locationDetails,
        docketSerial: widget.docketSerial, // ✅ Fixed: lowercase
      );

      if (!mounted) return;
      // Return the result to the caller (e.g., ImagePreviewPage)
      Navigator.of(context).pop<bool>(ok);
    } catch (e) {
      debugPrint('❌ Error uploading docket details: $e');
      if (!mounted) return;
      Navigator.of(context).pop<bool>(false);
    }
  }

  /// Sends form-encoded data to your PHP API and returns true/false.
  static Future<bool> _uploadDocketDetailsToDatabase(
    String docketType,
    String imageName, {
    required String depot,
    required String uploadedBy,
    String? locationDetails,
    String? docketSerial, // ✅ Fixed: lowercase parameter
    required String status,
  }) async {
    try {
      final now = DateTime.now();
      final uploadedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      final Map<String, String> postData = {
        'Depot': depot,
        'DocketType': docketType,
        'ImageName': imageName,
        'uploadedBy': uploadedBy,
        'UploadedTime': uploadedTime,
        'status': '0', // zero means it's new one
        'locationDetails': locationDetails ?? '',
        'DocketSerial':
            docketSerial ?? '', // ✅ Fixed: Always include, even if empty
      };

      // ✅ Debug: Print what we're sending
      debugPrint('📋 POST Data being sent:');
      postData.forEach((key, value) {
        debugPrint('  $key: $value');
      });

      final response = await http
          .post(
            Uri.parse('https://powerprox.sltidc.lk/POSTDocketDetailsX.php'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: postData,
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode != 200) {
        debugPrint('❌ HTTP error: ${response.statusCode}');
        return false;
      }

      // Try to parse JSON payload { status: "success", ... }
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['status'] == 'success') {
          debugPrint('✅ Upload successful! ID: ${decoded['id']}');
          return true;
        }
        debugPrint('❌ Server returned non-success: ${decoded['message']}');
        return false;
      } catch (_) {
        // If body isn't JSON, treat HTTP 200 as success unless obvious error text
        final body = response.body;
        if (body.contains('Fatal error') ||
            body.contains('mysqli_sql_exception')) {
          debugPrint('❌ Database error detected in response');
          return false;
        }
        debugPrint('⚠️ Non-JSON response, but treating as success');
        return true;
      }
    } on TimeoutException {
      debugPrint('❌ Request timeout');
      return false;
    } catch (e) {
      debugPrint('❌ Exception: $e');
      return false;
    }
  }
}


//v2
// // pages/http_post_docket_details.dart
// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:http/http.dart' as context;
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
//
// import '../../loginScreen/fetchUserAccess.dart';
//
// Future<void> _uploadDocketDetails() async {
//   // Read once; no rebuilds needed in this page
//   final ua = context.read<UserAccess>();
//
//   // Safely build the values
//   final depot      = ua.depot ?? 'Unknown';
//   final updator    = ua.username ?? ua.employeeNumber ?? ua.uuid ?? 'Unknown';
//   final assignedTo = ua.employeeNumber ?? 'UNASSIGNED';
//
//   final ok = await _uploadDocketDetailsToDatabase(
//     widget.docketType,
//     widget.fileName,
//     depot: depot,
//     uploadedBy: updator,
//     assignedTo: assignedTo,
//     locationDetails: widget.locationDetails,
//     docketSerial: widget.docketSerial,
//   );
//
//   if (!mounted) return;
//   Navigator.of(context).pop<bool>(ok);
// }
//
//
// class HttpPostDocketDetails extends StatefulWidget {
//   final String docketType;
//   final String fileName;
//   final String? filePath;        // optional; not used here but kept for API parity
//   final String? locationDetails;
//   final String? docketSerial;
//
//   const HttpPostDocketDetails({
//     super.key,
//     required this.docketType,
//     required this.fileName,
//     this.filePath,
//     this.locationDetails,
//     this.docketSerial,
//   });
//
//   @override
//   State<HttpPostDocketDetails> createState() => _HttpPostDocketDetailsState();
// }
//
// class _HttpPostDocketDetailsState extends State<HttpPostDocketDetails> {
//   @override
//   void initState() {
//     super.initState();
//     // Auto-start database insert after first frame
//     WidgetsBinding.instance.addPostFrameCallback((_) => _uploadDocketDetails());
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Saving Details')),
//       body: const Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(color: Colors.green),
//             SizedBox(height: 20),
//             Text('Saving docket details...', style: TextStyle(fontSize: 16)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> _uploadDocketDetails() async {
//     try {
//       final ok = await _uploadDocketDetailsToDatabase(
//         widget.docketType,
//         widget.fileName,
//         locationDetails: widget.locationDetails,
//         docketSerial: widget.docketSerial,
//       );
//       if (!mounted) return;
//       // ✅ return result to caller (e.g., ImagePreviewPage) instead of navigating elsewhere
//       Navigator.of(context).pop<bool>(ok);
//     } catch (e) {
//       if (!mounted) return;
//       Navigator.of(context).pop<bool>(false);
//     }
//   }
//
//   /// Sends form-encoded data to your existing PHP API and returns true/false.
//   static Future<bool> _uploadDocketDetailsToDatabase(
//       String docketType,
//       String imageName, {
//         String? locationDetails,
//         String? docketSerial,
//       }) async {
//     try {
//       final now = DateTime.now();
//       final uploadedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
//
//       final Map<String, String> postData = {
//         'Depot': 'Paliyagoda',
//         'DocketType': docketType,
//         'ImageName': imageName,
//         'uploadedBy': 'CSE001',
//         'UploadedTime': uploadedTime,
//         'AssignedTo': 'WORKER001',
//         'locationDetails': locationDetails ?? '',
//       };
//
//       if (docketSerial != null && docketSerial.isNotEmpty) {
//         postData['DocketSerial'] = docketSerial;
//       }
//
//       final response = await http
//           .post(
//         Uri.parse('https://powerprox.sltidc.lk/POSTDocketDetails.php'),
//         headers: {'Content-Type': 'application/x-www-form-urlencoded'},
//         body: postData.map((k, v) => MapEntry(k, v.toString())),
//       )
//           .timeout(const Duration(seconds: 30));
//
//       if (response.statusCode != 200) {
//         return false;
//       }
//
//       // Try to parse JSON success payload; fall back to true for HTTP 200 unless obvious error text.
//       try {
//         final decoded = jsonDecode(response.body);
//         if (decoded is Map && decoded['status'] == 'success') {
//           return true;
//         }
//         return false;
//       } catch (_) {
//         if (response.body.contains('Fatal error') ||
//             response.body.contains('mysqli_sql_exception')) {
//           return false;
//         }
//         return true;
//       }
//     } on TimeoutException {
//       return false;
//     } catch (_) {
//       return false;
//     }
//   }
// }
//


// v1
// pages/http_post_docket_details.dart
// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
//
// import 'junk/upload_confirmation_page.dart';
//
// class HttpPostDocketDetails extends StatefulWidget {
//   final String docketType;
//   final String fileName;
//   final String? filePath;
//   final String? locationDetails;
//   final String? docketSerial;
//
//   const HttpPostDocketDetails({
//     super.key,
//     required this.docketType,
//     required this.fileName,
//     this.filePath,
//     this.locationDetails,
//     this.docketSerial,
//   });
//
//   @override
//   State<HttpPostDocketDetails> createState() => _HttpPostDocketDetailsState();
// }
//
// class _HttpPostDocketDetailsState extends State<HttpPostDocketDetails> {
//   bool _isUploading = false;
//
//   @override
//   void initState() {
//     super.initState();
//     // Auto-start database insert after first frame
//     WidgetsBinding.instance.addPostFrameCallback((_) => _uploadDocketDetails());
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Saving Details')),
//       body: const Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(color: Colors.green),
//             SizedBox(height: 20),
//             Text('Saving docket details...', style: TextStyle(fontSize: 16)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> _uploadDocketDetails() async {
//     setState(() => _isUploading = true);
//
//     try {
//       final dbUploadSuccess = await _uploadDocketDetailsToDatabase(
//         widget.docketType,
//         widget.fileName,
//         locationDetails: widget.locationDetails,
//         docketSerial: widget.docketSerial,
//       );
//
//       if (!mounted) return;
//
//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute(
//           builder: (_) => UploadResultPage(
//             isSuccess: dbUploadSuccess,
//             filePath: widget.filePath,
//             docketType: widget.docketType,
//           ),
//         ),
//       );
//     } catch (e, st) {
//       debugPrint('Error during docket details upload: $e\n$st');
//       if (!mounted) return;
//       Navigator.of(context).pushReplacement(
//         MaterialPageRoute(
//           builder: (_) => UploadResultPage(
//             isSuccess: false,
//             filePath: widget.filePath,
//             docketType: widget.docketType,
//             errorMessage: e.toString(),
//           ),
//         ),
//       );
//     } finally {
//       if (mounted) setState(() => _isUploading = false);
//     }
//   }
//
//   /// Sends form-encoded data to your existing PHP API
//   static Future<bool> _uploadDocketDetailsToDatabase(
//       String docketType,
//       String imageName, {
//       String? locationDetails,
//       String? docketSerial,
//       }) async {
//     try {
//       final now = DateTime.now();
//       final uploadedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
//
//       final Map<String, String> postData = {
//         'Depot': 'Paliyagoda',
//         'DocketType': docketType,
//         'ImageName': imageName,
//         'uploadedBy': 'CSE001',
//         'UploadedTime': uploadedTime,
//         'AssignedTo': 'WORKER001',
//         'locationDetails': locationDetails ?? '',
//       };
//
//       debugPrint('DB INSERT - Form body: $postData');
//
//       // Add docket serial to the post data if available
//       if (docketSerial != null && docketSerial.isNotEmpty) {
//         postData['DocketSerial'] = docketSerial;
//       }
//
//       final response = await http.post(
//         Uri.parse('https://powerprox.sltidc.lk/POSTDocketDetails.php'),
//         headers: {'Content-Type': 'application/x-www-form-urlencoded'},
//         body: postData.map((key, value) => MapEntry(key, value.toString())),
//       ).timeout(const Duration(seconds: 30));
//
//       debugPrint('DB INSERT - Response ${response.statusCode}');
//       debugPrint('DB INSERT - Response body: ${response.body}');
//
//       if (response.statusCode != 200) {
//         debugPrint('DB INSERT - HTTP error: ${response.statusCode}');
//         return false;
//       }
//
//       // Parse JSON response from your PHP script
//       try {
//         final decoded = jsonDecode(response.body);
//         if (decoded is Map && decoded['status'] == 'success') {
//           debugPrint('DB INSERT - Success! ID: ${decoded['id']}');
//           return true;
//         } else {
//           debugPrint('DB INSERT - Database error: ${decoded['message']}');
//           return false;
//         }
//       } catch (jsonError) {
//         debugPrint('DB INSERT - JSON parse error: $jsonError');
//         // If it's not JSON but HTTP 200, might still be success
//         // Check for obvious error indicators
//         if (response.body.contains('Fatal error') ||
//             response.body.contains('mysqli_sql_exception')) {
//           return false;
//         }
//         return true;
//       }
//     } on TimeoutException catch (e) {
//       debugPrint('DB INSERT - Timeout: $e');
//       return false;
//     } catch (e) {
//       debugPrint('DB INSERT - Error: $e');
//       return false;
//     }
//   }
// }