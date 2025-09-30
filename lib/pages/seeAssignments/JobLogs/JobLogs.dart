import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../service/assigned_docket_service.dart';
import '../../../service/dockey_service.dart' as dockey;
import '../../../models/assigned_docket.dart';
import '../../../models/dockets.dart';

class JobLogsPage extends StatefulWidget {
  const JobLogsPage({super.key});

  @override
  State<JobLogsPage> createState() => _JobLogsPageState();
}

class _JobLogsPageState extends State<JobLogsPage> {
  static const Color _primaryColor = Color(0xFF003366);

  final _assignedSvc = AssignedDocketService();
  final _docketSvc = dockey.DocketService();

  bool _loading = true;
  String? _error;

  List<AssignedDocket> _assignments = [];
  final Map<String, Docket> _docketsMap = {};

  // Filters
  String _selectedBranch = 'All';
  String _selectedDepot = 'All';

  // Fixed color palette for deterministic mapping
  static const List<Color> _palette = <Color>[
    Color(0xFF2196F3), // Blue
    Color(0xFFFF9800), // Orange
    Color(0xFF4CAF50), // Green
    Color(0xFF9C27B0), // Purple
    Color(0xFFF44336), // Red
    Color(0xFF00BCD4), // Cyan
    Color(0xFF3F51B5), // Indigo
    Color(0xFF795548), // Brown
    Color(0xFFE91E63), // Pink
    Color(0xFFFFEB3B), // Yellow
  ];

  // Full depots list
  static const List<String> _allDepots = [
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

  static const List<String> _branches = [
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

  static const Map<String, List<String>> _branchDepots = {
    'All': ['All'],
    'Kelaniya': ['All', 'Wattala', 'Kandana', 'Mahara', 'Dalugama', 'Other'],
    'Kotte': ['All', 'Pitakotte', 'Kolonnawa', 'Kotikawatta', 'Other'],
    'Nugegoda': ['All', 'Boralesgamuwa', 'Nugegoda', 'Maharagama', 'Other'],
    'Moratuwa': ['All', 'Moratuwa North', 'Moratuwa South', 'Keselwatta', 'Panadura', 'Koralawella', 'Other'],
    'Kalutara': ['All', 'Payagala', 'Kalutara', 'Aluthgama', 'Other'],
    'Negombo': ['All', 'Negombo', 'Seeduwa', 'Ja-Ela', 'Other'],
    'Galle': ['All', 'Ambalangoda', 'Hikkaduwa', 'Galle', 'Other'],
    'Head Office': ['All', 'Head Office'],
    'Other': ['All', 'Other'],
  };

  List<String> get _availableDepots =>
      _selectedBranch == 'All' ? _allDepots : (_branchDepots[_selectedBranch] ?? ['All']);

  String _normalizeDepot(String value) {
    final lower = value.trim().toLowerCase();
    return lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _assignedSvc.fetchAssignedDockets(),
        _docketSvc.fetchDockets(),
      ]);

      final assignments = results[0] as List<AssignedDocket>;
      final dockets = results[1] as List<Docket>;

      _docketsMap
        ..clear()
        ..addEntries(dockets.map((d) => MapEntry(d.id, d)));

      setState(() {
        _assignments = assignments;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load job logs: $e';
        _assignments = [];
        _docketsMap.clear();
      });
    }
  }

  Map<String, int> _countByJobCategory() {
    final Map<String, int> counts = {};
    final selDepotNorm = _normalizeDepot(_selectedDepot);

    for (final d in _docketsMap.values) {
      if (_selectedDepot != 'All' && _normalizeDepot(d.depot) != selDepotNorm) {
        continue;
      }

      final type = ((d.docketType).isNotEmpty ? d.docketType : 'Unknown').trim();
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  List<PieChartSectionData> _buildSectionsFromEntries(
    List<MapEntry<String, int>> entries,
    bool isTablet,
  ) {
    return List.generate(entries.length, (i) {
      final e = entries[i];
      return PieChartSectionData(
        value: e.value.toDouble(),
        color: _palette[i % _palette.length],
        radius: isTablet ? 80 : 70,
        title: '',
        borderSide: const BorderSide(color: Colors.white, width: 2),
      );
    });
  }

  Widget _buildLegend(List<MapEntry<String, int>> entries, bool isTablet) {
    final total = entries.fold<int>(0, (p, e) => p + e.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries.asMap().entries.map((entry) {
        final i = entry.key;
        final e = entry.value;
        final color = _palette[i % _palette.length];
        final percent = total > 0 ? ((e.value / total) * 100).toStringAsFixed(1) : '0.0';
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: isTablet ? 18 : 16,
                height: isTablet ? 18 : 16,
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.key,
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF003366),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${e.value} dockets ($percent%)',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final horizontalPadding = isTablet ? 24.0 : 16.0;
    
    final counts = _countByJobCategory();
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sections = _buildSectionsFromEntries(entries, isTablet);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Job Logs',
          style: TextStyle(fontSize: isTablet ? 22 : 20),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: Icon(Icons.refresh, size: isTablet ? 26 : 24),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
              ),
            )
          : _error != null
              ? _Error(message: _error!, onRetry: _load, isTablet: isTablet)
              : Container(
                  color: Colors.grey[50],
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Filters Section
                        _FiltersCard(
                          selectedBranch: _selectedBranch,
                          selectedDepot: _selectedDepot,
                          availableDepots: _availableDepots,
                          onBranchChanged: (v) {
                            setState(() {
                              _selectedBranch = v ?? 'All';
                              _selectedDepot = 'All';
                            });
                          },
                          onDepotChanged: (v) {
                            setState(() {
                              _selectedDepot = v ?? 'All';
                            });
                          },
                          isTablet: isTablet,
                        ),
                        SizedBox(height: isTablet ? 20 : 16),
                        
                        // Chart Card
                        _ChartCard(
                          counts: counts,
                          entries: entries,
                          sections: sections,
                          buildLegend: () => _buildLegend(entries, isTablet),
                          isTablet: isTablet,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  final String selectedBranch;
  final String selectedDepot;
  final List<String> availableDepots;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<String?> onDepotChanged;
  final bool isTablet;

  const _FiltersCard({
    required this.selectedBranch,
    required this.selectedDepot,
    required this.availableDepots,
    required this.onBranchChanged,
    required this.onDepotChanged,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_list,
                color: const Color(0xFF003366),
                size: isTablet ? 24 : 20,
              ),
              SizedBox(width: isTablet ? 12 : 8),
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF003366),
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 20 : 16),
          
          LayoutBuilder(
            builder: (context, constraints) {
              if (isTablet && constraints.maxWidth > 500) {
                return Row(
                  children: [
                    Expanded(
                      child: _FilterDropdown(
                        label: 'Branch',
                        value: selectedBranch,
                        items: _JobLogsPageState._branches,
                        onChanged: onBranchChanged,
                        isTablet: isTablet,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FilterDropdown(
                        label: 'Depot',
                        value: availableDepots.contains(selectedDepot) ? selectedDepot : 'All',
                        items: availableDepots,
                        onChanged: onDepotChanged,
                        isTablet: isTablet,
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _FilterDropdown(
                      label: 'Branch',
                      value: selectedBranch,
                      items: _JobLogsPageState._branches,
                      onChanged: onBranchChanged,
                      isTablet: isTablet,
                    ),
                    const SizedBox(height: 16),
                    _FilterDropdown(
                      label: 'Depot',
                      value: availableDepots.contains(selectedDepot) ? selectedDepot : 'All',
                      items: availableDepots,
                      onChanged: onDepotChanged,
                      isTablet: isTablet,
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool isTablet;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTablet ? 15 : 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: isTablet ? 10 : 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 6 : 4,
              ),
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.keyboard_arrow_down),
              style: TextStyle(
                fontSize: isTablet ? 16 : 15,
                color: const Color(0xFF003366),
                fontWeight: FontWeight.w500,
              ),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
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

class _ChartCard extends StatelessWidget {
  final Map<String, int> counts;
  final List<MapEntry<String, int>> entries;
  final List<PieChartSectionData> sections;
  final Widget Function() buildLegend;
  final bool isTablet;

  const _ChartCard({
    required this.counts,
    required this.entries,
    required this.sections,
    required this.buildLegend,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final total = entries.fold<int>(0, (p, e) => p + e.value);

    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF003366).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  color: const Color(0xFF003366),
                  size: isTablet ? 24 : 20,
                ),
              ),
              SizedBox(width: isTablet ? 12 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dockets by Job Category',
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF003366),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$total total dockets',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 28 : 24),
          
          counts.isEmpty
              ? _EmptyChart(isTablet: isTablet)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final useVerticalLayout = constraints.maxWidth < 500 || !isTablet;
                    
                    if (useVerticalLayout) {
                      // Vertical layout for mobile
                      return Column(
                        children: [
                          SizedBox(
                            height: 240,
                            child: PieChart(
                              PieChartData(
                                sections: sections,
                                sectionsSpace: 2,
                                centerSpaceRadius: isTablet ? 50 : 45,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          buildLegend(),
                        ],
                      );
                    } else {
                      // Horizontal layout for tablet
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              child: buildLegend(),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 300,
                              child: PieChart(
                                PieChartData(
                                  sections: sections,
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 60,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final bool isTablet;
  
  const _EmptyChart({required this.isTablet});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isTablet ? 280 : 240,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 2, style: BorderStyle.solid),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pie_chart_outline_outlined,
              size: isTablet ? 64 : 56,
              color: Colors.grey[400],
            ),
            SizedBox(height: isTablet ? 16 : 12),
            Text(
              'No data available',
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Apply different filters to see results',
              style: TextStyle(
                fontSize: isTablet ? 14 : 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isTablet;
  
  const _Error({
    required this.message,
    required this.onRetry,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 32.0 : 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: isTablet ? 64 : 56,
                color: Colors.red[400],
              ),
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF003366),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isTablet ? 15 : 14,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: isTablet ? 28 : 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 32 : 24,
                  vertical: isTablet ? 16 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}