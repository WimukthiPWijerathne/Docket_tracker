import 'package:flutter/material.dart';
import 'dart:convert';
import '../../service/user_service.dart';

class NewUserDetailForm extends StatefulWidget {
  const NewUserDetailForm({super.key});

  @override
  State<NewUserDetailForm> createState() => _NewUserDetailFormState();
}

class _NewUserDetailFormState extends State<NewUserDetailForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'worker';

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New User'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                ),
                items: const [
                  DropdownMenuItem(value: 'ce', child: Text('Chief Engineer (CE)')),
                  DropdownMenuItem(value: 'css', child: Text('Customer Service (CS)')),
                  DropdownMenuItem(value: 'cro', child: Text('Clerk (CRO)')),
                  DropdownMenuItem(value: 'worker', child: Text('Field Worker')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a role';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Helper method to clear form fields
                    void clearForm() {
                      // Clear controllers first
                      _usernameController.clear();
                      _emailController.clear();
                      _passwordController.clear();
                      
                      // Reset form state
                      if (_formKey.currentState != null) {
                        _formKey.currentState!.reset();
                      }
                      
                      // Update the role in state
                      if (mounted) {
                        setState(() {
                          _selectedRole = 'worker';
                        });
                      }
                      
                      // Unfocus any focused fields
                      FocusScope.of(context).requestFocus(FocusNode());
                    }

                    // Helper method to show error message
                    void showError(String message) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }

                    // Helper method to show success message
                    void showSuccess() {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User created successfully!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }

                    if (!_formKey.currentState!.validate()) return;

                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final loadingSnackBar = SnackBar(
                      content: const Row(
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(width: 16),
                          Text('Creating user...'),
                        ],
                      ),
                      duration: const Duration(minutes: 1),
                    );

                    try {
                      // Show loading indicator
                      scaffoldMessenger.showSnackBar(loadingSnackBar);

                      final response = await UserService.createUser(
                        username: _usernameController.text.trim(),
                        email: _emailController.text.trim(),
                        password: _passwordController.text,
                        role: _selectedRole,
                      );

                      // Hide loading indicator
                      scaffoldMessenger.hideCurrentSnackBar();

                      if (response['success'] == true || response['data'] != null) {
                        // Clear form first
                        clearForm();
                        // Then show success message
                        if (context.mounted) {
                          showSuccess();
                        }
                      } else {
                        // Parse error message from API response
                        String errorMessage = 'Failed to create user';
                        final errorData = response['data'] ?? response['message'];
                        
                        if (errorData is Map) {
                          final errors = errorData.entries
                              .where((e) => e.value != null)
                              .map((e) => '${e.key}: ${e.value}')
                              .join('\n');
                          if (errors.isNotEmpty) {
                            errorMessage = errors;
                          }
                        } else if (errorData is String) {
                          errorMessage = errorData;
                        }
                        
                        showError(errorMessage);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        scaffoldMessenger.hideCurrentSnackBar();
                        showError('Network error: ${e.toString()}');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Create User'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}