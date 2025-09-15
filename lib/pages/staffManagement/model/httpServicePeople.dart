import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:leco_docket_tracker/pages/staffManagement/model/person.dart';


class PeopleService {
  static const String _base = 'https://powerprox.sltidc.lk';

  // TODO: change these to your actual PHP filenames if different
  static const String _getPeople = '$_base/GETPeople2.php';
  static const String _createPerson = '$_base/POSTPeople2.php';
  static const String _updatePerson = '$_base/UPDATEPeople2.php';

  Future<List<Person>> fetchPeople() async {
    final resp = await http.get(Uri.parse(_getPeople))
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) throw 'HTTP ${resp.statusCode}';

    final body = resp.body;
    try {
      final data = jsonDecode(body);
      if (data is List) {
        return data.map<Person>((e) => Person.fromJson(e as Map<String,dynamic>)).toList();
      } else if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map<Person>((e) => Person.fromJson(e as Map<String,dynamic>)).toList();
      }
      throw 'Unexpected payload';
    } catch (e) {
      debugPrint('[PeopleService] parse error: $e\n$body');
      rethrow;
    }
  }

  /// Create a new person (method name used by your page).
  Future<bool> createPerson({
    required String firstName,
    required String lastName,
    required String depot,
    required String employeeNo,
    required String designation,
    required String accessLevel,
    String available = 'Yes',
    String uuid = '',
  }) async {
    try {
      final payload = {
        'firstName': firstName,
        'lastName': lastName,
        'depot': depot,
        'employeeNo': employeeNo,
        'designation': designation,
        'accessLevel': accessLevel,
        'available': available,
        'uuid': uuid,
      };

      print('Sending to $_createPerson with payload: $payload');
      
      final resp = await http.post(
        Uri.parse(_createPerson),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      print('Response status: ${resp.statusCode}');
      print('Response body: ${resp.body}');

      if (resp.statusCode != 200) {
        print('Error: Server returned status code ${resp.statusCode}');
        return false;
      }

      try {
        final m = jsonDecode(resp.body);
        print('Parsed response: $m');
        
        final status = (m['status'] ?? '').toString().toLowerCase();
        final success = status == 'success' || status == 'ok' || m['success'] == true;
        
        if (!success) {
          print('Error from server: ${m['message'] ?? 'No error message provided'}');
        }
        
        return success;
      } catch (e) {
        print('Error parsing response: $e');
        // If backend returns plain text, accept HTTP 200 as success
        return true;
      }
    } catch (e) {
      print('Error in createPerson: $e');
      return false;
    }
  }

  Future<bool> updatePerson({
    required String personID,
    required Map<String, dynamic> fields,
  }) async {
    final payload = {'personID': personID, ...fields};

    final resp = await http.post(
      Uri.parse(_updatePerson),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) return false;

    try {
      final m = jsonDecode(resp.body);
      final status = (m['status'] ?? '').toString().toLowerCase();
      return status == 'success' || status == 'warning' || m['success'] == true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> setAvailability({
    required String personID,
    required bool active,
  }) {
    return updatePerson(
      personID: personID,
      fields: {'available': active ? 'Yes' : 'No'},
    );
  }
}



//v1
// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
//
// import 'person.dart';
//
// class PeopleService {
//   static const String _base = 'https://powerprox.sltidc.lk';
//
//   // TODO: change filenames if yours are different
//   static const String _getPeople = '$_base/GETPeople.php';
//   static const String _createPerson = '$_base/POSTPeople.php';
//   static const String _updatePerson = '$_base/UPDATEPeople.php';
//
//   Future<List<Person>> fetchPeople() async {
//     final resp = await http
//         .get(Uri.parse(_getPeople))
//         .timeout(const Duration(seconds: 30));
//     if (resp.statusCode != 200) throw 'HTTP ${resp.statusCode}';
//     try {
//       final data = jsonDecode(resp.body);
//       if (data is List) {
//         return data.map<Person>((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
//       } else if (data is Map && data['data'] is List) {
//         return (data['data'] as List)
//             .map<Person>((e) => Person.fromJson(e as Map<String, dynamic>))
//             .toList();
//       }
//       throw 'Unexpected payload';
//     } catch (e) {
//       debugPrint('[PeopleService] parse error: $e');
//       rethrow;
//     }
//   }
//
//   Future<bool> createPerson({
//     required String firstName,
//     required String lastName,
//     required String depot,
//     required String employeeNo,
//     required String designation,
//     required String accessLevel,
//     String available = 'Yes',
//     String uuid = '',
//   }) async {
//     final payload = {
//       'firstName': firstName,
//       'lastName': lastName,
//       'depot': depot,
//       'employeeNo': employeeNo,
//       'designation': designation,
//       'accessLevel': accessLevel,
//       'available': available,
//       'uuid': uuid,
//     };
//     final resp = await http.post(
//       Uri.parse(_createPerson),
//       headers: const {'Content-Type': 'application/json'},
//       body: jsonEncode(payload),
//     ).timeout(const Duration(seconds: 30));
//
//     if (resp.statusCode != 200) return false;
//     try {
//       final m = jsonDecode(resp.body);
//       final status = (m['status'] ?? '').toString().toLowerCase();
//       return status == 'success' || status == 'ok' || m['success'] == true;
//     } catch (_) {
//       // accept plain 200
//       return true;
//     }
//   }
//
//   Future<bool> updatePerson({
//     required String personID,
//     required Map<String, dynamic> fields,
//   }) async {
//     final payload = {'personID': personID, ...fields};
//     final resp = await http.post(
//       Uri.parse(_updatePerson),
//       headers: const {'Content-Type': 'application/json'},
//       body: jsonEncode(payload),
//     ).timeout(const Duration(seconds: 30));
//
//     if (resp.statusCode != 200) return false;
//     try {
//       final m = jsonDecode(resp.body);
//       final status = (m['status'] ?? '').toString().toLowerCase();
//       return status == 'success' || status == 'warning' || m['success'] == true;
//     } catch (_) {
//       return true;
//     }
//   }
//
//   Future<bool> setAvailability({
//     required String personID,
//     required bool active,
//   }) {
//     return updatePerson(
//       personID: personID,
//       fields: {'available': active ? 'Yes' : 'No'},
//     );
//   }
// }
