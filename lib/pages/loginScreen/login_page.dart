import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../service/user_service.dart';
import '../HomePage/options_page.dart'; // import OptionsPage

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Map database roles to match hardcoded role types
  String? _mapDbRole(String? dbRole) {
    if (dbRole == null) return null;
    
    final role = dbRole.toLowerCase().trim();
    
    // Map various role names to standard role types
    if (role.contains('admin') || role.contains('chief') || role == 'ce') {
      return 'ce';
    } else if (role.contains('service') || role == 'cs' || role == 'css') {
      return 'cs';
    } else if (role.contains('clerk') || role == 'cr' || role == 'cro') {
      return 'cro';
    } else if (role == 'worker' || role == 'w') {
      return 'worker';
    }
    
    return null; // No matching role found
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        print('🔄 Attempting login for: $email');
        
        if (email.isEmpty || password.isEmpty) {
          throw Exception('Please enter both username and password');
        }
        
        // First check hardcoded users
        String? role;
        if (email == "ce" && password == "1") {
          role = 'ce';
        } else if (email == "admin" && password == "0") {
          role = 'ce';
        } else if (email == "cs" && password == "2") {
          role = 'cs';
        } else if (email == "cro" && password == "3") {
          role = 'cro';
        } else if (email == "w" && password == "4") {
          role = 'worker';
        } 
        // If not a hardcoded user, check database
        else {
          print('🔍 Checking database for user: $email');
          try {
            // Fetch all users and filter by username
            final response = await http.get(
              Uri.parse('http://13.61.22.169:3000/users'),
              headers: {'Accept': 'application/json'},
            );

            if (response.statusCode == 200) {
              final List<dynamic> allUsers = jsonDecode(response.body);
              print('🔍 Found ${allUsers.length} users in database');
              
              // Find user by username (case-insensitive)
              final user = allUsers.firstWhere(
                (u) => u['username']?.toString().toLowerCase() == email.toLowerCase(),
                orElse: () => null,
              );

              if (user != null) {
                print('👤 Found user in database');
                // Verify password (in a real app, use proper password hashing)
                if (user['password']?.toString() == password) {
                  role = _mapDbRole(user['role']?.toString());
                  print('✅ Database login successful. Role: ${user['role']} -> $role');
                } else {
                  print('❌ Incorrect password for user: $email');
                }
              } else {
                print('❌ User not found in database: $email');
              }
            } else {
              print('⚠️ Database error: ${response.statusCode}');
            }
          } catch (e) {
            print('⚠️ Error during database login: $e');
          }
        }
        
        if (role != null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful! Redirecting...'),
              backgroundColor: Color(0xFF2E7D32),
              duration: Duration(seconds: 1),
            ),
          );
          
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => OptionsPage(role: role!),
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid username or password'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('❌ Login error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during login: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LECO Docket Tracker')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _buildForm(context),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Card(
      elevation: 4,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/leco_logo.webp',
                  width: 80, height: 80, fit: BoxFit.contain),
              const SizedBox(height: 24),
              Text(
                'Docket Tracker',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Log in to continue',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter email' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter password' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Log In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
