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
  List<Docket> _allDockets = [];
  List<WorkLog> _allWorkLogs = [];
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
        _allDockets = dockets;
        _allWorkLogs = workLogs;
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
        _allDockets = [];
        _allWorkLogs = [];
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Search Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search by ID, person, type, or depot...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Filter Section
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, isMobile ? 8 : 10),
              child: isMobile && isPortrait
                  ? _buildMobileFilters()
                  : _buildDesktopFilters(),
            ),

            const SizedBox(height: 24),

            // Bar Chart Section - Last 3 Months Dockets
            Container(
              margin: const EdgeInsets.all(16),
              child: _buildBarChartSection(),
            ),

            const SizedBox(height: 32),
          ],
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
                        child: Text(branch, overflow: TextOverflow.ellipsis),
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
                decoration: const InputDecoration(
                  labelText: 'Branch',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                isExpanded: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: availableDepots.contains(_selectedDepot)
                    ? _selectedDepot
                    : 'All',
                items: availableDepots
                    .map(
                      (depot) => DropdownMenuItem(
                        value: depot,
                        child: Text(depot, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedDepot = v ?? 'All'),
                decoration: const InputDecoration(
                  labelText: 'Depot',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                isExpanded: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Second row: Worker
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedWorker,
                items: _availableWorkers
                    .map(
                      (worker) => DropdownMenuItem(
                        value: worker,
                        child: Text(worker, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedWorker = v ?? 'All'),
                decoration: const InputDecoration(
                  labelText: 'Worker',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                isExpanded: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopFilters() {
    final isTablet =
        MediaQuery.of(context).size.width >= 600 &&
        MediaQuery.of(context).size.width < 1200;

    // Get available depots based on selected branch
    final availableDepots = _selectedBranch == 'All'
        ? kDepots
        : (kBranchDepots[_selectedBranch] ?? ['All']);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Branch Dropdown
        SizedBox(
          width: isTablet ? 180 : 200,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedBranch,
            items: kBranches
                .map(
                  (branch) => DropdownMenuItem(
                    value: branch,
                    child: Text(branch, overflow: TextOverflow.ellipsis),
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
            decoration: const InputDecoration(
              labelText: 'Branch',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 12),

        // Depot Dropdown
        SizedBox(
          width: isTablet ? 180 : 200,
          child: DropdownButtonFormField<String>(
            initialValue: availableDepots.contains(_selectedDepot)
                ? _selectedDepot
                : 'All',
            items: availableDepots
                .map(
                  (depot) => DropdownMenuItem(
                    value: depot,
                    child: Text(depot, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedDepot = v ?? 'All'),
            decoration: const InputDecoration(
              labelText: 'Depot',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 12),

        // Worker Dropdown
        SizedBox(
          width: isTablet ? 160 : 180,
          child: DropdownButtonFormField<String>(
            initialValue: _selectedWorker,
            items: _availableWorkers
                .map(
                  (worker) => DropdownMenuItem(
                    value: worker,
                    child: Text(worker, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedWorker = v ?? 'All'),
            decoration: const InputDecoration(
              labelText: 'Worker',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChartSection() {
    final monthlyStats = _getLastThreeMonthsDocketStats();

    if (monthlyStats.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No monthly data available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Last 3 Months Docket Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 16),
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
