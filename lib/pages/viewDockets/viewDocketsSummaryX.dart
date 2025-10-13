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
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAndBuild,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Docket Summary'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAndBuild,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search and filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Depot dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
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
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status Tabs
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final entry in _statusTotals.entries)
                  if (entry.key != -1) // Skip the "All" status in tabs
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          children: [
                            Icon(
                              _statusIcon[entry.key],
                              size: 16,
                              color: _selectedStatus == entry.key
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                            const SizedBox(width: 4),
                            Text(_statusLabel[entry.key] ?? 'Unknown'),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _selectedStatus == entry.key
                                    ? Colors.white24
                                    : Colors.black12,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                entry.value.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _selectedStatus == entry.key
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        selected: _selectedStatus == entry.key,
                        backgroundColor: _statusChipColor(entry.key),
                        selectedColor: const Color(0xFF003366),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedStatus = entry.key;
                              _recount();
                            });
                          }
                        },
                      ),
                    ),
              ],
            ),
          ),

          const Divider(),

          // Docket types grid
          Expanded(child: _buildDocketGrid(crossAxisCount)),
        ],
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
      return const Center(child: Text('No matching docket types found'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: filteredCounts.length,
      itemBuilder: (context, index) {
        final entry = filteredCounts[index];
        final type = entry.key;
        final count = entry.value;

        return Card(
          elevation: 2,
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
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
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
