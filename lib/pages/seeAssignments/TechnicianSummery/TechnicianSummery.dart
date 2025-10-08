import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../services/worker_service.dart';
import '../../../models/worker_model.dart';
import '../../../service/assigned_docket_service.dart';
import '../../../models/assigned_docket.dart';
import '../../../models/dockets.dart';
import '../../../models/WorkLog.dart';

class TechnicianSummaryPage extends StatefulWidget {
  const TechnicianSummaryPage({super.key});

  @override
  State<TechnicianSummaryPage> createState() => _TechnicianSummaryPageState();
}

class _TechnicianSummaryPageState extends State<TechnicianSummaryPage> {
  static const Color _primaryColor = Color(0xFF003366);
  static const Color _completedColor = Color(0xFF4CAF50);
  static const Color _assignedColor = Color(0xFFFF9800);

  // Branch and Depot constants
  static const List<String> kBranches = [
    'All',
    'Head Office',
    'Kotte',
    'Nugegoda',
    'Moratuwa',
    'Kalutara',
    'Kelaniya',
    'Negombo',
    'Galle',
    'Other',
  ];

  static const List<String> kDepots = [
    'All',
    'Head Office',
    'Wattala',
    'Kandana',
    'Mahara',
    'Dalugama',
    'Pitakotte',
    'Kolonnawa',
    'Kotikawatta',
    'Boralesgamuwa',
    'Nugegoda',
    'Maharagama',
    'Moratuwa North',
    'Moratuwa South',
    'Keselwatta',
    'Panadura',
    'Koralawella',
    'Payagala',
    'Kalutara',
    'Aluthgama',
    'Negombo',
    'Seeduwa',
    'Ja-Ela',
    'Ambalangoda',
    'Hikkaduwa',
    'Galle',
    'Other',
  ];

  static const Map<String, List<String>> kBranchDepots = {
    'All': ['All'],
    'Kelaniya': ['All', 'Wattala', 'Kandana', 'Mahara', 'Dalugama', 'Other'],
    'Kotte': ['All', 'Pitakotte', 'Kolonnawa', 'Kotikawatta', 'Other'],
    'Nugegoda': ['All', 'Boralesgamuwa', 'Nugegoda', 'Maharagama', 'Other'],
    'Moratuwa': [
      'All',
      'Moratuwa North',
      'Moratuwa South',
      'Keselwatta',
      'Panadura',
      'Koralawella',
      'Other',
    ],
    'Kalutara': ['All', 'Payagala', 'Kalutara', 'Aluthgama', 'Other'],
    'Negombo': ['All', 'Negombo', 'Seeduwa', 'Ja-Ela', 'Other'],
    'Galle': ['All', 'Ambalangoda', 'Hikkaduwa', 'Galle', 'Other'],
    'Head Office': ['All', 'Head Office'],
    'Other': ['All', 'Other'],
  };

  // Filter state
  String _selectedBranch = 'All';
  String _selectedDepot = 'All';
  String _selectedTechnician = 'All';
  List<String> _availableTechnicians = ['All'];
  Map<String, Worker> _workerMap = {}; // Map of ID to Worker for easy lookup

  // Data
  final WorkerService _workerService = WorkerService();
  List<Worker> _allWorkers = [];
  List<Worker> _filteredWorkers = [];
  bool _loading = true;
  String? _error;

  final AssignedDocketService _assignedSvc = AssignedDocketService();
  List<AssignedDocket> _allAssignments = [];

  // Chart data
  bool _chartLoading = false;
  String? _chartError;
  Map<int, int> _monthlyCompleted = {};
  Map<int, int> _monthlyInProgress = {}; // In-progress count
  List<Docket> _allDockets = [];
  List<WorkLog> _allWorkLogs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _workerService.fetchWorkers(),
        _assignedSvc.fetchAssignedDockets(),
        _fetchAllDockets(),
        _fetchAllWorkLogs(),
      ]);

      final workers = results[0] as List<Worker>;
      final assignments = results[1] as List<AssignedDocket>;
      final dockets = results[2] as List<Docket>;
      final workLogs = results[3] as List<WorkLog>;

      final techIds = <String>{'All'};
      final workerMap = <String, Worker>{};
      for (final w in workers) {
        final id = (w.employeeNo.isNotEmpty ? w.employeeNo : w.personID).trim();
        if (id.isNotEmpty) {
          techIds.add(id);
          workerMap[id] = w; // Store worker in map
        }
      }

      print('=== WORKER DATA DEBUG ===');
      print('Total workers loaded: ${workers.length}');
      if (workers.isNotEmpty) {
        print('--- Sample Workers ---');
        for (int i = 0; i < (workers.length > 5 ? 5 : workers.length); i++) {
          final w = workers[i];
          final id = (w.employeeNo.isNotEmpty ? w.employeeNo : w.personID)
              .trim();
          print(
            'Worker $i: name="${w.name}", employeeNo="${w.employeeNo}", personID="${w.personID}", extracted ID="$id"',
          );
        }
      }
      print('=== END WORKER DEBUG ===');

      setState(() {
        _allWorkers = workers;
        _allAssignments = assignments;
        _allDockets = dockets;
        _allWorkLogs = workLogs;
        _availableTechnicians = techIds.toList()..sort();
        _workerMap = workerMap;
      });

      _applyFilters();
      await _loadChartData();
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _allWorkers = [];
        _filteredWorkers = [];
        _allAssignments = [];
        _allDockets = [];
        _allWorkLogs = [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Fetch all dockets with retry logic like depot summary service
  Future<List<Docket>> _fetchAllDockets({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .get(
              Uri.parse('https://powerprox.sltidc.lk/GETDocketDetails2.php'),
              headers: {'Accept': 'application/json'},
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Request timed out after 30 seconds');
              },
            );

        if (response.statusCode == 200) {
          final String responseBody = response.body;
          if (responseBody.isEmpty) {
            if (attempt < maxRetries) continue;
            return [];
          }

          dynamic jsonData = json.decode(responseBody);
          if (jsonData is List) {
            return jsonData
                .map((json) => Docket.fromJson(json as Map<String, dynamic>))
                .toList();
          } else if (jsonData is Map<String, dynamic>) {
            if (jsonData.containsKey('data') && jsonData['data'] is List) {
              List dataList = jsonData['data'];
              return dataList
                  .map((json) => Docket.fromJson(json as Map<String, dynamic>))
                  .toList();
            } else {
              return [Docket.fromJson(jsonData)];
            }
          }
          return [];
        } else {
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
          return [];
        }
      } catch (e) {
        print('Error fetching dockets on attempt $attempt: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        return [];
      }
    }
    return [];
  }

  // Fetch all work logs with retry logic like depot summary service
  Future<List<WorkLog>> _fetchAllWorkLogs({int maxRetries = 3}) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .get(
              Uri.parse('https://powerprox.sltidc.lk/GETDocketWorkLog.php'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Request timed out after 30 seconds');
              },
            );

        if (response.statusCode == 200) {
          final String responseBody = response.body;
          if (responseBody.isEmpty) {
            if (attempt < maxRetries) continue;
            return [];
          }

          final dynamic jsonData = json.decode(responseBody);
          if (jsonData is List) {
            return jsonData
                .map<WorkLog>((item) => WorkLog.fromJson(item))
                .toList();
          } else if (jsonData is Map<String, dynamic>) {
            return [WorkLog.fromJson(jsonData)];
          }
          return [];
        } else {
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
          return [];
        }
      } catch (e) {
        print('Error fetching work logs on attempt $attempt: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        return [];
      }
    }
    return [];
  }

  void _applyFilters() {
    List<Worker> list = List.of(_allWorkers);

    if (_selectedBranch != 'All') {
      final allowedDepots = kBranchDepots[_selectedBranch] ?? const ['All'];
      list = list.where((w) => allowedDepots.contains(w.depot)).toList();
    }

    if (_selectedDepot != 'All') {
      list = list.where((w) => w.depot == _selectedDepot).toList();
    }

    _rebuildAvailableTechnicians();

    if (_selectedTechnician != 'All') {
      list = list.where((w) {
        final id = w.employeeNo.isNotEmpty ? w.employeeNo : w.personID;
        return id == _selectedTechnician;
      }).toList();
    }

    setState(() {
      _filteredWorkers = list;
    });
  }

  void _rebuildAvailableTechnicians() {
    List<Worker> base = List.of(_allWorkers);

    if (_selectedBranch != 'All') {
      final allowedDepots = kBranchDepots[_selectedBranch] ?? const ['All'];
      base = base.where((w) => allowedDepots.contains(w.depot)).toList();
    }

    if (_selectedDepot != 'All') {
      base = base.where((w) => w.depot == _selectedDepot).toList();
    }

    final ids = <String>{'All'};
    for (final w in base) {
      final id = (w.employeeNo.isNotEmpty ? w.employeeNo : w.personID).trim();
      if (id.isNotEmpty) ids.add(id);
    }

    final newList = ids.toList()..sort();
    final selectedStillValid = newList.contains(_selectedTechnician);

    setState(() {
      _availableTechnicians = newList;
      if (!selectedStillValid) {
        _selectedTechnician = 'All';
      }
    });
  }

  Future<void> _loadChartData() async {
    setState(() {
      _chartLoading = true;
      _chartError = null;
      _monthlyCompleted = {};
      _monthlyInProgress = {};
    });

    try {
      final now = DateTime.now();
      final currentYear = now.year;
      final currentMonth = now.month;

      // Get technicians to query based on filters
      List<String> technicianIds = [];
      bool showAllTechnicians = false;

      if (_selectedTechnician != 'All') {
        technicianIds = [_selectedTechnician];
      } else {
        // When "All" is selected, we'll show data for all assignments
        showAllTechnicians = true;
        // Still get the list for potential filtering by branch/depot
        technicianIds = _filteredWorkers
            .map((w) => w.employeeNo.isNotEmpty ? w.employeeNo : w.personID)
            .where((id) => id.isNotEmpty)
            .toList();
      }

      print('=== CHART DATA DEBUG ===');
      print('Selected Technician: $_selectedTechnician');
      print('Show All Technicians: $showAllTechnicians');
      print('Technician IDs count: ${technicianIds.length}');
      if (technicianIds.isNotEmpty) {
        print('First 5 Technician IDs: ${technicianIds.take(5).toList()}');
      }
      print('Total Assignments: ${_allAssignments.length}');

      // Print first few assignments to see the format
      if (_allAssignments.isNotEmpty) {
        print('--- Sample Assignments ---');
        for (
          int i = 0;
          i < (_allAssignments.length > 5 ? 5 : _allAssignments.length);
          i++
        ) {
          print(
            'Assignment $i: assignedPersons="${_allAssignments[i].assignedPersons}"',
          );
        }
      }

      print('Total Dockets: ${_allDockets.length}');
      print('Total WorkLogs: ${_allWorkLogs.length}');

      // Count assignments, completions, and in-progress per month (last 3 months only)
      final Map<int, int> assigned = {};
      final Map<int, int> completed = {};
      final Map<int, int> inProgress = {};

      // Initialize only last 3 months
      for (int i = 0; i < 3; i++) {
        int month = currentMonth - i;

        if (month < 1) {
          month += 12;
        }

        // Use month number as key (we'll filter by year when counting)
        assigned[month] = 0;
        completed[month] = 0;
        inProgress[month] = 0;
      }

      // Count assignments from dockets assigned to technicians
      int totalMatched = 0;
      for (final assignment in _allAssignments) {
        bool matchesTechnician = false;

        if (showAllTechnicians) {
          // If showing all technicians, match ALL assignments
          matchesTechnician = true;
        } else {
          final assignedPersons = assignment.assignedPersons
              .split(',')
              .map((e) => e.trim().toLowerCase())
              .toList();

          for (final techId in technicianIds) {
            final techIdLower = techId.toLowerCase();
            // Check if assignedPersons contains the ID directly
            if (assignedPersons.contains(techIdLower)) {
              matchesTechnician = true;
              break;
            }

            // Also check if the worker's name matches
            final worker = _workerMap[techId];
            if (worker != null) {
              final workerNameLower = worker.name.toLowerCase();
              if (assignedPersons.any(
                (person) =>
                    person.contains(workerNameLower) ||
                    workerNameLower.contains(person),
              )) {
                matchesTechnician = true;
                break;
              }
            }
          }
        }

        if (matchesTechnician) {
          totalMatched++;
          try {
            final assignDate = DateTime.parse(assignment.assignedTime);

            // Check if assignment is within last 3 months
            bool isWithinLast3Months = false;
            for (int i = 0; i < 3; i++) {
              int targetMonth = currentMonth - i;
              int targetYear = currentYear;

              if (targetMonth < 1) {
                targetMonth += 12;
                targetYear -= 1;
              }

              if (assignDate.year == targetYear &&
                  assignDate.month == targetMonth) {
                isWithinLast3Months = true;
                break;
              }
            }

            if (isWithinLast3Months && assigned.containsKey(assignDate.month)) {
              assigned[assignDate.month] =
                  (assigned[assignDate.month] ?? 0) + 1;
            }
          } catch (e) {
            print('Error parsing date: $e');
          }
        }
      }

      print('Total assignments matched: $totalMatched');

      // Count completions and in-progress using the same robust logic as depot summary
      int totalCompletedMatched = 0;
      int totalInProgressMatched = 0;
      for (final assignment in _allAssignments) {
        bool matchesTechnician = false;

        if (showAllTechnicians) {
          // If showing all technicians, match ALL assignments
          matchesTechnician = true;
        } else {
          final assignedPersons = assignment.assignedPersons
              .split(',')
              .map((e) => e.trim().toLowerCase())
              .toList();

          for (final techId in technicianIds) {
            final techIdLower = techId.toLowerCase();
            // Check if assignedPersons contains the ID directly
            if (assignedPersons.contains(techIdLower)) {
              matchesTechnician = true;
              break;
            }

            // Also check if the worker's name matches
            final worker = _workerMap[techId];
            if (worker != null) {
              final workerNameLower = worker.name.toLowerCase();
              if (assignedPersons.any(
                (person) =>
                    person.contains(workerNameLower) ||
                    workerNameLower.contains(person),
              )) {
                matchesTechnician = true;
                break;
              }
            }
          }
        }

        if (matchesTechnician) {
          // Find corresponding docket
          final docket = _allDockets.firstWhere(
            (d) => d.id == assignment.docketID,
            orElse: () => Docket(
              id: '',
              depot: '',
              docketType: '',
              imageName: '',
              uploadedBy: '',
              uploadedTime: '',
              assignedTo: '',
              completedTime: '',
              docketSerial: '',
              assignTime: '',
            ),
          );

          if (docket.id.isNotEmpty) {
            // Check if docket is completed using WorkLog completedAt field (same as depot summary)
            bool isCompleted = _allWorkLogs.any(
              (workLog) =>
                  workLog.docketId == docket.id &&
                  workLog.completedAt != null &&
                  workLog.completedAt!.isNotEmpty &&
                  workLog.completedAt != '0' &&
                  workLog.completedAt!.toLowerCase() != 'null',
            );

            // Get the assignment month for categorization
            try {
              final assignDate = DateTime.parse(assignment.assignedTime);

              // Check if assignment is within last 3 months
              bool isWithinLast3Months = false;
              for (int i = 0; i < 3; i++) {
                int targetMonth = currentMonth - i;
                int targetYear = currentYear;

                if (targetMonth < 1) {
                  targetMonth += 12;
                  targetYear -= 1;
                }

                if (assignDate.year == targetYear &&
                    assignDate.month == targetMonth) {
                  isWithinLast3Months = true;
                  break;
                }
              }

              if (isWithinLast3Months) {
                if (isCompleted) {
                  // Find the completion date from work log
                  final completedWorkLog = _allWorkLogs.firstWhere(
                    (workLog) =>
                        workLog.docketId == docket.id &&
                        workLog.completedAt != null &&
                        workLog.completedAt!.isNotEmpty &&
                        workLog.completedAt != '0' &&
                        workLog.completedAt!.toLowerCase() != 'null',
                    orElse: () => WorkLog(
                      id: '',
                      assignmentId: '',
                      docketId: '',
                      employeeNo: '',
                      completedAt: null,
                    ),
                  );

                  if (completedWorkLog.completedAt != null) {
                    totalCompletedMatched++;
                    try {
                      final completedDate = DateTime.parse(
                        completedWorkLog.completedAt!,
                      );

                      // Check if completion is within last 3 months
                      bool completionWithinLast3Months = false;
                      for (int i = 0; i < 3; i++) {
                        int targetMonth = currentMonth - i;
                        int targetYear = currentYear;

                        if (targetMonth < 1) {
                          targetMonth += 12;
                          targetYear -= 1;
                        }

                        if (completedDate.year == targetYear &&
                            completedDate.month == targetMonth) {
                          completionWithinLast3Months = true;
                          break;
                        }
                      }

                      if (completionWithinLast3Months &&
                          completed.containsKey(completedDate.month)) {
                        completed[completedDate.month] =
                            (completed[completedDate.month] ?? 0) + 1;
                      }
                    } catch (e) {
                      print('Error parsing completion date: $e');
                    }
                  }
                } else {
                  // In progress - assigned but not completed
                  if (inProgress.containsKey(assignDate.month)) {
                    totalInProgressMatched++;
                    inProgress[assignDate.month] =
                        (inProgress[assignDate.month] ?? 0) + 1;
                  }
                }
              }
            } catch (e) {
              print('Error parsing assignment date: $e');
            }
          }
        }
      }

      print('Monthly assigned: $assigned');
      print('Monthly completed: $completed');
      print('Monthly in-progress: $inProgress');
      print(
        'Total matched assignments: ${assigned.values.fold(0, (sum, val) => sum + val)}',
      );
      print('Total completed matched: $totalCompletedMatched');
      print('Total in-progress matched: $totalInProgressMatched');
      print('=== END DEBUG ===');

      setState(() {
        _monthlyCompleted = completed;
        _monthlyInProgress = inProgress;
      });
    } catch (e) {
      setState(() {
        _chartError = 'Failed to load chart data: $e';
      });
    } finally {
      if (mounted) setState(() => _chartLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Technician Summary'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFiltersCard(isMobile),
            const SizedBox(height: 24),
            _buildMonthlyTrendsCard(isMobile),
            const SizedBox(height: 24),
            _buildWorkersListCard(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          isMobile ? _buildMobileFilters() : _buildDesktopFilters(),
        ],
      ),
    );
  }

  Widget _buildMobileFilters() {
    final availableDepots = _selectedBranch == 'All'
        ? kDepots
        : (kBranchDepots[_selectedBranch] ?? const ['All']);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                value: _selectedBranch,
                items: kBranches,
                label: 'Branch',
                onChanged: (v) {
                  setState(() {
                    _selectedBranch = v ?? 'All';
                    _selectedDepot = 'All';
                  });
                  _applyFilters();
                  _loadChartData();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdown(
                value: availableDepots.contains(_selectedDepot)
                    ? _selectedDepot
                    : 'All',
                items: availableDepots,
                label: 'Depot',
                onChanged: (v) {
                  setState(() => _selectedDepot = v ?? 'All');
                  _applyFilters();
                  _loadChartData();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTechnicianDropdown(
          value: _selectedTechnician,
          items: _availableTechnicians,
          label: 'Technician',
          onChanged: (v) {
            setState(() => _selectedTechnician = v ?? 'All');
            _applyFilters();
            _loadChartData();
          },
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    final availableDepots = _selectedBranch == 'All'
        ? kDepots
        : (kBranchDepots[_selectedBranch] ?? const ['All']);

    return Row(
      children: [
        Expanded(
          child: _buildDropdown(
            value: _selectedBranch,
            items: kBranches,
            label: 'Branch',
            onChanged: (v) {
              setState(() {
                _selectedBranch = v ?? 'All';
                _selectedDepot = 'All';
              });
              _applyFilters();
              _loadChartData();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildDropdown(
            value: availableDepots.contains(_selectedDepot)
                ? _selectedDepot
                : 'All',
            items: availableDepots,
            label: 'Depot',
            onChanged: (v) {
              setState(() => _selectedDepot = v ?? 'All');
              _applyFilters();
              _loadChartData();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTechnicianDropdown(
            value: _selectedTechnician,
            items: _availableTechnicians,
            label: 'Technician',
            onChanged: (v) {
              setState(() => _selectedTechnician = v ?? 'All');
              _applyFilters();
              _loadChartData();
            },
          ),
        ),
      ],
    );
  }

  // Build technician dropdown with name and ID display
  Widget _buildTechnicianDropdown({
    required String value,
    required List<String> items,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items.map((String item) {
                String displayText = item;
                if (item != 'All' && _workerMap.containsKey(item)) {
                  final worker = _workerMap[item]!;
                  displayText = '${worker.name} ($item)';
                }
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    displayText,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyTrendsCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                _selectedTechnician == 'All'
                    ? 'Last 3 Months Progress - All Technicians'
                    : 'Last 3 Months Trends - $_selectedTechnician',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_chartLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_chartError != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _chartError!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (_monthlyInProgress.isEmpty && _monthlyCompleted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Text('No data available'),
                  const SizedBox(height: 8),
                  Text(
                    'Debug: In-Progress entries: ${_monthlyInProgress.length}, '
                    'Completed entries: ${_monthlyCompleted.length}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            _buildLineChart(isMobile),
        ],
      ),
    );
  }

  Widget _buildLineChart(bool isMobile) {
    final now = DateTime.now();
    final currentMonth = now.month;

    // Calculate the range for last 3 months
    final List<int> last3Months = [];
    for (int i = 2; i >= 0; i--) {
      int month = currentMonth - i;
      if (month < 1) {
        month += 12;
      }
      last3Months.add(month);
    }

    final minMonth = last3Months.first.toDouble();
    final maxMonth = last3Months.last.toDouble();

    final maxY = [
      ..._monthlyInProgress.values,
      ..._monthlyCompleted.values,
    ].fold(0, (max, val) => val > max ? val : max).toDouble();

    return Column(
      children: [
        SizedBox(
          height: isMobile ? 250 : 300,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: maxY > 0 ? maxY / 5 : 1,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: Colors.grey[300], strokeWidth: 1),
                getDrawingVerticalLine: (value) =>
                    FlLine(color: Colors.grey[300], strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: isMobile ? 10 : 12),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      const months = [
                        'Jan',
                        'Feb',
                        'Mar',
                        'Apr',
                        'May',
                        'Jun',
                        'Jul',
                        'Aug',
                        'Sep',
                        'Oct',
                        'Nov',
                        'Dec',
                      ];
                      final index = value.toInt();
                      if (index >= 1 &&
                          index <= 12 &&
                          last3Months.contains(index)) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            months[index - 1],
                            style: TextStyle(fontSize: isMobile ? 10 : 12),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey[300]!),
              ),
              minX: minMonth,
              maxX: maxMonth,
              minY: 0,
              maxY: maxY > 0 ? maxY * 1.1 : 10,
              lineBarsData: [
                LineChartBarData(
                  spots:
                      _monthlyInProgress.entries
                          .map(
                            (e) => FlSpot(e.key.toDouble(), e.value.toDouble()),
                          )
                          .toList()
                        ..sort((a, b) => a.x.compareTo(b.x)),
                  isCurved: true,
                  color: _assignedColor,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: false),
                ),
                LineChartBarData(
                  spots:
                      _monthlyCompleted.entries
                          .map(
                            (e) => FlSpot(e.key.toDouble(), e.value.toDouble()),
                          )
                          .toList()
                        ..sort((a, b) => a.x.compareTo(b.x)),
                  isCurved: true,
                  color: _completedColor,
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _legendItem(_assignedColor, 'In Progress'),
            _legendItem(_completedColor, 'Completed'),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildWorkersListCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Technicians',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          else if (_filteredWorkers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: Text('No technicians found')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredWorkers.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final worker = _filteredWorkers[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _primaryColor,
                    child: Text(
                      worker.name.isNotEmpty
                          ? worker.name[0].toUpperCase()
                          : 'T',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(
                    worker.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Employee No: ${worker.employeeNo}'),
                      Text('Depot: ${worker.depot}'),
                      Text('Status: ${worker.status}'),
                    ],
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
