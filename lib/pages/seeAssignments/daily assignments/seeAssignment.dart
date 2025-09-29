import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

// --- Models
import '../../../models/assigned_docket.dart';
import '../../../models/dockets.dart';

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
  List<Docket> _allDockets = [];
  final Map<String, Docket> _docketsMap = {};

  // UI State
  late AnimationController _animationController;
  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Assigned',
    'Completed',
    'Overdue',
  ];
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

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load data in parallel
      final results = await Future.wait([
        _assignedDocketSvc.fetchAssignedDockets(),
        _docketSvc.fetchDockets(),
      ]);

      final assignments = results[0] as List<AssignedDocket>;
      final dockets = results[1] as List<Docket>;

      // Create docket lookup map
      _docketsMap.clear();
      for (final docket in dockets) {
        _docketsMap[docket.id] = docket;
      }

      // Populate filter options
      _populateFilterOptions(assignments);

      // Update state
      setState(() {
        _allAssignments = assignments;
        _allDockets = dockets;
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
        _docketsMap.clear();
      });
    }
  }

  // Normalize depot names for robust comparisons (case/space/hyphen insensitive)
  String _normalizeDepot(String value) {
    final lower = value.trim().toLowerCase();
    // remove all non-alphanumeric characters
    return lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
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

    // Apply status filter
    switch (_selectedFilter) {
      case 'Assigned':
        filtered = filtered.where((a) => a.isOngoing).toList();
        break;
      case 'Completed':
        filtered = filtered.where((a) => a.isCompleted).toList();
        break;
      case 'Overdue':
        filtered = filtered.where((a) => a.isOverdue()).toList();
        break;
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
          .where((a) => a.isCompleted)
          .length;

      months.add((
        month: monthName,
        totalDockets: totalDockets,
        completedDockets: completedDockets,
      ));
    }

    return months;
  }

  // Get assignment statistics (filtered)
  ({int total, int completed, int ongoing, int overdue}) _getStatistics() {
    final assignments = _getFilteredAssignments();
    return (
      total: assignments.length,
      completed: assignments.where((a) => a.isCompleted).length,
      ongoing: assignments.where((a) => a.isOngoing).length,
      overdue: assignments.where((a) => a.isOverdue()).length,
    );
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
      completed: todayAssignments.where((a) => a.isCompleted).length,
      ongoing: todayAssignments.where((a) => a.isOngoing).length,
      overdue: todayAssignments.where((a) => a.isOverdue()).length,
    );
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
          'Assignment Overview',
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
    final stats = _getStatistics();
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
            // Summary Statistics Cards at the top
            Container(
              margin: const EdgeInsets.all(16),
              child: _buildSummaryCards(stats),
            ),

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

            // Filter Chips (Status)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _filterOptions.length,
                itemBuilder: (context, index) {
                  final filter = _filterOptions[index];
                  final isSelected = _selectedFilter == filter;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      selectedColor: _primaryColor.withOpacity(0.1),
                      checkmarkColor: _primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected ? _primaryColor : Colors.grey[700],
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Filter Section (similar to staff page)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, isMobile ? 8 : 10),
              child: isMobile && isPortrait
                  ? _buildMobileFilters()
                  : _buildDesktopFilters(),
            ),

            const SizedBox(height: 24),

            // Pie Chart Section - Today's assignments
            Container(
              margin: const EdgeInsets.all(16),
              child: _buildPieChartSection(),
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

  Widget _buildPieChartSection() {
    // Get daily statistics instead of filtered statistics
    final dailyStats = _getDailyStatistics();

    // Calculate total for pie chart (only ongoing and completed)
    final chartTotal = dailyStats.ongoing + dailyStats.completed;

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
            'Today\'s Assignment Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: chartTotal > 0
                ? PieChart(
                    PieChartData(
                      sections: [
                        if (dailyStats.completed > 0)
                          PieChartSectionData(
                            value: dailyStats.completed.toDouble(),
                            title: 'Completed\n${dailyStats.completed}',
                            color: Colors.green,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        if (dailyStats.ongoing > 0)
                          PieChartSectionData(
                            value: dailyStats.ongoing.toDouble(),
                            title: 'Ongoing\n${dailyStats.ongoing}',
                            color: Colors.orange,
                            radius: 60,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                      ],
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  )
                : Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pie_chart_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No assignments today',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.green, 'Completed'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.orange, 'Ongoing'),
            ],
          ),
        ],
      ),
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

  Widget _buildSummaryCards(
    ({int total, int completed, int ongoing, int overdue}) stats,
  ) {
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
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: _primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Summary Statistics',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: "Total",
                  count: stats.total,
                  icon: Icons.assignment,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: "Ongoing",
                  count: stats.ongoing,
                  icon: Icons.schedule,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: "Completed",
                  count: stats.completed,
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  title: "Overdue",
                  count: stats.overdue,
                  icon: Icons.warning,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            "$count",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
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
