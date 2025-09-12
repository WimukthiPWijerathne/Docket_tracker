import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddWorkerPage extends StatefulWidget {
  final String loggedInRole; // ✅ Pass role from login (CE or CS)

  const AddWorkerPage({
    super.key,
    required this.loggedInRole,
  });

  @override
  State<AddWorkerPage> createState() => _AddWorkerPageState();
}

class _AddWorkerPageState extends State<AddWorkerPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();

  String selectedDepot = 'Kadana';
  String? selectedRole; // ✅ role selection
  bool _isLoading = false;

  final List<String> depots = ['Kadana', 'Paliyagoda', 'Mahara', 'Wattala'];

  // ✅ Available roles depending on logged-in role
  List<String> getRoleOptions() {
    if (widget.loggedInRole == "ce") {
      return ["CS", "CRO", "Worker"];
    } else if (widget.loggedInRole == "cs") {
      return ["CRO", "Worker"];
    } else {
      return ["Worker"]; // fallback
    }
  }

  Future<void> submitWorker() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final body = {
        "firstName": _firstNameController.text.trim(),
        "lastName": _lastNameController.text.trim(),
        "employeeNo": _employeeIdController.text.trim(),
        "depot": selectedDepot,
        "role": selectedRole ?? "Worker", // ✅ send role
      };

      final response = await http.post(
        Uri.parse('http://13.61.22.169:3000/workers'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Log the full response for debugging
        print('Add worker response: $data');
        
        // Check for success in different response formats
        if (data['success'] == true || 
            data['status'] == 'success' ||
            (data['message']?.toString().toLowerCase().contains('added') ?? false)) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Worker ${body['firstName']} ${body['lastName']} added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Close the dialog after a short delay
          await Future.delayed(const Duration(seconds: 1));
          
          // Return to previous screen with the new worker data
          if (mounted) {
            Navigator.pop(context, {
              "name": "${body['firstName']} ${body['lastName']}".trim(),
              "depot": selectedDepot,
              "employeeNo": body['employeeNo'],
              "designation": body['role'],
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add worker: ${data['message'] ?? 'Unknown error'}')),
          );
          print('Failed to add worker. Response: $data');
        }
      } else {
        final errorBody = response.body.isNotEmpty ? jsonDecode(response.body) : 'No response body';
        print('Server error ${response.statusCode}: $errorBody');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error ${response.statusCode}: ${errorBody.toString().substring(0, 100)}...")),
        );
      }
    } on TimeoutException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Request timed out. Please try again.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _employeeIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleOptions = getRoleOptions();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add New Worker"),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // First Name
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: "First Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter the first name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Last Name
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: "Last Name",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter the last name";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Employee ID
              TextFormField(
                controller: _employeeIdController,
                decoration: const InputDecoration(
                  labelText: "Employee ID",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter the employee ID";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Depot dropdown
              DropdownButtonFormField<String>(
                value: selectedDepot,
                decoration: const InputDecoration(
                  labelText: "Select Depot",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
                items: depots
                    .map((depot) => DropdownMenuItem(
                          value: depot,
                          child: Text(depot),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedDepot = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // ✅ Role dropdown
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(
                  labelText: "Select Role",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
                items: roleOptions
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(role),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedRole = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please select a role";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            submitWorker();
                          }
                        },
                  icon: const Icon(Icons.add),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Add Worker"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
