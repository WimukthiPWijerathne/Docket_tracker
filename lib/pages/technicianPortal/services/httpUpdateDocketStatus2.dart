// lib/pages/viewDockets/updateDockets/updateDocketStatus.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Updates ONLY `status` in DocketDetails by `id`.
class DocketStatusApi {
  static const String endpoint =
      'https://powerprox.sltidc.lk/UPDATEDocketDetailsX.php';

  // Status codes (as strings in DB)
  static const String unassigned = '0';
  static const String assigned = '1';
  static const String completed = '2';
  static const String reassigned = '3';
  static const String issue = '4';
  static const String escalated = '4';

  /// Set status: payload = { id, status }
  static Future<bool> setStatus({
    required String id,
    required String statusCode,
  }) async {
    final payload = {'id': id, 'status': statusCode};

    try {
      debugPrint('[DocketStatusApi] POST $endpoint');
      debugPrint('[DocketStatusApi] Payload: ${jsonEncode(payload)}');

      final resp = await http
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));

      if (resp.statusCode != 200) return false;

      // Accept JSON {status: success|warning} or a non-error body.
      try {
        final m = jsonDecode(resp.body) as Map<String, dynamic>;
        final s = (m['status'] ?? '').toString().toLowerCase();
        return s == 'success' || s == 'warning';
      } catch (_) {
        final low = resp.body.toLowerCase();
        return !(low.contains('fatal error') || low.contains('error'));
      }
    } on TimeoutException {
      debugPrint('[DocketStatusApi] Timeout');
      return false;
    } catch (e) {
      debugPrint('[DocketStatusApi] Exception: $e');
      return false;
    }
  }

  // Shortcuts
  static Future<bool> markAssigned(String id) =>
      setStatus(id: id, statusCode: assigned);
  static Future<bool> markCompleted(String id) =>
      setStatus(id: id, statusCode: completed);
  static Future<bool> markReassigned(String id) =>
      setStatus(id: id, statusCode: reassigned);
  static Future<bool> markIssue(String id) =>
      setStatus(id: id, statusCode: issue);
  static Future<bool> markUnassigned(String id) =>
      setStatus(id: id, statusCode: unassigned);
  static Future<bool> markEscalated(String id) =>
      setStatus(id: id, statusCode: escalated);
}
