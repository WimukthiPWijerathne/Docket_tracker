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

  const HttpPostDocketDetails({
    super.key,
    required this.docketType,
    required this.fileName,
    this.filePath,
    this.locationDetails,
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
      }) async {
    try {
      final now = DateTime.now();
      final uploadedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      // Keys must match your PHP $_POST indexes exactly
      final Map<String, String> formBody = {
        'Depot': 'Paliyagoda',
        'DocketType': docketType,
        'ImageName': imageName,
        'uploadedBy': 'CSE001',
        'AssignedTo': 'WORKER001',
        'locationDetails': locationDetails ?? 'Not provided',
        'UploadedTime': uploadedTime,
        'DocketSerial': 'DS${now.millisecondsSinceEpoch}',
      };

      debugPrint('DB INSERT - Form body: $formBody');

      final resp = await http
          .post(
        Uri.parse('https://powerprox.sltidc.lk/POSTDocketDetails.php'),
        headers: const {
          'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
        },
        body: formBody,
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('DB INSERT - Response ${resp.statusCode}');
      debugPrint('DB INSERT - Response body: ${resp.body}');

      if (resp.statusCode != 200) {
        debugPrint('DB INSERT - HTTP error: ${resp.statusCode}');
        return false;
      }

      // Parse JSON response from your PHP script
      try {
        final decoded = jsonDecode(resp.body);
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
        if (resp.body.contains('Fatal error') ||
            resp.body.contains('mysqli_sql_exception')) {
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