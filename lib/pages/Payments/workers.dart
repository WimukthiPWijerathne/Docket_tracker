import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../Payments//payments.dart';

class WorkersSummaryPage extends StatefulWidget {
  const WorkersSummaryPage({super.key});

  @override
  State<WorkersSummaryPage> createState() => _WorkersSummaryPageState();
}

class _WorkersSummaryPageState extends State<WorkersSummaryPage> {
  // Available branches and their depots
  final Map<String, List<String>> branchDepots = {
    'Kelaniya': ['Wattala', 'Kandana', 'Mahara', 'Dalugama'],
    'Kotte': ['Pitakotte', 'Kolonnawa', 'Kotikawatta'],
    'Nugegoda': ['Boralesgamuwa', 'Nugegoda', 'Maharagama'],
    'Moratuwa': [
      'Moratuwa North',
      'Moratuwa South',
      'Keselwatta',
      'Panadura',
      'Koralawella',
    ],
    'Kalutara': ['Payagala', 'Kalutara', 'Aluthgama'],
    'Negombo': ['Negambo', 'Seeduwa', 'Ja-Ela'],
    'Galle': ['Ambalangoda', 'Hikkaduwa', 'Galle'],
    'Head Office': ['Head Office'],
  };

  // Available branches (for dropdown)
  List<String> get branches => branchDepots.keys.toList();

  // Selected filters
  String selectedBranch = 'Kelaniya';
  String selectedDepot = 'All Depots';

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isLoading = true;
  List<Map<String, String>> allWorkers = [];
  List<Map<String, String>> filteredWorkers = [];

  // Get depots for current branch including "All Depots" option
  List<String> get availableDepots => [
    'All Depots',
    ...branchDepots[selectedBranch] ?? [],
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        filterWorkers();
      });
    });
    fetchWorkers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              "personID":
                  w['personID']?.toString() ?? "", // personID for assignments
              "name": "${w['firstName'] ?? ""} ${w['lastName'] ?? ""}".trim(),
              "depot": w['depot']?.toString() ?? "Unknown",
              "role": w['designation']?.toString() ?? "Worker",
            };
          }).toList();

          filterWorkers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? "Failed to load workers"),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Server error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void filterWorkers() {
    setState(() {
      // First, filter by branch/depot
      List<Map<String, String>> tempFiltered;

      if (selectedDepot == 'All Depots') {
        // Show all workers from the selected branch's depots
        List<String> branchDepotList = branchDepots[selectedBranch] ?? [];
        tempFiltered = allWorkers
            .where((w) => branchDepotList.contains(w["depot"]))
            .toList();
      } else {
        // Show workers from the specific depot
        tempFiltered = allWorkers
            .where((w) => w["depot"] == selectedDepot)
            .toList();
      }

      // Then, apply search filter if query is not empty
      if (_searchQuery.isNotEmpty) {
        filteredWorkers = tempFiltered.where((worker) {
          final name = worker["name"]?.toLowerCase() ?? '';
          final id = worker["id"]?.toLowerCase() ?? '';
          final personId = worker["personID"]?.toLowerCase() ?? '';
          final depot = worker["depot"]?.toLowerCase() ?? '';
          final role = worker["role"]?.toLowerCase() ?? '';

          return name.contains(_searchQuery) ||
              id.contains(_searchQuery) ||
              personId.contains(_searchQuery) ||
              depot.contains(_searchQuery) ||
              role.contains(_searchQuery);
        }).toList();
      } else {
        filteredWorkers = tempFiltered;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Technician Payments",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // 🔹 Filters Section with improved design
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header with icon
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.filter_list_rounded,
                            color: Color(0xFF003366),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Search & Filters',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF003366),
                              ),
                            ),
                            Text(
                              'Find technicians quickly',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Bar
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by name, ID, depot, or role...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF003366),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFFFD700),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Branch and Depot Filters Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildFilterDropdown(
                                'Branch',
                                selectedBranch,
                                branches,
                                (value) {
                                  setState(() {
                                    selectedBranch = value!;
                                    selectedDepot =
                                        'All Depots'; // Reset depot when branch changes
                                    filterWorkers();
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildFilterDropdown(
                                'Depot',
                                selectedDepot,
                                availableDepots,
                                (value) {
                                  setState(() {
                                    selectedDepot = value!;
                                    filterWorkers();
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 🔹 Workers count info with improved design
            if (!_isLoading)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF003366),
                      const Color(0xFF003366).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF003366).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _searchQuery.isNotEmpty
                            ? Icons.search_rounded
                            : Icons.people_rounded,
                        color: const Color(0xFF003366),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${filteredWorkers.length}",
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _searchQuery.isNotEmpty
                                ? "Results for \"$_searchQuery\""
                                : selectedDepot == 'All Depots'
                                ? "Workers in $selectedBranch"
                                : "Workers in $selectedDepot",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (filteredWorkers.isNotEmpty)
                      Icon(
                        Icons.touch_app_rounded,
                        color: Colors.white.withOpacity(0.7),
                        size: 24,
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
                            _searchQuery.isNotEmpty
                                ? Icons.search_off
                                : Icons.group_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? "No workers found for \"$_searchQuery\""
                                : "No workers found in ${selectedDepot == 'All Depots' ? '$selectedBranch branch' : selectedDepot}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? "Try a different search term"
                                : "Try selecting a different ${selectedDepot == 'All Depots' ? 'branch' : 'depot'}",
                            textAlign: TextAlign.center,
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
                                childAspectRatio:
                                    1.5, // Adjusted for better proportions
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

  // 🔹 Improved Compact Worker Card
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF003366).withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top colored header bar
            Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF003366), Color(0xFFFFD700)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Icon and Badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003366).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 24,
                            color: Color(0xFF003366),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withOpacity(0.2),
                            border: Border.all(
                              color: const Color(0xFFFFD700),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            worker["role"] ?? "Worker",
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF003366),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Worker Name
                    Text(
                      worker["name"] ?? "Unknown",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003366),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Depot
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            worker["depot"] ?? "Unknown",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Employee ID
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.badge_rounded,
                            size: 14,
                            color: Colors.amber.shade700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          worker["id"] ?? "",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // View Button
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF003366).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.visibility_rounded,
                            size: 14,
                            color: const Color(0xFF003366),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "View Details",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF003366),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: const Color(0xFF003366),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Improved Filter Dropdown Builder
  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF003366),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFFFFD700).withOpacity(0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF003366),
              ),
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Row(
                    children: [
                      Icon(
                        option.contains('All')
                            ? Icons.dashboard_rounded
                            : Icons.location_on_rounded,
                        size: 16,
                        color: const Color(0xFF003366),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          option,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
