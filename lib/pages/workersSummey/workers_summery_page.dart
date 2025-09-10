import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'worker_summery_detail.dart';

class WorkersSummaryPage extends StatefulWidget {
  const WorkersSummaryPage({super.key});

  @override
  State<WorkersSummaryPage> createState() => _WorkersSummaryPageState();
}

class _WorkersSummaryPageState extends State<WorkersSummaryPage> {
  String selectedDepot = "Kadana";
  bool _isLoading = true;
  List<Map<String, String>> allWorkers = [];
  List<Map<String, String>> filteredWorkers = [];

  final List<String> depots = ["Kadana", "Mahara", "Paliyagoda", "Wattala", "HQ"];

  @override
  void initState() {
    super.initState();
    fetchWorkers();
  }

  Future<void> fetchWorkers() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('https://powerprox.sltidc.lk/GETPeople2.php');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);

        if (result['status'] == 'success') {
          final List data = result['data'];

          allWorkers = data.map<Map<String, String>>((w) {
            return {
              "id": w['employeeNo']?.toString() ?? "", // employee ID
              "name": "${w['firstName'] ?? ""} ${w['lastName'] ?? ""}".trim(),
              "depot": w['depot']?.toString() ?? "Unknown",
              "role": w['role']?.toString() ?? "Worker",
            };
          }).toList();

          filterWorkers(selectedDepot);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? "Failed to load workers")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void filterWorkers(String depot) {
    setState(() {
      selectedDepot = depot;
      filteredWorkers =
          allWorkers.where((w) => w["depot"] == depot).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Workers Summary"),
        backgroundColor: const Color(0xFF003366),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 Depot Filter Dropdown
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const Text(
                    "Filter by Depot: ",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: selectedDepot,
                    items: depots
                        .map((depot) =>
                            DropdownMenuItem(value: depot, child: Text(depot)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) filterWorkers(value);
                    },
                  ),
                ],
              ),
            ),

            // 🔹 Workers Grid
            _isLoading
                ? const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = 1;
                        if (constraints.maxWidth > 600) {
                          crossAxisCount = 2; // Tablet
                        }
                        if (constraints.maxWidth > 900) {
                          crossAxisCount = 3; // Desktop
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.3,
                          ),
                          itemCount: filteredWorkers.length,
                          itemBuilder: (context, index) {
                            final worker = filteredWorkers[index];
                            return _buildWorkerCard(worker);
                          },
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // 🔹 Worker Card
  Widget _buildWorkerCard(Map<String, String> worker) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkersSummaryDetailsPage(
              workerId: worker["id"] ?? "",
              workerName: worker["name"] ?? "",
            ),
          ),
        );
      },
      child: Card(
        color: const Color(0xFF003366),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.person, size: 40, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                worker["name"] ?? "",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Depot: ${worker["depot"]}",
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
