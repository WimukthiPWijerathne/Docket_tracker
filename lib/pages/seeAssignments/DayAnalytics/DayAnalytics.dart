import 'package:flutter/material.dart';
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

class SeeAssignmentsPage extends StatefulWidget {
  const SeeAssignmentsPage({super.key});

  @override
  State<SeeAssignmentsPage> createState() => _SeeAssignmentsPageState();
}

class _SeeAssignmentsPageState extends State<SeeAssignmentsPage>
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

  // Check if assignment is ongoing (not completed)
  bool _isAssignmentOngoing(AssignedDocket assignment) {
    return !_isAssignmentCompleted(assignment);
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

  // Get daily assignment statistics
  ({int total, int completed, int ongoing, int overdue}) _getDailyStatistics() {
    final today = DateTime.now();
    final base = _getFilteredAssignments();
    final todayAssignments = base.where((assignment) {
      try {
        final assignedTime = DateTime.parse(
          assignment.assignedTime.replaceAll('/', '-'),
        );
        return assignedTime.year == today.year &&
            assignedTime.month == today.month &&
            assignedTime.day == today.day;
      } catch (_) {
        return false;
      }
    }).toList();

    return (
      total: todayAssignments.length,
      completed: todayAssignments
          .where((a) => _isAssignmentCompleted(a))
          .length,
      ongoing: todayAssignments.where((a) => _isAssignmentOngoing(a)).length,
      overdue: todayAssignments.where((a) => a.isOverdue()).length,
    );
  }

  // Get today's docket type statistics with filtering
  Map<String, int> _getTodayDocketTypeStats() {
    final today = DateTime.now();
    final base = _getFilteredAssignments();
    final todayAssignments = base.where((assignment) {
      try {
        final assignedTime = DateTime.parse(
          assignment.assignedTime.replaceAll('/', '-'),
        );
        return assignedTime.year == today.year &&
            assignedTime.month == today.month &&
            assignedTime.day == today.day;
      } catch (_) {
        return false;
      }
    }).toList();

    final Map<String, int> docketTypeStats = {};

    for (final assignment in todayAssignments) {
      final docket = _docketsMap[assignment.docketID];
      if (docket != null) {
        final docketType = docket.docketType.trim();
        if (docketType.isNotEmpty) {
          docketTypeStats[docketType] = (docketTypeStats[docketType] ?? 0) + 1;
        }
      }
    }

    return docketTypeStats;
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
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.analytics_outlined,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Day Analytics',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.refresh_rounded, size: 20),
              ),
              onPressed: _loadData,
              tooltip: 'Refresh Data',
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _primaryColor,
                _primaryColor.withBlue(
                  (_primaryColor.blue * 1.2).clamp(0, 255).toInt(),
                ),
              ],
            ),
          ),
        ),
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
                    "Loading assignments...",
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

              // Filter Section with improved spacing
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
                    _buildPieChartSection(),
                    SizedBox(height: sectionSpacing),
                    _buildDocketTypesPieChartSection(),
                  ],
                )
              else
                // Desktop/Tablet: Side by side or stacked based on preference
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildPieChartSection()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildDocketTypesPieChartSection()),
                      ],
                    ),
                  ],
                ),

              // Bottom spacing
              SizedBox(height: isMobile ? 32 : 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileFilters() {
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
              child: DropdownButtonFormField<String>(
                initialValue: _selectedBranch,
                items: kBranches
                    .map(
                      (branch) => DropdownMenuItem(
                        value: branch,
                        child: Text(
                          branch,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
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
                    fontWeight: FontWeight.w500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                isExpanded: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
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
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedDepot = v ?? 'All'),
                decoration: InputDecoration(
                  labelText: 'Depot',
                  labelStyle: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                isExpanded: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Second row: Worker
        DropdownButtonFormField<String>(
          initialValue: _selectedWorker,
          items: _availableWorkers
              .map(
                (worker) => DropdownMenuItem(
                  value: worker,
                  child: Text(
                    worker,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedWorker = v ?? 'All'),
          decoration: InputDecoration(
            labelText: 'Worker',
            labelStyle: TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w500,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          isExpanded: true,
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isWideScreen = screenWidth >= 1200;

    // Get available depots based on selected branch
    final availableDepots = _selectedBranch == 'All'
        ? kDepots
        : (kBranchDepots[_selectedBranch] ?? ['All']);

    // Responsive widths
    final branchWidth = isWideScreen
        ? 220.0
        : isTablet
        ? 200.0
        : 180.0;
    final depotWidth = isWideScreen
        ? 220.0
        : isTablet
        ? 200.0
        : 180.0;
    final workerWidth = isWideScreen
        ? 200.0
        : isTablet
        ? 180.0
        : 160.0;
    final spacing = isWideScreen ? 20.0 : 16.0;

    return Wrap(
      spacing: spacing,
      runSpacing: 16,
      children: [
        // Branch Dropdown
        SizedBox(
          width: branchWidth,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedBranch,
            items: kBranches
                .map(
                  (branch) => DropdownMenuItem(
                    value: branch,
                    child: Text(
                      branch,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
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
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            isExpanded: true,
          ),
        ),

        // Depot Dropdown
        SizedBox(
          width: depotWidth,
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
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedDepot = v ?? 'All'),
            decoration: InputDecoration(
              labelText: 'Depot',
              labelStyle: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            isExpanded: true,
          ),
        ),

        // Worker Dropdown
        SizedBox(
          width: workerWidth,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedWorker,
            items: _availableWorkers
                .map(
                  (worker) => DropdownMenuItem(
                    value: worker,
                    child: Text(
                      worker,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedWorker = v ?? 'All'),
            decoration: InputDecoration(
              labelText: 'Worker',
              labelStyle: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildPieChartSection() {
    // Get daily statistics instead of filtered statistics
    final dailyStats = _getDailyStatistics();
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Calculate total for pie chart (only ongoing and completed)
    final chartTotal = dailyStats.ongoing + dailyStats.completed;

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: _primaryColor,
                size: isMobile ? 20 : 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Today\'s Assignment Progress',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : 24),
          Container(
            height: isMobile ? 220 : 240,
            padding: const EdgeInsets.all(8),
            child: chartTotal > 0
                ? PieChart(
                    PieChartData(
                      sections: [
                        if (dailyStats.completed > 0)
                          PieChartSectionData(
                            value: dailyStats.completed.toDouble(),
                            title:
                                'Completed\n${dailyStats.completed}\n(${((dailyStats.completed / chartTotal) * 100).toStringAsFixed(1)}%)',
                            color: const Color(0xFF4CAF50),
                            radius: isMobile ? 65 : 70,
                            titleStyle: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        if (dailyStats.ongoing > 0)
                          PieChartSectionData(
                            value: dailyStats.ongoing.toDouble(),
                            title:
                                'Ongoing\n${dailyStats.ongoing}\n(${((dailyStats.ongoing / chartTotal) * 100).toStringAsFixed(1)}%)',
                            color: const Color(0xFFFF9800),
                            radius: isMobile ? 65 : 70,
                            titleStyle: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                      ],
                      sectionsSpace: 3,
                      centerSpaceRadius: isMobile ? 45 : 50,
                    ),
                  )
                : Container(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pie_chart_outline_rounded,
                          size: isMobile ? 56 : 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        Text(
                          'No assignments today',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: isMobile ? 4 : 8),
                        Text(
                          'Data will appear when assignments are available',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildEnhancedLegendItem(
                  const Color(0xFF4CAF50),
                  'Completed',
                  dailyStats.completed,
                ),
                Container(width: 1, height: 24, color: Colors.grey[300]),
                _buildEnhancedLegendItem(
                  const Color(0xFFFF9800),
                  'Ongoing',
                  dailyStats.ongoing,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedLegendItem(Color color, String text, int count) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isMobile ? 14 : 16,
              height: isMobile ? 14 : 16,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            SizedBox(width: isMobile ? 6 : 8),
            Text(
              text,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDocketTypeLegendItem(
    Color color,
    String docketType,
    int count,
    int total,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final percentage = ((count / total) * 100).toStringAsFixed(1);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 12,
        vertical: isMobile ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isMobile ? 12 : 14,
            height: isMobile ? 12 : 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          SizedBox(width: isMobile ? 6 : 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                docketType,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                '$count ($percentage%)',
                style: TextStyle(
                  fontSize: isMobile ? 10 : 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocketTypesPieChartSection() {
    final docketTypeStats = _getTodayDocketTypeStats();
    final totalDockets = docketTypeStats.values.fold(
      0,
      (sum, count) => sum + count,
    );
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Enhanced colors for different docket types
    final List<Color> chartColors = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF009688), // Teal
      const Color(0xFF3F51B5), // Indigo
      const Color(0xFFE91E63), // Pink
      const Color(0xFFFFC107), // Amber
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF8BC34A), // Light Green
      const Color(0xFF795548), // Brown
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.donut_large_outlined,
                color: _primaryColor,
                size: isMobile ? 20 : 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Today\'s Docket Types Distribution',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : 24),
          Container(
            height: isMobile ? 220 : 240,
            padding: const EdgeInsets.all(8),
            child: totalDockets > 0
                ? PieChart(
                    PieChartData(
                      sections: docketTypeStats.entries
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) {
                            final index = entry.key;
                            final docketEntry = entry.value;
                            final docketType = docketEntry.key;
                            final count = docketEntry.value;
                            final color =
                                chartColors[index % chartColors.length];

                            final percentage = ((count / totalDockets) * 100)
                                .toStringAsFixed(1);
                            return PieChartSectionData(
                              value: count.toDouble(),
                              title: count > 0
                                  ? '$docketType\\n$count\\n($percentage%)'
                                  : '',
                              color: color,
                              radius: isMobile ? 65 : 70,
                              titleStyle: TextStyle(
                                fontSize: isMobile ? 9 : 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            );
                          })
                          .toList(),
                      sectionsSpace: 3,
                      centerSpaceRadius: isMobile ? 45 : 50,
                    ),
                  )
                : Container(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.donut_small_rounded,
                          size: isMobile ? 56 : 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        Text(
                          'No docket types today',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: isMobile ? 4 : 8),
                        Text(
                          'Chart will display when docket data is available',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          // Enhanced Legend for docket types
          if (totalDockets > 0) ...[
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Distribution Details',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  Wrap(
                    alignment: WrapAlignment.start,
                    spacing: isMobile ? 16 : 20,
                    runSpacing: isMobile ? 12 : 16,
                    children: docketTypeStats.entries
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                          final index = entry.key;
                          final docketEntry = entry.value;
                          final docketType = docketEntry.key;
                          final count = docketEntry.value;
                          final color = chartColors[index % chartColors.length];

                          return _buildDocketTypeLegendItem(
                            color,
                            docketType,
                            count,
                            totalDockets,
                          );
                        })
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
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
