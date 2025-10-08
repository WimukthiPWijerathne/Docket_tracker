// lib/pages/loginScreen/fetchUserAccess.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserAccess extends ChangeNotifier {
  int? accessLevel;
  String? userDesignation;
  String? username;
  String? uuid;
  String? employeeNumber;
  String? depot;

  bool isLoading = false;
  String? error;
  bool isRegistered = false; // <- UUID exists in DB?

  Future<bool> fetchUserAccess(String userUID) async {
    const url = "https://powerprox.sltidc.lk/GETPeopleX.php";
    uuid = userUID;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        error = 'HTTP ${resp.statusCode}';
        _setGuest();
        return isRegistered = false;
      }

      final decoded = json.decode(resp.body);

      // Normalize into a list of maps
      List<Map<String, dynamic>> rows;
      if (decoded is List) {
        rows = decoded.cast<Map<String, dynamic>>();
      } else if (decoded is Map<String, dynamic>) {
        final inner = (decoded['people'] ?? decoded['data'] ?? decoded['results'] ?? decoded['records']);
        if (inner is List) {
          rows = inner.cast<Map<String, dynamic>>();
        } else {
          rows = [decoded.cast<String, dynamic>()];
        }
      } else {
        _setGuest();
        return isRegistered = false;
      }

      // Find by UUID (case-insensitive key)
      Map<String, dynamic>? match;
      for (final row in rows) {
        final m = {for (final e in row.entries) e.key.toLowerCase(): e.value};
        if ((m['uuid']?.toString() ?? '') == userUID) { match = row; break; }
      }

      if (match == null) {
        debugPrint('UUID $userUID not found → Pending approval.');
        _setGuest();
        return isRegistered = false;
      }

      // Fill other details only when UUID exists
      String? read(List<String> keys) {
        for (final k in keys) {
          final real = match!.keys.firstWhere(
                (kk) => kk.toLowerCase() == k.toLowerCase(),
            orElse: () => '',
          );
          if (real.isNotEmpty) return match![real]?.toString();
        }
        return null;
      }

      username        = read(['firstName','firstname']) ?? 'User';
      userDesignation = read(['designation']) ?? '';
      depot           = read(['depot']) ?? '';
      employeeNumber  = read(['employeeNo','employeeno']);
      accessLevel     = int.tryParse(read(['accessLevel','accesslevel']) ?? '0') ?? 0;

      return isRegistered = true;
    } catch (e) {
      error = 'Fetch failed: $e';
      _setGuest();
      return isRegistered = false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _setGuest() {
    userDesignation = 'Guest';
    accessLevel = 0;
  }
}


//v2
// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
//
// class UserAccess extends ChangeNotifier {
//   int? accessLevel;
//   String? userDesignation;
//   String? username;
//   String? uuid;
//   String? employeeNumber;
//   String? depot;
//
//   bool isLoading = false;
//   String? error;
//
//   Future<void> fetchUserAccess(String userUID) async {
//     const url = "https://powerprox.sltidc.lk/GETPeople.php";
//     uuid = userUID;
//     isLoading = true;
//     error = null;
//     notifyListeners();
//
//     try {
//       final resp = await http
//           .get(Uri.parse(url))
//           .timeout(const Duration(seconds: 12));
//
//       if (resp.statusCode != 200) {
//         error = 'HTTP ${resp.statusCode}';
//         _fallbackToGuest();
//         return;
//       }
//
//       final decoded = json.decode(resp.body);
//
//       // Get a List<Map<String,dynamic>> out of the response, whatever its shape.
//       List<Map<String, dynamic>> rows;
//       if (decoded is List) {
//         rows = decoded.cast<Map<String, dynamic>>();
//       } else if (decoded is Map<String, dynamic>) {
//         final candidates = ['data', 'results', 'records', 'people'];
//         dynamic inner;
//         for (final k in candidates) {
//           final v = decoded[k];
//           if (v is List) {
//             inner = v;
//             break;
//           }
//         }
//         if (inner == null) {
//           // As a last resort, if the map itself looks like a single row.
//           if (decoded.values.any((v) => v is Map || v is List)) {
//             error = 'Unexpected payload shape';
//             _fallbackToGuest();
//             return;
//           } else {
//             rows = [decoded];
//           }
//         } else {
//           rows = List<Map<String, dynamic>>.from(inner);
//         }
//       } else {
//         error = 'Unsupported JSON type';
//         _fallbackToGuest();
//         return;
//       }
//
//       // Find the row by uuid (case-insensitive key match).
//       Map<String, dynamic>? match;
//       for (final row in rows) {
//         final lower = <String, dynamic>{
//           for (final e in row.entries) e.key.toLowerCase(): e.value
//         };
//         if ((lower['uuid']?.toString() ?? '') == userUID) {
//           match = row;
//           break;
//         }
//       }
//
//       if (match == null) {
//         // No UUID in DB yet → default to guest
//         _fallbackToGuest();
//         debugPrint('No user with uuid=$userUID found; defaulting to Guest.');
//         return;
//       }
//
//       // Read fields (support both camel/lower).
//       String? _s(Iterable<String> keys) {
//         for (final k in keys) {
//           if (match!.containsKey(k)) return match![k]?.toString();
//           final alt = k.toLowerCase();
//           if (match!.keys.map((e) => e.toLowerCase()).contains(alt)) {
//             final realKey =
//             match!.keys.firstWhere((e) => e.toLowerCase() == alt);
//             return match![realKey]?.toString();
//           }
//         }
//         return null;
//       }
//
//       final lvlStr = _s(['accessLevel', 'accesslevel']) ?? '0';
//       accessLevel = int.tryParse(lvlStr) ?? 0;
//       depot = _s(['depot']);
//       userDesignation = _s(['designation']);
//       username = _s(['firstName', 'firstname']) ?? 'User';
//       employeeNumber = _s(['employeeNo', 'employeeno']);
//
//       debugPrint('User Access Level: $accessLevel, user: $username');
//     } catch (e) {
//       error = 'Fetch failed: $e';
//       _fallbackToGuest();
//       debugPrint('Error fetching user access: $e');
//     } finally {
//       isLoading = false;
//       notifyListeners();
//     }
//   }
//
//   void _fallbackToGuest() {
//     userDesignation = 'Guest';
//     accessLevel = 0;
//     // keep uuid as-is
//   }
// }


//v1
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
//
//
// class UserAccess extends ChangeNotifier {
//   int? accessLevel; // Variable to store userPortal access level
//   String? userDesignation;
//   String? username;
//   String? uuid;
//   String? employeeNumber;
//   String? depot;
//
//
//
//   Future<void> fetchUserAccess(String userName) async {
//     var url = "https://powerprox.sltidc.lk/GETPeople.php";
//     print('I am at the start of FetechUserAcccss');
//     print(userName);
//     uuid=userName;
//
//     try {
//       final response = await http.get(Uri.parse(url));
//       // print('Response status: ${response.statusCode}');
//       // print('Response body: ${response.body}');
//       if (response.statusCode == 200) {
//         var dataReceived = json.decode(response.body);
//         // print('Data received: $dataReceived');
//         var results = dataReceived
//             .where((data) => data['UUID'] == userName)
//             .toList();
//         // print('Filtered results: $results');
//         if (results.isNotEmpty) {
//           accessLevel = int.tryParse(results.first['accessLevel'] ?? '');
//           depot = results.first['depot'];
//           userDesignation = results.first['designation'];
//           username = results.first['firstname'];
//           print('User Access Level: $accessLevel');
//         } else {
//           userDesignation = 'Guest';
//           accessLevel = 0; // If userPortal not found, set access level to zero
//           print('No User Found');
//         }
//       } else {
//         throw Exception('Failed to load data: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error fetching userPortal access: $e');
//       throw Exception('Failed to load data');
//     }
//
//     // Notify listeners after updating the data
//     notifyListeners();
//   }
//
//
// }
//
