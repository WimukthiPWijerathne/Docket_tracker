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
      final url = Uri.parse('http://13.61.22.169:3000/workers');
      print('Fetching workers from: $url');
      
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode != 200) {
        // Handle non-200 status codes
        dynamic errorResponse;
        try {
          errorResponse = jsonDecode(response.body);
        } catch (e) {
          errorResponse = response.body;
        }
        
        final errorMessage = errorResponse is Map 
            ? errorResponse['message']?.toString() ?? 'Failed to load workers'
            : 'Server error: ${response.statusCode}';
            
        throw Exception(errorMessage);
      }
      
      // Process successful response
      final responseData = jsonDecode(response.body);
      List<dynamic> workersData = [];
      
      // Handle different response formats
      if (responseData is List) {
        workersData = responseData;
      } else if (responseData is Map) {
        if (responseData.containsKey('data')) {
          workersData = responseData['data'] is List ? responseData['data'] : [];
        } else if (responseData.containsKey('workers')) {
          workersData = responseData['workers'] is List ? responseData['workers'] : [];
        } else if (responseData.containsKey('status') && responseData['status'] == 'success') {
          workersData = responseData['data'] is List ? responseData['data'] : [];
        }
      }
      
      print('Found ${workersData.length} workers');
      
      allWorkers = workersData.map<Map<String, String>>((w) {
        try {
          final firstName = w['firstName']?.toString() ?? '';
          final lastName = w['lastName']?.toString() ?? '';
          
          print('Processing worker: $firstName $lastName | Depot: ${w['depot']}');
          
          return {
            'id': w['employeeNo']?.toString() ?? w['employeeId']?.toString() ?? '',
            'personID': w['personID']?.toString() ?? w['id']?.toString() ?? '',
            'name': '$firstName $lastName'.trim(),
            'depot': w['depot']?.toString() ?? 'Unknown',
            'role': w['role']?.toString() ?? w['designation']?.toString() ?? 'Worker',
          };
        } catch (e) {
          print('Error processing worker data: $e');
          return {
            'id': '',
            'personID': '',
            'name': 'Invalid Worker Data',
            'depot': 'Unknown',
            'role': 'Worker',
          };
        }
      }).where((worker) => worker['name'] != 'Invalid Worker Data').toList();
      
      filterWorkers(selectedDepot);
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
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 Depot Filter Dropdown
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Color(0xFF003366)),
                  const SizedBox(width: 8),
                  const Text(
                    "Filter by Depot: ",
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButton<String>(
                        value: selectedDepot,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: depots
                            .map((depot) => DropdownMenuItem(
                                  value: depot, 
                                  child: Text(depot),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) filterWorkers(value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 Workers count info
            if (!_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${filteredWorkers.length} workers in $selectedDepot",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (filteredWorkers.isNotEmpty)
                      Text(
                        "Tap a worker to view details",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),

            // 🔹 Workers Grid
            _isLoading
                ? const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : filteredWorkers.isEmpty
                    ? Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.group_off,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No workers found in $selectedDepot",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Try selecting a different depot",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                childAspectRatio: 1.2,
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
        // Debug print to check what we're passing
        print("Navigating to worker: ${worker["name"]} with ID: ${worker["id"]} or personID: ${worker["personID"]}");
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WorkersSummaryDetailsPage(
              // 🔹 Try personID first, fallback to employeeNo
              workerId: worker["personID"]?.isNotEmpty == true 
                  ? worker["personID"]! 
                  : worker["id"] ?? "",
              workerName: worker["name"] ?? "",
            ),
          ),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF003366),
                Color(0xFF004080),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        worker["role"] ?? "Worker",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  worker["name"] ?? "",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "Depot: ${worker["depot"]}",
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  "ID: ${worker["id"]}",
                  style: const TextStyle(fontSize: 10, color: Colors.white60),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 16,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Tap for details",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}