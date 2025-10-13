// lib/pages/viewDockets/updateDockets/httpUpdateDocketassignment.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// API client for updating DocketDetails rows.
class DocketUpdateApi {
  static const String endpoint =
      'https://powerprox.sltidc.lk/UPDATEDocketDetailsX.php';

  /// Update only the DocketType of a row.
  ///
  /// PHP expects:
  ///   - required: id  (int/string)
  ///   - optional: DocketType (string) + any other fields
  ///
  /// Returns true on success (or "warning" = no change).
  static Future<bool> updateDocketType({
    required String id,
    required String newType,
    String?
    uploadedBy, // maps to PHP's uploadedBy field if you want to track who made the change
  }) async {
    final payload = <String, dynamic>{
      'id': id, // <- lower-case id (required by your PHP)
      'DocketType': newType, // <- the field you want to change
      if (uploadedBy != null && uploadedBy.isNotEmpty)
        'uploadedBy':
            uploadedBy, // optional; PHP supports updating this column too
    };

    try {
      debugPrint('[DocketUpdateApi] POST $endpoint');
      debugPrint('[DocketUpdateApi] Payload: ${jsonEncode(payload)}');

      final resp = await http
          .post(
            Uri.parse(endpoint),
            headers: const {
              'Content-Type': 'application/json', // PHP accepts JSON or form
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));

      debugPrint('[DocketUpdateApi] Status: ${resp.statusCode}');
      debugPrint('[DocketUpdateApi] Body: ${resp.body}');

      if (resp.statusCode != 200) return false;

      // Parse JSON response from PHP
      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        // If for some reason non-JSON is returned, consider HTTP 200 as success
        // unless it clearly indicates an error.
        final bodyLower = resp.body.toLowerCase();
        if (bodyLower.contains('fatal error') ||
            bodyLower.contains('warning') &&
                !bodyLower.contains('no changes')) {
          return false;
        }
        return true;
      }

      final status = (decoded['status'] ?? '').toString().toLowerCase();
      // success -> true; warning (no rows changed) -> still true for UX;
      // error -> false
      if (status == 'success' || status == 'warning') {
        return true;
      }
      return false;
    } on TimeoutException {
      debugPrint('[DocketUpdateApi] Timeout');
      return false;
    } catch (e) {
      debugPrint('[DocketUpdateApi] Exception: $e');
      return false;
    }
  }

  /// Generic updater if you need to change multiple fields later.
  /// Example:
  ///   await DocketUpdateApi.updateFields(id: '123', fields: {
  ///     'AssignedTime': '1',
  ///     'DocketSerial': 'DS123456'
  ///   });
  static Future<bool> updateFields({
    required String id,
    required Map<String, dynamic> fields,
  }) async {
    final payload = {'id': id, ...fields};
    try {
      debugPrint('[DocketUpdateApi.updateFields] POST $endpoint');
      debugPrint(
        '[DocketUpdateApi.updateFields] Payload: ${jsonEncode(payload)}',
      );

      final resp = await http
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));

      debugPrint('[DocketUpdateApi.updateFields] Status: ${resp.statusCode}');
      debugPrint('[DocketUpdateApi.updateFields] Body: ${resp.body}');

      if (resp.statusCode != 200) return false;

      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        final bodyLower = resp.body.toLowerCase();
        if (bodyLower.contains('fatal error')) return false;
        return true;
      }
      final status = (decoded['status'] ?? '').toString().toLowerCase();
      return status == 'success' || status == 'warning';
    } catch (e) {
      debugPrint('[DocketUpdateApi.updateFields] Exception: $e');
      return false;
    }
  }

  /// Update location details for a docket
  static Future<bool> updateLocationDetails({
    required String id,
    required String locationDetails,
  }) async {
    return updateFields(id: id, fields: {'locationDetails': locationDetails});
  }
}
