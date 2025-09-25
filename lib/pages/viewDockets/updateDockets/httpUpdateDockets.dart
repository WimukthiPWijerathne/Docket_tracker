// lib/pages/viewDockets/updateDockets/httpUpdateDocketassignment.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// API client for updating DocketDetails rows.
class DocketUpdateApi {
  static const String endpoint =
      'https://powerprox.sltidc.lk/UPDATEDocketDetails2.php';

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
      debugPrint(
        '[DocketUpdateApi.updateFields] Body length: ${resp.body.length}',
      );

      if (resp.statusCode != 200) return false;

      // If we get here, the HTTP request was successful (200)
      // Now parse the response to determine if the database operation succeeded

      Map<String, dynamic>? decoded;
      try {
        decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        // Response is not JSON - check for common success/error indicators
        final bodyLower = resp.body.toLowerCase().trim();

        // Check for explicit error indicators
        if (bodyLower.contains('fatal error') ||
            bodyLower.contains('error') ||
            bodyLower.contains('failed') ||
            bodyLower.contains('exception')) {
          return false;
        }

        // Check for success indicators or assume success if no errors
        if (bodyLower.contains('success') ||
            bodyLower.contains('updated') ||
            bodyLower.contains('complete') ||
            bodyLower == '1' || // Common success response
            bodyLower == 'true' ||
            bodyLower.isEmpty) {
          // Empty response often means success
          debugPrint(
            '[DocketUpdateApi.updateFields] Returning true (non-JSON success indicator found)',
          );
          return true;
        }

        // If we can't determine, assume success since HTTP 200 was returned
        debugPrint(
          '[DocketUpdateApi.updateFields] Returning true (non-JSON, no clear error, HTTP 200)',
        );
        return true;
      }

      // Response is valid JSON - check status field
      final status = (decoded['status'] ?? '').toString().toLowerCase();
      if (status == 'success' || status == 'warning' || status == 'ok') {
        debugPrint(
          '[DocketUpdateApi.updateFields] Returning true (JSON status: $status)',
        );
        return true;
      }

      // Check for error indicators in JSON response
      if (status == 'error' || status == 'failed') {
        debugPrint(
          '[DocketUpdateApi.updateFields] Returning false (JSON status: $status)',
        );
        return false;
      }

      // If status field doesn't exist or is unclear, check other fields
      final message = (decoded['message'] ?? '').toString().toLowerCase();
      if (message.contains('success') || message.contains('updated')) {
        debugPrint(
          '[DocketUpdateApi.updateFields] Returning true (JSON message indicates success)',
        );
        return true;
      }

      // If we still can't determine and got HTTP 200, assume success
      debugPrint(
        '[DocketUpdateApi.updateFields] Returning true (assumed success from HTTP 200)',
      );
      return true;
    } catch (e) {
      debugPrint('[DocketUpdateApi.updateFields] Exception: $e');
      return false;
    }
  }
}
