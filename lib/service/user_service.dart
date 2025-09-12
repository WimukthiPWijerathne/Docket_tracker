import 'dart:convert';
import 'package:http/http.dart' as http;

class UserService {
  static const String _baseUrl = 'http://13.61.22.169:3000';
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // Map database roles to application role types
  static String _mapRoleToAppRole(String? dbRole) {
    if (dbRole == null) return 'worker'; // Default to most restricted access
    
    final role = dbRole.toLowerCase().trim();
    
    // Map various role names to standard role types
    if (role == 'admin' || role == 'chief engineer' || role == 'ce') {
      return 'ce';
    } else if (role == 'customer service' || role == 'customerservice' || role == 'cs' || role == 'css') {
      return 'cs';
    } else if (role == 'clerk' || role == 'clerk' || role == 'cr' || role == 'cro') {
      return 'cro';
    } else if (role == 'worker' || role == 'w') {
      return 'worker';
    }
    
    return role; // Return as-is if no mapping found (will be treated as worker)
  }

  // Login user by checking against the workers list
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      print('🔄 Attempting login for user: $username');
      print('🔑 Password length: ${password.length}');
      
      // First check hardcoded users
      print('🔍 Checking hardcoded users...');
      if (username == "ce" && password == "1") {
        print('✅ Logging in as Chief Engineer (ce/1)');
        return {'success': true, 'role': 'ce'};
      } else if (username == "admin" && password == "0") {
        print('✅ Logging in as Admin (admin/0)');
        return {'success': true, 'role': 'ce'};
      } else if (username == "cs" && password == "2") {
        print('✅ Logging in as Customer Service (cs/2)');
        return {'success': true, 'role': 'cs'};
      } else if (username == "cr" && password == "3") {
        print('✅ Logging in as Clerk (cr/3)');
        return {'success': true, 'role': 'cro'};
      } else if (username == "w" && password == "4") {
        print('✅ Logging in as Worker (w/4)');
        return {'success': true, 'role': 'worker'};
      } else {
        print('❌ No matching hardcoded user found');
      }
      
      // If not a hardcoded user, check against the workers API
      print('🔍 Checking workers API for user: $username');
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/workers?username=$username'),
          headers: {'Accept': 'application/json'},
        );

        print('🔑 Login response status: ${response.statusCode}');
        print('🔑 Login response body: ${response.body}');

        if (response.statusCode == 200) {
          final List<dynamic> workers = jsonDecode(response.body);
          if (workers.isNotEmpty) {
            final worker = workers.first;
            final dbRole = worker['role']?.toString();
            final appRole = _mapRoleToAppRole(dbRole);
            
            print('👤 Found user in database with role: $dbRole -> $appRole');
            
            // In a real app, verify the password here
            // For now, we'll just check if the username exists
            return {
              'success': true,
              'role': appRole,
              'originalRole': dbRole, // Keep original role for reference
              'userData': worker,     // Include the full worker data
            };
          } else {
            print('❌ No worker found with username: $username');
          }
        } else {
          print('❌ API error: ${response.statusCode} - ${response.reasonPhrase}');
        }
      } catch (e) {
        print('❌ Error checking workers API: $e');
      }
      
      return {
        'success': false,
        'message': 'Invalid username or password',
      };
      
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'message': 'An error occurred during login: $e',
      };
    }
  }

  // Create a new user
  static Future<Map<String, dynamic>> createUser({
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      print('Sending request to create user: $username');
      final response = await http.post(
        Uri.parse('$_baseUrl/users'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'role': role,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response headers: ${response.headers}');
      print('Response body: ${response.body}');

      dynamic responseData;
      try {
        responseData = jsonDecode(response.body);
        print('Parsed response data: $responseData');
      } catch (e) {
        print('Error parsing JSON: $e');
        // If JSON parsing fails, use the raw response body as a string
        responseData = response.body;
      }
      
      if (response.statusCode == 201) {
        return {
          'success': true,
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to create user',
          'data': responseData,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred: $e',
      };
    }
  }
}
