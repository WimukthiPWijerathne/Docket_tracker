import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../workersProfile/addworkers.dart';

class WorkerListPage extends StatefulWidget {
  final String loggedInRole;   // ✅ new

  const WorkerListPage({super.key, required this.loggedInRole});

  @override
  State<WorkerListPage> createState() => _WorkerListPageState();
}
class _WorkerListPageState extends State<WorkerListPage> {
  List<Map<String, String>> allWorkers = [];
  List<Map<String, String>> displayedWorkers = [];
  String selectedDepot = 'All';
  bool _isLoading = true;

  final List<String> depots = ['HQ', 'Kadana', 'Paliyagoda', 'Mahara', 'Wattala'];

  @override
  void initState() {
    super.initState(); 
    fetchWorkers();
  }

  // Fetch workers from backend
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
          // Handle success status with potential data
          workersData = responseData['data'] is List ? responseData['data'] : [];
        }
      }
      
      print('Found ${workersData.length} workers');
      
      allWorkers = workersData.map<Map<String, String>>((w) {
        try {
          // Extract worker data with null safety
          final firstName = w['firstName']?.toString() ?? '';
          final lastName = w['lastName']?.toString() ?? '';
          
          // Determine availability status
          String availableStatus = '1'; // Default to available
          if (w['available'] != null) {
            availableStatus = w['available'].toString().toLowerCase() == 'true' ? '1' : '0';
          } else if (w['isAvailable'] != null) {
            availableStatus = w['isAvailable'].toString().toLowerCase() == 'true' ? '1' : '0';
          } else if (w['status'] != null) {
            availableStatus = w['status'].toString().toLowerCase() == 'available' ? '1' : '0';
          }
          
          // Log worker details for debugging
          print('Worker: $firstName $lastName | Available: $availableStatus | Depot: ${w['depot']}');
          
          return {
            'personID': w['personID']?.toString() ?? w['id']?.toString() ?? '',
            'name': '$firstName $lastName'.trim(),
            'depot': w['depot']?.toString() ?? 'Unknown',
            'available': availableStatus,
            'employeeNo': w['employeeNo']?.toString() ?? w['employeeId']?.toString() ?? '',
          };
        } catch (e) {
          print('Error processing worker data: $e');
          return {
            'personID': '',
            'name': 'Invalid Worker Data',
            'depot': 'Unknown',
            'available': '0',
            'employeeNo': '',
          };
        }
      }).where((worker) => worker['name'] != 'Invalid Worker Data').toList();
      
      filterWorkers(selectedDepot);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void filterWorkers(String depot) {
    setState(() {
      selectedDepot = depot;
      if (depot == 'All') {
        displayedWorkers = List.from(allWorkers);
      } else {
        displayedWorkers =
            allWorkers.where((w) => w['depot'] == depot).toList();
      }
    });
  }

  String getDepotInitial(String depot) {
    switch (depot) {
      case 'Kadana':
        return 'K';
      case 'Paliyagoda':
        return 'P';
      case 'Mahara':
        return 'M';
      case 'Wattala':
        return 'W';
      case 'HQ':
        return 'H';
      default:
        return '';
    }
  }

  Widget buildAvailabilityStatus(String available) {
    bool isAvailable = available == "1";
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isAvailable ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          isAvailable ? "Available" : "Not Available",
          style: TextStyle(
            color: isAvailable ? Colors.green : Colors.red,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Workers Profile"),
        centerTitle: true,
        backgroundColor: Colors.teal,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Depot filter dropdown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text(
                    "Filter by depot: ",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: selectedDepot,
                    items: ['All', ...depots]
                        .map((depot) => DropdownMenuItem(
                            value: depot, child: Text(depot)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) filterWorkers(value);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Worker grid
            _isLoading
                ? const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GridView.builder(
                        itemCount: displayedWorkers.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 3 / 4,
                        ),
                        itemBuilder: (context, index) {
                          final worker = displayedWorkers[index];
                          final initial = getDepotInitial(worker['depot']!);
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundImage: const NetworkImage(
                                            "https://via.placeholder.com/100"),
                                      ),
                                      // Availability indicator on avatar
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: worker['available'] == "1" 
                                                ? Colors.green 
                                                : Colors.red,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "$initial. ${worker['name']}",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    worker['depot']!,
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Emp No: ${worker['employeeNo']}",
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  // Availability status
                                  buildAvailabilityStatus(worker['available']!),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
            // Add Worker button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final newWorker = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddWorkerPage(loggedInRole: widget.loggedInRole,),
                      ),
                    );

                    // Refresh list from backend after adding
                    if (newWorker != null) {
                      fetchWorkers();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text(
                    "Add Worker",
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}