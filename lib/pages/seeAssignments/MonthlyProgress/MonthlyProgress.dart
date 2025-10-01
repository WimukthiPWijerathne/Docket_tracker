import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// --- Models
import '../../../models/assigned_docket.dart';
import '../../../models/dockets.dart';
import '../../../models/WorkLog.dart';

// --- Services
import '../../../service/assigned_docket_service.dart';
import '../../../service/dockey_service.dart' as dockey;

// Branch and Depot constants from technician portal
const List<String> kBranches = [
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

const List<String> kDepots = [
  'All',
  // Head Office
  'Head Office',
  // Kelaniya depots
  'Wattala',
  'Kandana',
  'Mahara',
  'Dalugama',
  // Kotte depots
  'Pitakotte',
  'Kolonnawa',
  'Kotikawatta',
  // Nugegoda depots
  'Boralesgamuwa',
  'Nugegoda',
  'Maharagama',
  // Moratuwa depots
  'Moratuwa North',
  'Moratuwa South',
  'Keselwatta',
  'Panadura',
  'Koralawella',
  // Kalutara depots
  'Payagala',
  'Kalutara',
  'Aluthgama',
  // Negombo depots
  'Negombo',
  'Seeduwa',
  'Ja-Ela',
  // Galle depots
  'Ambalangoda',
  'Hikkaduwa',
  'Galle',
  'Other',
];

const Map<String, List<String>> kBranchDepots = {
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

class MonthlyProgressPage extends StatefulWidget {
  const MonthlyProgressPage({super.key});

  @override
  State<MonthlyProgressPage> createState() => _MonthlyProgressPageState();
}

class _MonthlyProgressPageState extends State<MonthlyProgressPage>
    with TickerProviderStateMixin {
  final _assignedDocketSvc = AssignedDocketService();
  final _docketSvc = dockey.DocketService();

  bool _loading = true;
  String? _error;

  // Data
  List<AssignedDocket> _allAssignments = [];
  final Map<String, Docket> _docketsMap = {};
  final Map<String, WorkLog> _workLogsMap = {};

  // UI State
  late AnimationController _animationController;
  String _searchQuery = '';

  // Separate filter states for branch and depot
  String _selectedBranch = 'All';
  String _selectedDepot = 'All';
  String _selectedWorker = 'All';
  List<String> _availableWorkers = ['All'];

  // Constants
  static const Color _primaryColor = Color(0xFF003366);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Method to fetch work logs
  Future<List<WorkLog>> _fetchWorkLogs() async {
    try {
      final response = await http
          .get(
            Uri.parse('https://powerprox.sltidc.lk/GETDocketWorkLog.php'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final String responseBody = response.body;
        if (responseBody.isEmpty) return [];

        final dynamic jsonData = json.decode(responseBody);
        if (jsonData is List) {
          return jsonData
              .map<WorkLog>((item) => WorkLog.fromJson(item))
              .toList();
        } else if (jsonData is Map<String, dynamic>) {
          return [WorkLog.fromJson(jsonData)];
        }
        return [];
      }
      return [];
    } catch (e) {
      print('Error fetching work logs: $e');
      return [];
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load data in parallel - including work logs
      final results = await Future.wait([
        _assignedDocketSvc.fetchAssignedDockets(),
        _docketSvc.fetchDockets(),
        _fetchWorkLogs(),
      ]);

      final assignments = results[0] as List<AssignedDocket>;
      final dockets = results[1] as List<Docket>;
      final workLogs = results[2] as List<WorkLog>;

      // Create lookup maps
      _docketsMap.clear();
      _workLogsMap.clear();

      for (final docket in dockets) {
        _docketsMap[docket.id] = docket;
      }

      for (final workLog in workLogs) {
        _workLogsMap[workLog.docketId] = workLog;
      }

      // Populate filter options
      _populateFilterOptions(assignments);

      // Update state
      setState(() {
        _allAssignments = assignments;
        _loading = false;
      });

      // Start animation
      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      setState(() {
        _error = 'Failed to load assignments: $e';
        _loading = false;
        _allAssignments = [];
        _docketsMap.clear();
        _workLogsMap.clear();
      });
    }
  }

  // Normalize depot names for robust comparisons (case/space/hyphen insensitive)
  String _normalizeDepot(String value) {
    final lower = value.trim().toLowerCase();
    // remove all non-alphanumeric characters
    return lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  // Check if assignment is completed using WorkLog data (same logic as depot summary)
  bool _isAssignmentCompleted(AssignedDocket assignment) {
    final workLog = _workLogsMap[assignment.docketID];
    if (workLog == null) return false;

    return workLog.completedAt != null &&
        workLog.completedAt!.isNotEmpty &&
        workLog.completedAt != '0' &&
        workLog.completedAt!.toLowerCase() != 'null';
  }

  // Get filtered assignments based on search and filter
  List<AssignedDocket> _getFilteredAssignments() {
    var filtered = _allAssignments;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((assignment) {
        final docket = _docketsMap[assignment.docketID];
        final searchLower = _searchQuery.toLowerCase();

        return assignment.assignmentID.toLowerCase().contains(searchLower) ||
            assignment.docketID.toLowerCase().contains(searchLower) ||
            assignment.assignedPersons.toLowerCase().contains(searchLower) ||
            (docket?.docketType.toLowerCase().contains(searchLower) ?? false) ||
            (docket?.depot.toLowerCase().contains(searchLower) ?? false);
      }).toList();
    }

    // Apply branch filter (assuming depot field contains branch info)
    if (_selectedBranch != 'All') {
      final allowedDepots = kBranchDepots[_selectedBranch] ?? const ['All'];
      final allowedSet = allowedDepots.map(_normalizeDepot).toSet();
      filtered = filtered.where((assignment) {
        final docket = _docketsMap[assignment.docketID];
        if (docket == null) return false;
        final depotName = _normalizeDepot(docket.depot);
        return allowedSet.contains(depotName);
      }).toList();
    }

    // Apply depot filter
    if (_selectedDepot != 'All') {
      final targetDepot = _normalizeDepot(_selectedDepot);
      filtered = filtered.where((assignment) {
        final docket = _docketsMap[assignment.docketID];
        if (docket == null) return false;
        return _normalizeDepot(docket.depot) == targetDepot;
      }).toList();
    }

    // Apply worker filter (exact match among comma-separated IDs)
    if (_selectedWorker != 'All') {
      filtered = filtered.where((assignment) {
        final persons = assignment.assignedPersons
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        return persons.contains(_selectedWorker);
      }).toList();
    }

    return filtered;
  }

  // Get last three months docket statistics for bar chart
  List<({String month, int totalDockets, int completedDockets})>
  _getLastThreeMonthsDocketStats() {
    final now = DateTime.now();
    final months = <({String month, int totalDockets, int completedDockets})>[];
    final base = _getFilteredAssignments();

    for (int i = 2; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthName = DateFormat('MMM').format(monthDate);

      // Filter assignments for this month (from filtered set)
      final monthAssignments = base.where((assignment) {
        try {
          final assignedTime = DateTime.parse(
            assignment.assignedTime.replaceAll('/', '-'),
          );
          return assignedTime.year == monthDate.year &&
              assignedTime.month == monthDate.month;
        } catch (_) {
          return false;
        }
      });

      final totalDockets = monthAssignments.length;
      final completedDockets = monthAssignments
          .where((a) => _isAssignmentCompleted(a))
          .length;

      months.add((
        month: monthName,
        totalDockets: totalDockets,
        completedDockets: completedDockets,
      ));
    }

    return months;
  }

  double _getMaxYValue(
    List<({String month, int totalDockets, int completedDockets})> stats,
  ) {
    final maxTotal = stats
        .map((e) => e.totalDockets)
        .reduce((a, b) => a > b ? a : b);
    final maxCompleted = stats
        .map((e) => e.completedDockets)
        .reduce((a, b) => a > b ? a : b);
    final maxValue = maxTotal > maxCompleted ? maxTotal : maxCompleted;
    return (maxValue + 2).toDouble(); // Add some padding
  }

  // Get dominant docket type trends over the last 3 months
  List<({String month, String dominantType, int count})>
  _getDominantDocketTypeTrends() {
    final now = DateTime.now();
    final base = _getFilteredAssignments();
    final List<({String month, String dominantType, int count})>
    dominantTrends = [];

    for (int i = 2; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      final monthName = DateFormat('MMM').format(monthDate);

      // Filter assignments for this month
      final monthAssignments = base.where((assignment) {
        try {
          final assignedTime = DateTime.parse(
            assignment.assignedTime.replaceAll('/', '-'),
          );
          return assignedTime.year == monthDate.year &&
              assignedTime.month == monthDate.month;
        } catch (_) {
          return false;
        }
      });

      // Count docket types for this month
      final Map<String, int> monthDocketTypes = {};
      for (final assignment in monthAssignments) {
        final docket = _docketsMap[assignment.docketID];
        if (docket != null && docket.docketType.trim().isNotEmpty) {
          final docketType = docket.docketType.trim();
          monthDocketTypes[docketType] =
              (monthDocketTypes[docketType] ?? 0) + 1;
        }
      }

      // Find the dominant docket type (highest count) for this month
      String dominantType = 'No Data';
      int maxCount = 0;

      if (monthDocketTypes.isNotEmpty) {
        for (final entry in monthDocketTypes.entries) {
          if (entry.value > maxCount) {
            maxCount = entry.value;
            dominantType = entry.key;
          }
        }
      }

      dominantTrends.add((
        month: monthName,
        dominantType: dominantType,
        count: maxCount,
      ));
    }

    return dominantTrends;
  }

  double _getMaxDominantValue(
    List<({String month, String dominantType, int count})> trends,
  ) {
    if (trends.isEmpty) return 10.0;

    int maxValue = 0;
    for (final trend in trends) {
      if (trend.count > maxValue) maxValue = trend.count;
    }
    return (maxValue + 2).toDouble(); // Add some padding
  }

  void _populateFilterOptions(List<AssignedDocket> assignments) {
    final Set<String> workers = {'All'};

    for (final assignment in assignments) {
      if (assignment.assignedPersons.isNotEmpty &&
          assignment.assignedPersons != 'null') {
        // Handle comma-separated assigned persons
        final persons = assignment.assignedPersons
            .split(',')
            .map((e) => e.trim());
        workers.addAll(persons);
      }
    }

    setState(() {
      _availableWorkers = workers.toList()..sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Monthly Progress',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                  SizedBox(height: 24),
                  Text(
                    "Loading monthly progress...",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _loadData)
          : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    // Dynamic padding based on screen size
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
        ? 24.0
        : 32.0;
    final sectionSpacing = isMobile ? 20.0 : 28.0;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top spacing
              SizedBox(height: isMobile ? 16 : 24),

              // Search Bar with enhanced styling
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by ID, person, type, or depot...',
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontSize: isMobile ? 14 : 16,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey[600],
                      size: isMobile ? 20 : 24,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              size: isMobile ? 20 : 24,
                            ),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: _primaryColor, width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: isMobile ? 16 : 18,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),

              SizedBox(height: sectionSpacing),

              // Filter Section with improved styling
              Container(
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
                    Text(
                      'Filter Options',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    SizedBox(height: isMobile ? 12 : 16),
                    isMobile && isPortrait
                        ? _buildMobileFilters()
                        : _buildDesktopFilters(),
                  ],
                ),
              ),

              SizedBox(height: sectionSpacing),

              // Charts Section with responsive layout
              if (isMobile)
                // Mobile: Stack charts vertically
                Column(
                  children: [
                    _buildBarChartSection(),
                    SizedBox(height: sectionSpacing),
                    _buildDocketTypeTrendsSection(),
                  ],
                )
              else
                // Desktop/Tablet: Show charts side by side or stacked based on available space
                isTablet && isPortrait
                    ? Column(
                        children: [
                          _buildBarChartSection(),
                          SizedBox(height: sectionSpacing),
                          _buildDocketTypeTrendsSection(),
                        ],
                      )
                    : Column(
                        children: [
                          _buildBarChartSection(),
                          SizedBox(height: sectionSpacing),
                          _buildDocketTypeTrendsSection(),
                        ],
                      ),

              // Bottom spacing
              SizedBox(height: sectionSpacing + 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileFilters() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Get available depots based on selected branch
    final availableDepots = _selectedBranch == 'All'
        ? kDepots
        : (kBranchDepots[_selectedBranch] ?? ['All']);

    return Column(
      children: [
        // First row: Branch and Depot dropdowns
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  color: Colors.grey[50],
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedBranch,
                  items: kBranches
                      .map(
                        (branch) => DropdownMenuItem(
                          value: branch,
                          child: Text(
                            branch,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedBranch = v ?? 'All';
                      // Reset depot when branch changes
                      _selectedDepot = 'All';
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Branch',
                    labelStyle: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 12 : 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isMobile ? 12 : 14,
                    ),
                  ),
                  isExpanded: true,
                ),
              ),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  color: Colors.grey[50],
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: availableDepots.contains(_selectedDepot)
                      ? _selectedDepot
                      : 'All',
                  items: availableDepots
                      .map(
                        (depot) => DropdownMenuItem(
                          value: depot,
                          child: Text(
                            depot,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedDepot = v ?? 'All'),
                  decoration: InputDecoration(
                    labelText: 'Depot',
                    labelStyle: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 12 : 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isMobile ? 12 : 14,
                    ),
                  ),
                  isExpanded: true,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 12 : 16),
        // Second row: Worker
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                  color: Colors.grey[50],
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedWorker,
                  items: _availableWorkers
                      .map(
                        (worker) => DropdownMenuItem(
                          value: worker,
                          child: Text(
                            worker,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedWorker = v ?? 'All'),
                  decoration: InputDecoration(
                    labelText: 'Worker',
                    labelStyle: TextStyle(
                      color: _primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 12 : 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isMobile ? 12 : 14,
                    ),
                  ),
                  isExpanded: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    // Get available depots based on selected branch
    final availableDepots = _selectedBranch == 'All'
        ? kDepots
        : (kBranchDepots[_selectedBranch] ?? ['All']);

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        // Branch Dropdown
        SizedBox(
          width: isTablet ? 180 : 200,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.grey[50],
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedBranch,
              items: kBranches
                  .map(
                    (branch) => DropdownMenuItem(
                      value: branch,
                      child: Text(
                        branch,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedBranch = v ?? 'All';
                  // Reset depot when branch changes
                  _selectedDepot = 'All';
                });
              },
              decoration: InputDecoration(
                labelText: 'Branch',
                labelStyle: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              isExpanded: true,
            ),
          ),
        ),

        // Depot Dropdown
        SizedBox(
          width: isTablet ? 180 : 200,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.grey[50],
            ),
            child: DropdownButtonFormField<String>(
              initialValue: availableDepots.contains(_selectedDepot)
                  ? _selectedDepot
                  : 'All',
              items: availableDepots
                  .map(
                    (depot) => DropdownMenuItem(
                      value: depot,
                      child: Text(
                        depot,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedDepot = v ?? 'All'),
              decoration: InputDecoration(
                labelText: 'Depot',
                labelStyle: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              isExpanded: true,
            ),
          ),
        ),

        // Worker Dropdown
        SizedBox(
          width: isTablet ? 160 : 180,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.grey[50],
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedWorker,
              items: _availableWorkers
                  .map(
                    (worker) => DropdownMenuItem(
                      value: worker,
                      child: Text(
                        worker,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedWorker = v ?? 'All'),
              decoration: InputDecoration(
                labelText: 'Worker',
                labelStyle: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              isExpanded: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChartSection() {
    final monthlyStats = _getLastThreeMonthsDocketStats();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (monthlyStats.isEmpty) {
      return Container(
        height: isMobile ? 180 : 200,
        alignment: Alignment.center,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: isMobile ? 40 : 48,
              color: Colors.grey[400],
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              'No monthly data available',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bar_chart,
                  color: _primaryColor,
                  size: isMobile ? 20 : 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Last 3 Months Docket Overview',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    Text(
                      'Monthly performance comparison',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxYValue(monthlyStats),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => Colors.grey[800]!,
                    tooltipRoundedRadius: 8,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final month = monthlyStats[groupIndex];
                      final value = rodIndex == 0
                          ? month.totalDockets
                          : month.completedDockets;
                      final label = rodIndex == 0
                          ? 'Total Dockets'
                          : 'Completed';
                      return BarTooltipItem(
                        '$label: $value',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value >= 0 && value < monthlyStats.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              monthlyStats[value.toInt()].month,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 32,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 1,
                      dashArray: [2, 2],
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(color: Colors.grey[300], strokeWidth: 1);
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey[300]!),
                ),
                barGroups: monthlyStats.asMap().entries.map((entry) {
                  final index = entry.key;
                  final month = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: month.totalDockets.toDouble(),
                        color: Colors.orange,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                      BarChartRodData(
                        toY: month.completedDockets.toDouble(),
                        color: Colors.green,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                    barsSpace: 4,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.orange, 'Total Dockets'),
              const SizedBox(width: 24),
              _buildLegendItem(Colors.green, 'Completed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildDocketTypeTrendsSection() {
    final dominantTrends = _getDominantDocketTypeTrends();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (dominantTrends.isEmpty ||
        dominantTrends.every((trend) => trend.count == 0)) {
      return Container(
        padding: EdgeInsets.all(isMobile ? 24 : 32),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: isMobile ? 40 : 48,
              color: Colors.grey[400],
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              'No dominant docket type trends available',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Define colors for different docket types

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: _primaryColor,
                  size: isMobile ? 20 : 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dominant Docket Type Trends',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    Text(
                      'Last 3 months comparison',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 16 : 20),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                maxY: _getMaxDominantValue(dominantTrends),
                minY: 0,
                lineBarsData: [
                  LineChartBarData(
                    spots: dominantTrends.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.count.toDouble(),
                      );
                    }).toList(),
                    isCurved: true,
                    color: _primaryColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      color: _primaryColor.withOpacity(0.1),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: _primaryColor,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                  ),
                ],
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value >= 0 && value < dominantTrends.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              dominantTrends[value.toInt()].month,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 32,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getMaxDominantValue(dominantTrends) / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
                  },
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.grey[800]!,
                    tooltipRoundedRadius: 8,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final trend = dominantTrends[barSpot.x.toInt()];
                        return LineTooltipItem(
                          '${trend.dominantType}\n${trend.month}: ${barSpot.y.toInt()} dockets',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend for dominant docket types
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: dominantTrends.map((trend) {
              return _buildTrendLegendItem(
                _primaryColor.withOpacity(0.7),
                '${trend.month}: ${trend.dominantType} (${trend.count})',
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendLegendItem(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorView({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Oops! Something went wrong",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text("Try Again"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
