import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/depot_summary_service.dart';

class DepotWiseSummaryPage extends StatefulWidget {
  const DepotWiseSummaryPage({super.key});

  @override
  State<DepotWiseSummaryPage> createState() => _DepotWiseSummaryPageState();
}

class _DepotWiseSummaryPageState extends State<DepotWiseSummaryPage> {
  static const Color _primaryColor = Color(0xFF003366);

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

  // Available docket types (will be populated from database)
  List<String> docketTypes = ['All Types'];
  bool docketTypesLoaded = false;

  // Month filter options
  final List<String> months = [
    'All Time',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // Selected filters
  String selectedBranch = 'Kelaniya';
  String selectedDocketType = 'All Types';
  String selectedMonth = 'All Time';

  // Real data from the database
  List<DepotChartData> chartData = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDocketTypes();
    _loadRealData();
  }

  Future<void> _loadDocketTypes() async {
    if (!docketTypesLoaded) {
      try {
        List<String> actualDocketTypes =
            await DepotSummaryService.getAllDocketTypes();
        setState(() {
          docketTypes = ['All Types', ...actualDocketTypes];
          docketTypesLoaded = true;
        });
        print('UI DEBUG: Loaded docket types: $docketTypes');
      } catch (e) {
        print('Error loading docket types: $e');
      }
    }
  }

  Future<void> _loadRealData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get depot names based on selected branch
      List<String> depotNames = _getDepotsForBranch(selectedBranch);
      print('UI DEBUG: Selected branch: $selectedBranch, Depots: $depotNames');
      print('UI DEBUG: Selected docket type: $selectedDocketType');
      print('UI DEBUG: Selected month: $selectedMonth');

      // Convert month name to month number (1-12) or null for "All Time"
      int? monthNumber;
      if (selectedMonth != 'All Time') {
        monthNumber = months.indexOf(selectedMonth); // Will be 1-12
      }

      // Fetch data for the selected branch's depots using parallel processing
      Map<String, dynamic> result =
          await DepotSummaryService.getDepotSummaryWithMetrics(
            depotNames: depotNames,
            docketType: selectedDocketType == 'All Types'
                ? null
                : selectedDocketType,
            month: monthNumber,
          );

      List<DepotSummaryData> summaryData =
          result['data'] as List<DepotSummaryData>;

      // Log performance metrics
      Map<String, dynamic> metrics = result['metrics'];
      print(
        'UI DEBUG: Data loaded in ${metrics['executionTimeMs']}ms for ${metrics['depotCount']} depots',
      );
      if (metrics.containsKey('totalDockets')) {
        print('UI DEBUG: Total dockets processed: ${metrics['totalDockets']}');
      }

      print('UI DEBUG: Received ${summaryData.length} summary data items');
      for (var data in summaryData) {
        print(
          'UI DEBUG: ${data.depotName} - InProgress: ${data.inProgressCount}, Completed: ${data.completedCount}',
        );
      }

      setState(() {
        chartData = summaryData
            .map(
              (data) => DepotChartData(
                depotName: data.depotName,
                inProgressCount: data.inProgressCount,
                completedCount: data.completedCount,
              ),
            )
            .toList();
        print('UI DEBUG: ChartData created with ${chartData.length} items');
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
        // Fallback to empty data or show error message
        chartData = [];
      });
    }
  }

  // Helper method to get depot names for a branch
  List<String> _getDepotsForBranch(String branch) {
    return branchDepots[branch] ?? [];
  }

  /// Refresh data when user pulls to refresh
  Future<void> _refreshData() async {
    print('=== REFRESH: Starting pull-to-refresh ===');

    try {
      // Refresh docket types first (in case new ones were added)
      await _loadDocketTypes();

      // Then refresh the main data
      await _loadRealData();

      print('=== REFRESH: Pull-to-refresh completed successfully ===');
    } catch (e) {
      print('=== REFRESH: Error during pull-to-refresh: $e ===');

      // Show snackbar for error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Force refresh all data and clear any cached information
  Future<void> _forceRefreshAllData() async {
    print('=== FORCE REFRESH: Starting complete data refresh ===');

    setState(() {
      isLoading = true;
      docketTypesLoaded = false; // Force reload of docket types
      chartData = []; // Clear existing data
    });

    try {
      // Reload docket types from server
      await _loadDocketTypes();

      // Reload chart data
      await _loadRealData();

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data refreshed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      print('=== FORCE REFRESH: Complete data refresh finished ===');
    } catch (e) {
      print('=== FORCE REFRESH: Error during force refresh: $e ===');

      setState(() {
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  double _getMaxYValue() {
    if (chartData.isEmpty) {
      print('DEBUG: Chart data is empty, returning default maxY: 10');
      return 10.0;
    }

    int maxValue = 0;
    for (var data in chartData) {
      if (data.inProgressCount > maxValue) {
        maxValue = data.inProgressCount;
      }
      if (data.completedCount > maxValue) {
        maxValue = data.completedCount;
      }
    }

    print('DEBUG: Max value from data: $maxValue');

    // Enhanced Y-axis scaling logic
    if (maxValue == 0) {
      print('DEBUG: Max value is 0, returning 5');
      return 5.0;
    }

    // Calculate appropriate scale based on data range
    double calculatedMax;
    if (maxValue <= 5) {
      calculatedMax = 10.0;
    } else if (maxValue <= 10) {
      calculatedMax = 15.0;
    } else if (maxValue <= 20) {
      calculatedMax = 25.0;
    } else if (maxValue <= 50) {
      // Round to nearest 10, then add 20%
      calculatedMax = ((maxValue / 10).ceil() * 10 * 1.2).ceilToDouble();
    } else if (maxValue <= 100) {
      // Round to nearest 20, then add 20%
      calculatedMax = ((maxValue / 20).ceil() * 20 * 1.2).ceilToDouble();
    } else {
      // For larger values, round to nearest appropriate interval
      int interval = _getAppropriateInterval(maxValue);
      calculatedMax = ((maxValue / interval).ceil() * interval * 1.2)
          .ceilToDouble();
    }

    print('DEBUG: Calculated maxY: $calculatedMax');
    return calculatedMax;
  }

  // Helper method to determine appropriate interval based on max value
  int _getAppropriateInterval(int maxValue) {
    if (maxValue <= 100) return 20;
    if (maxValue <= 500) return 50;
    if (maxValue <= 1000) return 100;
    if (maxValue <= 5000) return 500;
    return 1000;
  }

  // Calculate Y-axis interval for better tick spacing
  double _getYAxisInterval() {
    double maxY = _getMaxYValue();

    if (maxY <= 10) return 2.0;
    if (maxY <= 25) return 5.0;
    if (maxY <= 50) return 10.0;
    if (maxY <= 100) return 20.0;
    if (maxY <= 200) return 25.0;
    if (maxY <= 500) return 50.0;

    // For larger values, use appropriate intervals
    return (maxY / 10).ceilToDouble();
  }

  // Format Y-axis labels for better readability
  String _formatYAxisLabel(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return value.toString();
    }
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Depot-wise Summary'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: isLoading ? null : _forceRefreshAllData,
            icon: Icon(
              Icons.refresh,
              color: isLoading ? Colors.grey : Colors.white,
            ),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: _primaryColor,
        backgroundColor: Colors.white,
        child: Container(
          color: Colors.grey[50],
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Filters Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Branch and Docket Type Filters Row
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
                                _loadRealData();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildFilterDropdown(
                            'Docket Type',
                            selectedDocketType,
                            docketTypes,
                            (value) {
                              setState(() {
                                selectedDocketType = value!;
                                _loadRealData();
                              });
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Month Filter Row
                    _buildFilterDropdown('Month', selectedMonth, months, (
                      value,
                    ) {
                      setState(() {
                        selectedMonth = value!;
                        _loadRealData();
                      });
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Chart Section
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                        'Assignment Distribution',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Depot-wise docket count for $selectedBranch branch ${selectedDocketType == 'All Types' ? '(All docket types)' : '($selectedDocketType)'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),

                      // Bar Chart
                      Expanded(
                        child: isLoading
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Loading data...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : chartData.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.bar_chart,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No data available for the selected filters',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Pull down to refresh or try different filters',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _forceRefreshAllData,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Refresh Data'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _primaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  // Legend
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildLegendItem(
                                        'In Progress',
                                        Colors.orange,
                                      ),
                                      const SizedBox(width: 20),
                                      _buildLegendItem(
                                        'Completed',
                                        Colors.green,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Chart
                                  Expanded(
                                    child: BarChart(
                                      BarChartData(
                                        alignment:
                                            BarChartAlignment.spaceAround,
                                        maxY: _getMaxYValue(),
                                        minY: 0,
                                        barTouchData: BarTouchData(
                                          enabled: true,
                                          touchTooltipData: BarTouchTooltipData(
                                            getTooltipColor: (group) =>
                                                Colors.grey[800]!,
                                            tooltipRoundedRadius: 8,
                                            getTooltipItem:
                                                (
                                                  group,
                                                  groupIndex,
                                                  rod,
                                                  rodIndex,
                                                ) {
                                                  String status = rodIndex == 0
                                                      ? 'In Progress'
                                                      : 'Completed';
                                                  return BarTooltipItem(
                                                    '${chartData[group.x.toInt()].depotName}\n$status: ${rod.toY.round()}',
                                                    const TextStyle(
                                                      color: Colors.white,
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
                                              reservedSize: 60,
                                              getTitlesWidget: (value, meta) {
                                                if (value.toInt() <
                                                    chartData.length) {
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    child: RotatedBox(
                                                      quarterTurns: -1,
                                                      child: Text(
                                                        chartData[value.toInt()]
                                                            .depotName,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  );
                                                }
                                                return const Text('');
                                              },
                                            ),
                                          ),
                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 45,
                                              interval: _getYAxisInterval(),
                                              getTitlesWidget: (value, meta) {
                                                // Only show whole number labels and skip decimals
                                                if (value % 1 != 0) {
                                                  return const Text('');
                                                }

                                                int intValue = value.round();
                                                if (intValue < 0) {
                                                  return const Text('');
                                                }

                                                // Skip labels that are too close to max to avoid overlap
                                                double maxY = _getMaxYValue();
                                                if (intValue > maxY * 0.95) {
                                                  return const Text('');
                                                }

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8.0,
                                                      ),
                                                  child: Text(
                                                    _formatYAxisLabel(intValue),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.black87,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    textAlign: TextAlign.right,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          rightTitles: const AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: false,
                                            ),
                                          ),
                                          topTitles: const AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: false,
                                            ),
                                          ),
                                        ),
                                        borderData: FlBorderData(
                                          show: true,
                                          border: Border(
                                            left: BorderSide(
                                              color: Colors.grey[400]!,
                                              width: 1,
                                            ),
                                            bottom: BorderSide(
                                              color: Colors.grey[400]!,
                                              width: 1,
                                            ),
                                            right: BorderSide.none,
                                            top: BorderSide.none,
                                          ),
                                        ),
                                        barGroups: chartData
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                              return BarChartGroupData(
                                                x: entry.key,
                                                barRods: [
                                                  BarChartRodData(
                                                    toY: entry
                                                        .value
                                                        .inProgressCount
                                                        .toDouble(),
                                                    color: Colors.orange,
                                                    width: 16,
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                3,
                                                              ),
                                                          topRight:
                                                              Radius.circular(
                                                                3,
                                                              ),
                                                        ),
                                                  ),
                                                  BarChartRodData(
                                                    toY: entry
                                                        .value
                                                        .completedCount
                                                        .toDouble(),
                                                    color: Colors.green,
                                                    width: 16,
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                3,
                                                              ),
                                                          topRight:
                                                              Radius.circular(
                                                                3,
                                                              ),
                                                        ),
                                                  ),
                                                ],
                                              );
                                            })
                                            .toList(),
                                        gridData: FlGridData(
                                          show: true,
                                          horizontalInterval:
                                              _getYAxisInterval(),
                                          getDrawingHorizontalLine: (value) {
                                            // Don't draw grid line at 0 or very close to maxY
                                            if (value == 0 ||
                                                value >
                                                    _getMaxYValue() * 0.95) {
                                              return FlLine(
                                                color: Colors.transparent,
                                              );
                                            }
                                            return FlLine(
                                              color: Colors.grey[200]!,
                                              strokeWidth: 0.8,
                                            );
                                          },
                                          drawVerticalLine: false,
                                        ),
                                      ),
                                    ),
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
      ),
    );
  }

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
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[50],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down),
              items: options.map((String option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
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

// Data model for depot chart with grouped bars
class DepotChartData {
  final String depotName;
  final int inProgressCount;
  final int completedCount;

  DepotChartData({
    required this.depotName,
    required this.inProgressCount,
    required this.completedCount,
  });
}
