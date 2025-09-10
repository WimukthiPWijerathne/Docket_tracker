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

  // 🔹 Dummy salary rates by docket type
  final Map<String, double> salaryRates = {
   'Service Line Maintenance': 20,
    'Meter Testing':30,
    'Estimate':50,
    'Per Visit':10,
    'Pole Disconnection':130,
    'Material Remove':66,
    'Meter Replacement Only':55,
    'Visit with Contractor':44,
    'Pole Top Maintenance':80,
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
            final persons =
                (assignment['assignedPersons'] ?? "").toString().split(",");
            return persons.contains(widget.workerId);
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
    final url = Uri.parse('https://powerprox.sltidc.lk/GETDocketAssignment2.php');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body); // ✅ decode as List

      // Store details mapped by ID for quick lookup
      for (var d in data) {
        docketDetailsMap[d["ID"].toString()] = d;
      }

      // Calculate total salary
      double sum = 0.0;
      for (var docket in assignedDockets) {
        final details = docketDetailsMap[docket["docketID"]];
        if (details != null) {
          final type = details["DocketType"] ?? "Unknown";
          final salary = salaryRates[type] ?? 1000.0; // default salary
          docket["docketType"] = type;
          docket["salary"] = salary;
          sum += salary;
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : assignedDockets.isEmpty
              ? const Center(child: Text("No dockets assigned"))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: assignedDockets.length,
                        itemBuilder: (context, index) {
                          final docket = assignedDockets[index];
                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              leading: const Icon(Icons.assignment,
                                  color: Colors.blue),
                              title: Text(
                                  "Docket ID: ${docket["docketID"]} (${docket["docketType"] ?? "Unknown"})"),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Assigned: ${docket["assignedTime"] ?? "-"}"),
                                  Text("Uploaded by: ${docket["uploadedBy"] ?? "-"}"),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2, horizontal: 6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: docket["completedTime"] == null
                                          ? Colors.green
                                          : Colors.blue.withOpacity(0.2),
                                    ),
                                    child: Text(
                                      docket["completedTime"] == null
                                          ? "Pending"
                                          : "Completed: ${docket["completedTime"]}",
                                      style: TextStyle(
                                        color: docket["completedTime"] == null
                                            ? Colors.white
                                            : Colors.blue,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "Salary: Rs. ${docket["salary"]?.toStringAsFixed(2) ?? "0.00"}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // 🔹 Total Salary at the bottom
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.blueGrey.shade50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Total Salary:",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Rs. ${totalSalary.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
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
