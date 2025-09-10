import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WorkersSummaryDetailsPage extends StatefulWidget {
  final String workerId;
  final String workerName;

  const WorkersSummaryDetailsPage({
    super.key,
    required this.workerId,
    required this.workerName,
  });

  @override
  State<WorkersSummaryDetailsPage> createState() =>
      _WorkersSummaryDetailsPageState();
}

class _WorkersSummaryDetailsPageState extends State<WorkersSummaryDetailsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> assignedDockets = [];
  Map<String, dynamic> docketDetailsMap = {}; // store docket details by ID
  double totalSalary = 0.0;

  // 🔹 Salary rates by docket type
  final Map<String, double> salaryRates = {
    'Service Line Maintenance': 20,
    'Meter Testing': 30,
    'Estimate': 50,
    'Per Visit': 10,
    'Pole Disconnection': 130,
    'Material Remove': 66,
    'Meter Replacement Only': 55,
    'Visit with Contractor': 44,
    'Pole Top Maintenance': 80,
  };

  @override
  void initState() {
    super.initState();
    fetchAssignments();
  }

  Future<void> fetchAssignments() async {
    setState(() => _isLoading = true);
    try {
      // 🔹 Step 1: Fetch all docket assignments
      final url = Uri.parse('https://powerprox.sltidc.lk/GETDocketAssignment2.php');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);

        if (result['status'] == 'success') {
          final List data = result['data'];

          assignedDockets = data.where((assignment) {
            // Check if this assignment belongs to the current worker
            // Since assignedPersons contains names like "test1 1", we need to check
            // if the worker name is in the assignedPersons field
            final assignedPersons = (assignment['assignedPersons'] ?? "").toString();
            
            // For now, let's also check if the workerId matches
            // You might need to adjust this logic based on your exact data structure
            return assignedPersons.contains(widget.workerId) || 
                   assignedPersons.contains(widget.workerName);
          }).map<Map<String, dynamic>>((a) {
            return {
              "assignmentID": a["assignmentID"],
              "docketID": a["docketID"],
              "assignedPersons": a["assignedPersons"],
              "assignedTime": a["assignedTime"],
              "uploadedBy": a["uploadedBy"],
              "uploadedTime": a["uploadedTime"],
              "completedTime": a["completedTime"],
            };
          }).toList();

          // 🔹 Step 2: Fetch docket details & calculate salaries
          await fetchDocketDetails();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchDocketDetails() async {
    try {
      final url = Uri.parse('https://powerprox.sltidc.lk/GETDocketDetails2.php');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        // Store details mapped by ID for quick lookup
        for (var d in data) {
          docketDetailsMap[d["ID"].toString()] = d;
        }

        // Calculate total salary
        double sum = 0.0;
        for (var docket in assignedDockets) {
          // 🔹 FIX: Use docketID to match with the details map
          final docketId = docket["docketID"].toString();
          final details = docketDetailsMap[docketId];
          
          if (details != null) {
            final type = details["DocketType"] ?? "Unknown";
            final salary = salaryRates[type] ?? 50.0; // default salary reduced to 50
            docket["docketType"] = type;
            docket["salary"] = salary;
            sum += salary;
          } else {
            // If no details found, still assign a default
            docket["docketType"] = "Unknown";
            docket["salary"] = 50.0;
            sum += 50.0;
          }
        }

        totalSalary = sum;
      } else {
        debugPrint("Server error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching docket details: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.workerName} - Dockets"),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : assignedDockets.isEmpty
              ? const Center(child: Text("No dockets assigned"))
              : Column(
                  children: [
                    // 🔹 Worker info header
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue.shade50,
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 40, color: Color(0xFF003366)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.workerName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF003366),
                                ),
                              ),
                              Text(
                                "Worker ID: ${widget.workerId}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                "${assignedDockets.length} Dockets Assigned",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: assignedDockets.length,
                        itemBuilder: (context, index) {
                          final docket = assignedDockets[index];
                          final isCompleted = docket["completedTime"] != null;
                          
                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              leading: Icon(
                                isCompleted ? Icons.check_circle : Icons.assignment,
                                color: isCompleted ? Colors.green : Colors.blue,
                                size: 32,
                              ),
                              title: Text(
                                "Docket ID: ${docket["docketID"]}",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    "Type: ${docket["docketType"] ?? "Unknown"}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text("Assigned: ${docket["assignedTime"] ?? "-"}"),
                                  Text("Uploaded by: ${docket["uploadedBy"] ?? "-"}"),
                                  const SizedBox(height: 8),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4, horizontal: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: isCompleted
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                    child: Text(
                                      isCompleted
                                          ? "✓ Completed: ${docket["completedTime"]}"
                                          : "⏳ Pending",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Text(
                                  "Rs. ${docket["salary"]?.toStringAsFixed(2) ?? "0.00"}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // 🔹 Total Salary at the bottom
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF003366),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Total Salary:",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Rs. ${totalSalary.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}