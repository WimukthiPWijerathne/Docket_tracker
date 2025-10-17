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
        // Debug: Log the response data to check for unexpected completedAt values
        print('[DEBUG] WorkLog for docket $docketId: ${resp.body}');
        if (data is List && data.isNotEmpty) {
          final workLog = WorkLog.fromJson(data.first);
          if (workLog.completedAt != null && workLog.completedAt!.isNotEmpty) {
            print(
              '[DEBUG] Docket $docketId has completedAt: ${workLog.completedAt}',
            );
          }
          return workLog;
        } else if (data is Map<String, dynamic>) {
          final workLog = WorkLog.fromJson(data);
          if (workLog.completedAt != null && workLog.completedAt!.isNotEmpty) {
            print(
              '[DEBUG] Docket $docketId has completedAt: ${workLog.completedAt}',
            );
          }
          return workLog;
        }
      }
    } catch (e) {
      // ignore errors here; caller can fallback
    }
    return null;
  }
}
