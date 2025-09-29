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

  // Selected filters
  String selectedBranch = 'Kelaniya';
  String selectedDocketType = 'All Types';

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

      // Fetch data for the selected branch's depots
      List<DepotSummaryData> summaryData =
          await DepotSummaryService.getDepotSummary(
            depotNames: depotNames,
            docketType: selectedDocketType == 'All Types'
                ? null
                : selectedDocketType,
          );

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

  double _getMaxYValue() {
    if (chartData.isEmpty) return 20;
    double maxValue = 0;
    for (var data in chartData) {
      if (data.inProgressCount > maxValue)
        maxValue = data.inProgressCount.toDouble();
      if (data.completedCount > maxValue)
        maxValue = data.completedCount.toDouble();
    }
    return maxValue * 1.2;
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
      ),
      body: Container(
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
                          ? const Center(
                              child: Text(
                                'No data available for the selected filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
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
                                    _buildLegendItem('Completed', Colors.green),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Chart
                                Expanded(
                                  child: BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: _getMaxYValue(),
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
                                                      overflow:
                                                          TextOverflow.ellipsis,
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
                                            reservedSize: 40,
                                            getTitlesWidget: (value, meta) {
                                              return Text(
                                                value.toInt().toString(),
                                                style: const TextStyle(
                                                  fontSize: 11,
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
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      barGroups: chartData.asMap().entries.map((
                                        entry,
                                      ) {
                                        return BarChartGroupData(
                                          x: entry.key,
                                          barRods: [
                                            BarChartRodData(
                                              toY: entry.value.inProgressCount
                                                  .toDouble(),
                                              color: Colors.orange,
                                              width: 16,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(3),
                                                    topRight: Radius.circular(
                                                      3,
                                                    ),
                                                  ),
                                            ),
                                            BarChartRodData(
                                              toY: entry.value.completedCount
                                                  .toDouble(),
                                              color: Colors.green,
                                              width: 16,
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(3),
                                                    topRight: Radius.circular(
                                                      3,
                                                    ),
                                                  ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                      gridData: FlGridData(
                                        show: true,
                                        horizontalInterval: 5,
                                        getDrawingHorizontalLine: (value) {
                                          return FlLine(
                                            color: Colors.grey[300]!,
                                            strokeWidth: 1,
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
