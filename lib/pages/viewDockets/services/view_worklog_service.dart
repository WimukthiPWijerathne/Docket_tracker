import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/WorkLog.dart';

class ViewWorkLogService {
  static const String baseUrl = 'https://powerprox.sltidc.lk';
  static String get getWorkLogUrl => '$baseUrl/GETDocketWorkLog.php';

  /// Fetch the first WorkLog for the given docketId (or null if none)
  static Future<WorkLog?> getWorkLogForDocket(String docketId) async {
    try {
      final url = '$getWorkLogUrl?docketID=${Uri.encodeComponent(docketId)}';
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List && data.isNotEmpty) {
          return WorkLog.fromJson(data.first);
        } else if (data is Map<String, dynamic>) {
          return WorkLog.fromJson(data);
        }
      }
    } catch (e) {
      // ignore errors here; caller can fallback
    }
    return null;
  }
}
