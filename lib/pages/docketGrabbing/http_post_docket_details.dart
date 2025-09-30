// pages/http_post_docket_details.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'upload_confirmation_page.dart';

class HttpPostDocketDetails extends StatefulWidget {
  final String docketType;
  final String fileName;
  final String? filePath;
  final String? locationDetails;
  final String? docketSerial;

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
  bool _isUploading = false;

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
    setState(() => _isUploading = true);

    try {
      final dbUploadSuccess = await _uploadDocketDetailsToDatabase(
        widget.docketType,
        widget.fileName,
        locationDetails: widget.locationDetails,
        docketSerial: widget.docketSerial,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => UploadResultPage(
            isSuccess: dbUploadSuccess,
            filePath: widget.filePath,
            docketType: widget.docketType,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Error during docket details upload: $e\n$st');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => UploadResultPage(
            isSuccess: false,
            filePath: widget.filePath,
            docketType: widget.docketType,
            errorMessage: e.toString(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Sends form-encoded data to your existing PHP API
  static Future<bool> _uploadDocketDetailsToDatabase(
    String docketType,
    String imageName, {
    String? locationDetails,
    String? docketSerial,
  }) async {
    try {
      final now = DateTime.now();
      final uploadedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      final Map<String, String> postData = {
        'Depot': 'Wattala',
        'DocketType': docketType,
        'ImageName': imageName,
        'UploadedBy': 'CSE001',
        'UploadedTime': uploadedTime,
        'AssignedTo': 'WORKER001',
        'locationDetails': locationDetails ?? '',
      };

      debugPrint('DB INSERT - Form body: $postData');

      // Add docket serial to the post data if available
      if (docketSerial != null && docketSerial.isNotEmpty) {
        postData['DocketSerial'] = docketSerial;
      }

      final response = await http
          .post(
            Uri.parse('https://powerprox.sltidc.lk/POSTDocketDetails2.php'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: postData.map((key, value) => MapEntry(key, value.toString())),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('DB INSERT - Response ${response.statusCode}');
      debugPrint('DB INSERT - Response body: ${response.body}');

      if (response.statusCode != 200) {
        debugPrint('DB INSERT - HTTP error: ${response.statusCode}');
        return false;
      }

      // Parse JSON response from your PHP script
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['status'] == 'success') {
          debugPrint('DB INSERT - Success! ID: ${decoded['id']}');
          return true;
        } else {
          debugPrint('DB INSERT - Database error: ${decoded['message']}');
          return false;
        }
      } catch (jsonError) {
        debugPrint('DB INSERT - JSON parse error: $jsonError');
        // If it's not JSON but HTTP 200, might still be success
        // Check for obvious error indicators
        if (response.body.contains('Fatal error') ||
            response.body.contains('mysqli_sql_exception')) {
          return false;
        }
        return true;
      }
    } on TimeoutException catch (e) {
      debugPrint('DB INSERT - Timeout: $e');
      return false;
    } catch (e) {
      debugPrint('DB INSERT - Error: $e');
      return false;
    }
  }
}
