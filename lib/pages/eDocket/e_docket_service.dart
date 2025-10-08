import 'dart:convert';
import 'package:http/http.dart' as http;

import 'e_docket_model.dart';

class EDocketService {
  final String baseUrl;
  EDocketService({required this.baseUrl});

  Future<http.Response> submitEDocket(EDocket model) async {
    final url = Uri.parse('$baseUrl/e-dockets'); // TODO: adjust endpoint
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(model.toJson()),
    );
    return resp;
  }
}
