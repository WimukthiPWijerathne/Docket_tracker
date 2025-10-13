// lib/pages/viewDockets/viewDocketsSummaryX.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/docketsX.dart';
import '../../service/dockey_serviceX.dart';
import '../loginScreen/fetchUserAccess.dart';
import 'showDocketsListX.dart';

class ViewDocketSummaryXPage extends StatefulWidget {
  const ViewDocketSummaryXPage({super.key});

  @override
  State<ViewDocketSummaryXPage> createState() => _ViewDocketSummaryXPageState();
}

class _ViewDocketSummaryXPageState extends State<ViewDocketSummaryXPage> {
  final DocketServiceX _docketService = DocketServiceX();
  final TextEditingController _searchController = TextEditingController();

  // Data
  List<Docket> _allDockets = [];
  Map<String, int> _docketCounts = {};
  List<String> _depots = const []; // includes "All" when permitted
  String _selectedDepot = 'All';

  // Status filter + totals for tab badges
  // -1 = All, 0..4 = Unassigned..Issue
  int _selectedStatus = 0; //-1= all tab
  Map<int, int> _statusTotals = {};

  // UI state
  bool _isLoading = true;
  String _errorMessage = '';
  String _query = '';

  // Access / permissions
  bool _initializedUA = false;
  bool _canPickDepot = false; // accessLevel <= 4

  // Status metadata
  static const Map<int, String> _statusLabel = {
    -1: 'All',
    0: 'Unassigned',
    1: 'Assigned',
    2: 'Completed',
    3: 'Reassigned',
    4: 'Issue',
  };

  static const Map<int, IconData> _statusIcon = {
    -1: Icons.all_inbox,
    0: Icons.pending_outlined,
    1: Icons.assignment_turned_in_outlined,
    2: Icons.check_circle_outline,
    3: Icons.restart_alt,
    4: Icons.report_problem_outlined,
  };

  Color _statusChipColor(int s) {
    switch (s) {
      case 0:
        return Colors.blueGrey.shade100;
      case 1:
        return Colors.blue.shade100;
      case 2:
        return Colors.green.shade100;
      case 3:
        return Colors.orange.shade100;
      case 4:
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedUA) {
      try {
        // Try to get UserAccess, but don't crash if not available
        final ua = Provider.of<UserAccess>(context, listen: false);
        final access = ua.accessLevel ?? 0;
        _canPickDepot = access <= 4;
        _selectedDepot = _canPickDepot ? 'All' : (ua.depot ?? 'All');
      } catch (e) {
        // If UserAccess provider is not found, give full access
        _canPickDepot = true;
        _selectedDepot = 'All';
      }

      _initializedUA = true;
      _fetchAndBuild();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndBuild() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final dockets = await _docketService.fetchDockets();
      _allDockets = dockets;

      // Build depot list
      final depotsSet = <String>{};
      for (final d in _allDockets) {
        final depot = d.depot.trim();
        if (depot.isNotEmpty) depotsSet.add(depot);
      }
      final depots = depotsSet.toList()..sort();

      if (_canPickDepot) {
        _depots = ['All', ...depots];
      } else {
        // techs etc: only their depot (still show a disabled dropdown with their depot)
        if (_selectedDepot != 'All' && !_depots.contains(_selectedDepot)) {
          _depots = [_selectedDepot];
        } else {
          // fallback
          _depots = [(context.read<UserAccess>().depot ?? 'Unknown')];
        }
      }

      _recount();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load dockets: $e';
        _isLoading = false;
      });
    }
  }

  // SAFELY read the status from each Docket (used for filtering)
  int _statusOf(Docket d) {
    final str = d.status.trim();
    final val = int.tryParse(str);
    return val ?? 0;
  }

  void _recount() {
    // Filter by depot according to selection/permissions
    Iterable<Docket> depotFiltered = _allDockets;

    String? myDepot;
    try {
      // Try to get UserAccess, but don't crash if not available
      myDepot = Provider.of<UserAccess>(context, listen: false).depot;
    } catch (e) {
      // If UserAccess provider is not found, no filtering by depot
      myDepot = null;
    }

    if (!_canPickDepot && myDepot != null) {
      depotFiltered = depotFiltered.where((d) => d.depot == myDepot);
    } else if (_selectedDepot != 'All') {
      depotFiltered = depotFiltered.where((d) => d.depot == _selectedDepot);
    }

    // Build status totals for tabs (independent of search text)
    final statusTotals = <int, int>{-1: 0, 0: 0, 1: 0, 2: 0, 3: 0, 4: 0};
    for (final d in depotFiltered) {
      final s = _statusOf(d).clamp(0, 4);
      statusTotals[-1] = (statusTotals[-1] ?? 0) + 1;
      statusTotals[s] = (statusTotals[s] ?? 0) + 1;
    }

    // Apply status filter for the grid/top3 counting
    Iterable<Docket> filtered = depotFiltered;
    if (_selectedStatus != -1) {
      filtered = filtered.where((d) => _statusOf(d) == _selectedStatus);
    }

    // Count by type
    final counts = <String, int>{};
    for (final d in filtered) {
      final t = d.docketType.trim();
      if (t.isEmpty) continue;
      counts[t] = (counts[t] ?? 0) + 1;
    }

    setState(() {
      _statusTotals = statusTotals;
      _docketCounts = counts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100
        ? 5
        : width >= 900
        ? 4
        : width >= 600
        ? 3
        : 2;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dockets Summary'),
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF003366)),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dockets Summary'),
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(_errorMessage, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _fetchAndBuild,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Apply search filter to the counted types
    final filteredCounts = _docketCounts.entries.where((e) {
      if (_query.isEmpty) return true;
      return e.key.toLowerCase().contains(_query.toLowerCase());
    }).toList()..sort((a, b) => b.value.compareTo(a.value));

    // Get top three docket types
    final topThree =
        (_docketCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(3)
            .toList();

    // Tab ids: All + 0..4
    final List<int> tabs = const [-1, 0, 1, 2, 3, 4];

    return DefaultTabController(
      length: tabs.length,
      initialIndex: tabs.indexOf(_selectedStatus),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dockets Summary'),
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: _fetchAndBuild,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                ),
                onTap: (idx) {
                  final sel = tabs[idx];
                  if (sel != _selectedStatus) {
                    setState(() => _selectedStatus = sel);
                    _recount();
                  }
                },
                tabs: tabs.map((s) {
                  final count = _statusTotals[s] ?? 0;
                  return Tab(
                    height: 46, // Increase height to prevent overflow
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon[s], size: 18),
                        const SizedBox(width: 6),
                        Text(_statusLabel[s]!),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2, // Reduced vertical padding
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF003366),
                              fontSize: 12, // Reduced font size
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.list_alt, color: Color(0xFF003366)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Available Number of Dockets',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF003366),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      // Search field
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search docket types',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Depot dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedDepot,
                        decoration: InputDecoration(
                          labelText: 'Depot',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: _depots
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                        onChanged: _canPickDepot
                            ? (value) {
                                setState(() {
                                  _selectedDepot = value!;
                                  _recount();
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),

                // Top 3 docket types (horizontal scroll)
                if (topThree.isNotEmpty) ...[
                  SizedBox(
                    height: 120, // Reduced height
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        4,
                        16,
                        4,
                      ), // Added vertical padding
                      scrollDirection: Axis.horizontal,
                      itemCount: topThree.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, idx) {
                        final e = topThree[idx];
                        return _buildTopDocketCard(
                          title: e.key,
                          count: e.value,
                          rank: idx + 1,
                          onTap: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => ShowDocketsListX(
                                      title: e.key,
                                      depot: _selectedDepot == 'All'
                                          ? null
                                          : _selectedDepot,
                                      filterStatus: _selectedStatus,
                                    ),
                                  ),
                                )
                                .then((_) => _fetchAndBuild());
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Docket types grid
                Expanded(child: _buildDocketGrid(crossAxisCount)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to get an icon for a docket type
  IconData _iconFor(String type) {
    final t = type.toLowerCase();
    if (t.contains('meter')) return Icons.speed;
    if (t.contains('pole')) return Icons.electric_bolt;
    if (t.contains('maintenance')) return Icons.build;
    if (t.contains('visit')) return Icons.directions_walk;
    if (t.contains('disconnect')) return Icons.power_off;
    if (t.contains('service')) return Icons.home_repair_service;
    return Icons.article;
  }

  Widget _buildTopDocketCard({
    required String title,
    required int count,
    required int rank,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12), // Reduced padding
            child: Column(
              mainAxisSize:
                  MainAxisSize.min, // Prevent column from expanding too much
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF003366),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(6), // Reduced padding
                      child: Icon(
                        _iconFor(title),
                        color: Colors.white,
                        size: 20, // Slightly smaller icon
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '#$rank',
                      style: const TextStyle(
                        fontSize: 18, // Slightly smaller text
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003366),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8), // Reduced spacing
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4), // Reduced spacing
                Text(
                  '$count Dockets',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocketGrid(int crossAxisCount) {
    final filteredCounts =
        _docketCounts.entries.where((e) {
          if (_query.isEmpty) return true;
          return e.key.toLowerCase().contains(_query.toLowerCase());
        }).toList()..sort(
          (a, b) => b.value.compareTo(a.value),
        ); // Sort by count descending

    if (filteredCounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No matching docket types found',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3, // Increased aspect ratio to give more height
      ),
      itemCount: filteredCounts.length,
      itemBuilder: (context, index) {
        final entry = filteredCounts[index];
        final type = entry.key;
        final count = entry.value;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShowDocketsListX(
                    title: type,
                    depot: _selectedDepot == 'All' ? null : _selectedDepot,
                    filterStatus: _selectedStatus == -1
                        ? null
                        : _selectedStatus,
                  ),
                ),
              ).then((_) => _fetchAndBuild()); // Refresh on return
            },
            child: Padding(
              padding: const EdgeInsets.all(12), // Reduced padding
              child: Column(
                mainAxisSize: MainAxisSize.min, // Prevent auto-expansion
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _iconFor(type),
                    size: 28, // Slightly smaller icon
                    color: const Color(0xFF003366),
                  ),
                  const SizedBox(height: 6), // Reduced spacing
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 22, // Slightly smaller text
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 6), // Reduced spacing
                  Text(
                    type,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                    ), // Slightly smaller text
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
