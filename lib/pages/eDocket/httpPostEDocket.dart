// lib/pages/eDocket/httpPostEDocket.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import '../loginScreen/fetchUserAccess.dart';
import 'e_docket_model.dart';

/// Minimal logger (prints only in debug)
void _d(Object? o) {
  if (kDebugMode) debugPrint('[EDocket] $o');
}

/// Rich result for diagnostics
class UploadResult {
  final bool ok;
  final int status;
  final String body;
  final Uri uri;
  final Map<String, String> sent;
  final String? error;

  const UploadResult({
    required this.ok,
    required this.status,
    required this.body,
    required this.uri,
    required this.sent,
    this.error,
  });
}

class HttpPostEDocket extends StatefulWidget {
  final EDocket model;
  final List<String> errorTypes;
  final String? otherError;
  final String? remarks;
  // This can be either a list of local file paths (preferred) or already-uploaded names.
  // If paths exist on disk, we'll upload them and generate names; otherwise we'll pass through as names.
  final List<String>? imageNames;
  // Alternatively, raw image files can be passed here (preferred for direct upload)
  final List<File>? imageFiles;

  const HttpPostEDocket({
    super.key,
    required this.model,
    required this.errorTypes,
    this.otherError,
    this.remarks,
    this.imageNames,
    this.imageFiles,
  });

  @override
  State<HttpPostEDocket> createState() => _HttpPostEDocketState();
}

class _HttpPostEDocketState extends State<HttpPostEDocket> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Submitting E-Docket')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Uploading...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Future<void> _upload() async {
    try {
      // If Provider may be absent, switch to read<UserAccess?> and handle nulls.
      // final ua = context.read<UserAccess>();

      // 1) Upload images if local files or file paths were provided, build image names list
      final depot =
          'Kel'; // TODO: replace with actual depot from user access or form
      final uploadedImageNames = await _prepareUploadImageNames(
        depot: depot,
        files: widget.imageFiles,
        pathsOrNames: widget.imageNames,
      );

      // 2) Post E-Docket with generated/collected imageNames
      final res = await _uploadEDocketToDatabase(
        model: widget.model,
        depot: depot,
        uploadedBy: 'Test User', // TODO: wire real user name
        employeeNo: 'EMP123', // TODO: wire real employee no
        errorTypes: widget.errorTypes,
        otherError: widget.otherError,
        remarks: widget.remarks,
        imageNames: uploadedImageNames,
      );
      if (!mounted) return;

      if (res.ok) {
        Navigator.of(context).pop<bool>(true);
        return;
      }

      // Show diagnostics when it fails
      final prettySent = const JsonEncoder.withIndent('  ').convert(res.sent);
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Upload failed'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Endpoint: ${res.uri}'),
                const SizedBox(height: 8),
                Text('HTTP status: ${res.status}'),
                const SizedBox(height: 8),
                const Text('Request payload:'),
                SelectableText(prettySent),
                const SizedBox(height: 8),
                const Text('Response body:'),
                SelectableText(res.body.isEmpty ? '(empty)' : res.body),
                if (res.error != null) ...[
                  const SizedBox(height: 8),
                  Text('Error: ${res.error}'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final text =
                    'POST ${res.uri}\n\nPayload:\n$prettySent\n\n'
                    'Status: ${res.status}\n\nBody:\n${res.body}';
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Diagnostics copied')),
                );
              },
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );

      Navigator.of(context).pop<bool>(false);
    } catch (e, st) {
      _d('Client exception: $e');
      _d(st);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Client error'),
          content: SelectableText(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      Navigator.of(context).pop<bool>(false);
    }
  }

  /// Prepare image names by uploading any provided files or file paths.
  /// If neither files nor paths are provided, returns an empty list.
  /// If only names are provided (no files), returns them as-is.
  Future<List<String>> _prepareUploadImageNames({
    required String depot,
    List<File>? files,
    List<String>? pathsOrNames,
  }) async {
    final List<File> toUpload = [];
    final List<String> passthroughNames = [];

    // Collect files from explicit files list
    if (files != null && files.isNotEmpty) {
      toUpload.addAll(files.where((f) => f.existsSync()));
    }

    // Collect files or names from pathsOrNames
    if (pathsOrNames != null && pathsOrNames.isNotEmpty) {
      for (final entry in pathsOrNames) {
        final f = File(entry);
        if (f.existsSync()) {
          toUpload.add(f);
        } else {
          // Treat as an already-existing image name on the server
          passthroughNames.add(entry);
        }
      }
    }

    // If nothing to upload, return passthrough names
    if (toUpload.isEmpty) return passthroughNames;

    // Generate base timestamp once per submission
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final base = '${depot}_${ts}';

    final List<String> uploadedNames = [];
    for (int i = 0; i < toUpload.length; i++) {
      final file = toUpload[i];
      final baseName = i == 0 ? base : '${base}_${i}';
      final ok = await _uploadSingleImage(file: file, imageBaseName: baseName);
      if (ok) {
        uploadedNames.add('$baseName.jpg');
      } else {
        _d('Image upload failed for file: ${file.path}');
      }
    }

    return [...uploadedNames, ...passthroughNames];
  }

  /// Upload a single image file to the new endpoint with provided base name (without extension)
  Future<bool> _uploadSingleImage({
    required File file,
    required String imageBaseName,
  }) async {
    try {
      final uri = Uri.parse(
        'http://124.43.181.243:8000/api/upload-testdocket/$imageBaseName.jpg',
      );
      _d('Uploading image to: $uri');

      final req = http.MultipartRequest('POST', uri);
      req.files.add(await http.MultipartFile.fromPath('image', file.path));

      final resp = await req.send().timeout(const Duration(seconds: 30));
      final body = await resp.stream.bytesToString();
      _d('Image upload status: ${resp.statusCode}');
      _d('Image upload body: $body');
      return resp.statusCode == 200;
    } catch (e) {
      _d('Image upload error: $e');
      return false;
    }
  }

  /// Performs the POST to your PHP endpoint and returns rich diagnostics.
  static Future<UploadResult> _uploadEDocketToDatabase({
    required EDocket model,
    required String depot,
    required String uploadedBy,
    required String employeeNo,
    required List<String> errorTypes,
    String? otherError,
    String? remarks,
    List<String>? imageNames,
  }) async {
    final now = DateTime.now();
    final uploadedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    final errorsCsv = errorTypes.join(',');
    final imagesCsv = (imageNames ?? const <String>[]).join(',');

    final Map<String, String> post = {
      // Model
      'docketNo': model.docketNo,
      'year': model.year ?? '',
      'accountNumber': model.accountNumber ?? '',
      'customerName': model.customerName,
      'address': model.address ?? '',
      'meterNumber': model.meterNumber ?? '',
      'meterReading': model.meterReading ?? '',
      'poleNumber': model.poleNumber ?? '',
      'dateTime': DateFormat('yyyy-MM-dd HH:mm:ss').format(model.date ?? now),

      // Context
      'depot': depot,
      'uploadedBy': uploadedBy,
      'employeeNo': employeeNo,
      'uploadedTime': uploadedTime,

      // Status
      'status': '0',

      // Errors
      'errorTypes': errorsCsv,
      'otherError': otherError ?? '',
      'remarks': remarks ?? '',

      // Attachments (names only)
      'imageNames': imagesCsv,
    };

    // Update if your path differs
    final uri = Uri.parse('https://powerprox.sltidc.lk/POSTEDocketX.php');

    try {
      _d('POST $uri');
      _d('Payload: $post');

      final resp = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: post,
          )
          .timeout(const Duration(seconds: 30));

      _d('Status: ${resp.statusCode}');
      _d('Headers: ${resp.headers}');
      _d(
        'Body: ${resp.body.length > 2000 ? resp.body.substring(0, 2000) + '…' : resp.body}',
      );

      bool ok = resp.statusCode == 200;
      String? err;

      // Accept either {"status":"success"} or {"success":true}
      try {
        final m = jsonDecode(resp.body);
        if (m is Map) {
          final okStatus = m['status']?.toString().toLowerCase() == 'success';
          final okSuccess = m['success'] == true;
          ok = ok && (okStatus || okSuccess);
          if (!ok) err = m['message']?.toString();
        } else {
          ok = false;
          err = 'Unexpected JSON structure';
        }
      } catch (_) {
        // Non-JSON: check for PHP error strings
        final low = resp.body.toLowerCase();
        final hasPhpErr =
            low.contains('fatal error') ||
            low.contains('warning') ||
            low.contains('notice') ||
            low.contains('mysqli');
        ok = ok && !hasPhpErr;
        if (!ok) err = 'PHP error in body';
      }

      return UploadResult(
        ok: ok,
        status: resp.statusCode,
        body: resp.body,
        uri: uri,
        sent: post,
        error: ok ? null : (err ?? 'Server did not return success'),
      );
    } on TimeoutException {
      return UploadResult(
        ok: false,
        status: 0,
        body: '',
        uri: uri,
        sent: post,
        error: 'Timeout',
      );
    } on SocketException catch (e) {
      return UploadResult(
        ok: false,
        status: 0,
        body: '',
        uri: uri,
        sent: post,
        error: 'Network: $e',
      );
    } catch (e) {
      return UploadResult(
        ok: false,
        status: 0,
        body: '',
        uri: uri,
        sent: post,
        error: e.toString(),
      );
    }
  }
}
