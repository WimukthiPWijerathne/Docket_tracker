// lib/pages/viewDockets/viewDocketsSummary.dart
import 'package:flutter/material.dart';
import 'package:leco_docket_tracker/pages/viewDockets/showDocketsList.dart';
import 'package:provider/provider.dart';

import '../../models/dockets.dart';
import '../../service/dockey_service.dart';
import '../loginScreen/fetchUserAccess.dart';

class ViewDocketSummaryPage extends StatefulWidget {
  const ViewDocketSummaryPage({super.key});

  @override
  State<ViewDocketSummaryPage> createState() => _ViewDocketSummaryPageState();
}

class _ViewDocketSummaryPageState extends State<ViewDocketSummaryPage> {
  final DocketService _docketService = DocketService();
  final TextEditingController _searchController = TextEditingController();

  // Data
  List<Docket> _allDockets = [];
  Map<String, int> _docketCounts = {};
  List<String> _depots = const []; // includes "All" when permitted
  String _selectedDepot = 'All';

  // Status filter + totals for tab badges
  // -1 = All, 0..4 = Unassigned..Issue
  int _selectedStatus = 0;  //-1= all tab
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
      final ua = context.read<UserAccess>();
      final access = ua.accessLevel ?? 0;
      _canPickDepot = access <= 4;
      _selectedDepot = _canPickDepot ? 'All' : (ua.depot ?? 'All');
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
        final depot = (d.depot ?? '').trim();
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

  // SAFELY read the assignedTime from each Docket (used for filtering)
  int _assignedOf(Docket d) {
    if (d.AssignedTime == null) return 0;
    final str = d.AssignedTime.toString().trim();
    final val = int.tryParse(str);
    return val ?? 0;
  }


  void _recount() {
    // Filter by depot according to selection/permissions
    Iterable<Docket> depotFiltered = _allDockets;
    if (!_canPickDepot) {
      final myDepot = context.read<UserAccess>().depot ?? '';
      depotFiltered = depotFiltered.where((d) => (d.depot ?? '') == myDepot);
    } else if (_selectedDepot != 'All') {
      depotFiltered = depotFiltered.where((d) => (d.depot ?? '') == _selectedDepot);
    }

    // Build status totals for tabs (independent of search text)
    final statusTotals = <int, int>{-1: 0, 0: 0, 1: 0, 2: 0, 3: 0, 4: 0};
    for (final d in depotFiltered) {
      final s = _assignedOf(d).clamp(0, 4);
      statusTotals[-1] = (statusTotals[-1] ?? 0) + 1;
      statusTotals[s] = (statusTotals[s] ?? 0) + 1;
    }

    // Apply status filter for the grid/top3 counting
    Iterable<Docket> filtered = depotFiltered;
    if (_selectedStatus != -1) {
      filtered = filtered.where((d) => _assignedOf(d) == _selectedStatus);
    }

    // Count by type
    final counts = <String, int>{};
    for (final d in filtered) {
      final t = (d.docketType ?? '').trim();
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
    final entries = _docketCounts.entries
        .where((e) => e.key.toLowerCase().contains(_query))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topThree = (_docketCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();

    // Tab ids: All + 0..4
    final List<int> _tabs = const [-1, 0, 1, 2, 3, 4];

    return DefaultTabController(
      length: _tabs.length,
      initialIndex: _tabs.indexOf(_selectedStatus),
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
                indicatorColor: Colors.white,          // add
                indicatorWeight: 3,                    // add
                labelColor: Colors.white,              // add
                unselectedLabelColor: Colors.white70,  // add
                labelStyle: const TextStyle(fontWeight: FontWeight.bold), // add
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal), // add
                onTap: (idx) {
                  final sel = _tabs[idx];
                  if (sel != _selectedStatus) {
                    setState(() => _selectedStatus = sel);
                    _recount();
                  }
                },
                tabs: _tabs.map((s) {
                  final count = _statusTotals[s] ?? 0;
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon[s], size: 18),
                        const SizedBox(width: 6),
                        Text(_statusLabel[s]!),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF003366), // 👈 badge text dark blue
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
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF003366),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter bar (depot + search)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _FilterBar(
                    depots: _depots,
                    selectedDepot: _selectedDepot,
                    canPickDepot: _canPickDepot,
                    onDepotChanged: (v) {
                      setState(() {
                        _selectedDepot = v;
                      });
                      _recount();
                    },
                    searchController: _searchController,
                  ),
                ),

                // Top 3 (horizontal scroll)
                if (topThree.isNotEmpty) ...[
                  SizedBox(
                    height: 130,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: topThree.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, idx) {
                        final e = topThree[idx];
                        return _TopDocketCard(
                          title: e.key,
                          count: e.value,
                          rank: idx + 1,
                          icon: _iconFor(e.key),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ShowDocketsList(
                                  title: e.key,
                                  depot: _selectedDepot == 'All' ? null : _selectedDepot,
                                  filterStatus: _selectedStatus, // -1,0..4
                                ),
                              ),
                            );




                            // Navigator.of(context).push(
                            //   MaterialPageRoute(
                            //     builder: (_) => ShowDocketsList(
                            //       title: e.key,
                            //       // OPTIONAL: forward selected status to list page
                            //       // filterStatus: _selectedStatus,
                            //     ),
                            //   ),
                            // );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Count text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${entries.length} docket types',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // Grid (scrollable)
                Expanded(
                  child: entries.isEmpty
                      ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'No dockets found for selected filters'
                          : 'No results for "$_query"',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  )
                      : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      itemCount: entries.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.9,
                      ),
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        return _DocketCard(
                          title: e.key,
                          count: e.value,
                          icon: _iconFor(e.key),
                          onTap: () {
                            // Debug (optional): see what we’re sending
                            debugPrint('[Summary] Pushing ShowDocketsList '
                                'title="${e.key}", depot="${_selectedDepot}", status=$_selectedStatus');

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ShowDocketsList(
                                  title: e.key,
                                  depot: _selectedDepot == 'All' ? null : _selectedDepot,
                                  filterStatus: _selectedStatus, // -1,0..4
                                ),
                              ),
                            );
                          },

                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String title) {
    switch (title) {
      case 'Service Line Maintenance':
        return Icons.handyman;
      case 'Meter Testing':
        return Icons.speed;
      case 'Estimate':
        return Icons.request_quote;
      case 'Per Visit':
        return Icons.directions_walk;
      case 'Pole Disconnection':
        return Icons.power_off;
      case 'Material Remove':
        return Icons.remove_circle_outline;
      case 'Meter Replacement Only':
        return Icons.swap_horiz;
      case 'Visit with Contractor':
        return Icons.group;
      case 'Pole Top Maintenance':
        return Icons.engineering;
      default:
        return Icons.widgets;
    }
  }
}

/// ✓ Fixed filter bar (no Expanded inside a Column)
class _FilterBar extends StatelessWidget {
  final List<String> depots;
  final String selectedDepot;
  final bool canPickDepot;
  final ValueChanged<String> onDepotChanged;
  final TextEditingController searchController;

  const _FilterBar({
    required this.depots,
    required this.selectedDepot,
    required this.canPickDepot,
    required this.onDepotChanged,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 700;

    final depotDropdown = DropdownButtonFormField<String>(
      value: selectedDepot,
      isExpanded: true,
      onChanged: canPickDepot
          ? (v) {
        if (v != null) onDepotChanged(v);
      }
          : null,
      items:
      depots.map((d) => DropdownMenuItem<String>(value: d, child: Text(d))).toList(),
      decoration: InputDecoration(
        labelText: 'Depot',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );

    final searchField = TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Search docket types...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => searchController.clear(),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );

    if (isWide) {
      return Row(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: depotDropdown,
          ),
          const SizedBox(width: 16),
          Expanded(child: searchField),
        ],
      );
    }

    // Narrow: stack vertically (NO Expanded here)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        depotDropdown,
        const SizedBox(height: 12),
        searchField,
      ],
    );
  }
}

class _DocketCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final VoidCallback onTap;

  const _DocketCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42, color: const Color(0xFF003366)),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Color(0xFF003366),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopDocketCard extends StatelessWidget {
  final String title;
  final int count;
  final int rank;
  final IconData icon;
  final VoidCallback onTap;

  const _TopDocketCard({
    required this.title,
    required this.count,
    required this.rank,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color rankColor = rank == 1
        ? const Color(0xFFFFD700) // gold
        : rank == 2
        ? const Color(0xFFC0C0C0) // silver
        : const Color(0xFFCD7F32); // bronze

    return SizedBox(
      width: 260,
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [rankColor.withOpacity(0.12), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // rank + icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: rankColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '#$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(icon, color: const Color(0xFF003366)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF003366),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003366),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}



//v1 working fine without the filters
// // lib/pages/viewDockets/viewDocketsSummary.dart
// import 'package:flutter/material.dart';
// import 'package:leco_docket_tracker/pages/viewDockets/showDocketsList.dart';
// import 'package:provider/provider.dart';
//
// import '../../models/dockets.dart';
// import '../../service/dockey_service.dart';
//
// import '../loginScreen/fetchUserAccess.dart';
//
// class ViewDocketSummaryPage extends StatefulWidget {
//   const ViewDocketSummaryPage({super.key});
//
//   @override
//   State<ViewDocketSummaryPage> createState() => _ViewDocketSummaryPageState();
// }
//
// class _ViewDocketSummaryPageState extends State<ViewDocketSummaryPage> {
//   final DocketService _docketService = DocketService();
//   final TextEditingController _searchController = TextEditingController();
//
//   // Data
//   List<Docket> _allDockets = [];
//   Map<String, int> _docketCounts = {};
//   List<String> _depots = const []; // includes "All" when permitted
//   String _selectedDepot = 'All';
//
//   // UI state
//   bool _isLoading = true;
//   String _errorMessage = '';
//   String _query = '';
//
//   // Access / permissions
//   bool _initializedUA = false;
//   bool _canPickDepot = false; // accessLevel <= 4
//
//   @override
//   void initState() {
//     super.initState();
//     _searchController.addListener(() {
//       setState(() => _query = _searchController.text.trim().toLowerCase());
//     });
//   }
//
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     if (!_initializedUA) {
//       final ua = context.read<UserAccess>();
//       final access = ua.accessLevel ?? 0;
//       _canPickDepot = access <= 4;
//       _selectedDepot = _canPickDepot ? 'All' : (ua.depot ?? 'All');
//       _initializedUA = true;
//
//       _fetchAndBuild();
//     }
//   }
//
//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _fetchAndBuild() async {
//     try {
//       setState(() {
//         _isLoading = true;
//         _errorMessage = '';
//       });
//
//       final dockets = await _docketService.fetchDockets();
//       _allDockets = dockets;
//
//       // Build depot list
//       final depotsSet = <String>{};
//       for (final d in _allDockets) {
//         final depot = (d.depot ?? '').trim();
//         if (depot.isNotEmpty) depotsSet.add(depot);
//       }
//       final depots = depotsSet.toList()..sort();
//
//       if (_canPickDepot) {
//         _depots = ['All', ...depots];
//       } else {
//         // techs etc: only their depot (still show a disabled dropdown with their depot)
//         if (_selectedDepot != 'All' && !_depots.contains(_selectedDepot)) {
//           _depots = [_selectedDepot];
//         } else {
//           // fallback
//           _depots = [(context.read<UserAccess>().depot ?? 'Unknown')];
//         }
//       }
//
//       _recount();
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Failed to load dockets: $e';
//         _isLoading = false;
//       });
//     }
//   }
//
//   void _recount() {
//     // Filter by depot according to selection/permissions
//     Iterable<Docket> filtered = _allDockets;
//     if (!_canPickDepot) {
//       final myDepot = context.read<UserAccess>().depot;
//       filtered = filtered.where((d) => (d.depot ?? '') == (myDepot ?? ''));
//     } else if (_selectedDepot != 'All') {
//       filtered = filtered.where((d) => (d.depot ?? '') == _selectedDepot);
//     }
//
//     // Count by type
//     final counts = <String, int>{};
//     for (final d in filtered) {
//       final t = (d.docketType ?? '').trim();
//       if (t.isEmpty) continue;
//       counts[t] = (counts[t] ?? 0) + 1;
//     }
//
//     setState(() {
//       _docketCounts = counts;
//       _isLoading = false;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final width = MediaQuery.of(context).size.width;
//     final crossAxisCount = width >= 1100
//         ? 5
//         : width >= 900
//         ? 4
//         : width >= 600
//         ? 3
//         : 2;
//
//     if (_isLoading) {
//       return Scaffold(
//         appBar: AppBar(
//           title: const Text('Dockets Summary'),
//           backgroundColor: const Color(0xFF003366),
//           foregroundColor: Colors.white,
//         ),
//         body: const Center(
//           child: CircularProgressIndicator(color: Color(0xFF003366)),
//         ),
//       );
//     }
//
//     if (_errorMessage.isNotEmpty) {
//       return Scaffold(
//         appBar: AppBar(
//           title: const Text('Dockets Summary'),
//           backgroundColor: const Color(0xFF003366),
//           foregroundColor: Colors.white,
//         ),
//         body: Center(
//           child: Padding(
//             padding: const EdgeInsets.all(24.0),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
//                 const SizedBox(height: 16),
//                 Text(_errorMessage, textAlign: TextAlign.center),
//                 const SizedBox(height: 16),
//                 ElevatedButton.icon(
//                   onPressed: _fetchAndBuild,
//                   icon: const Icon(Icons.refresh),
//                   label: const Text('Retry'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF003366),
//                     foregroundColor: Colors.white,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }
//
//     // Apply search filter to the counted types
//     final entries = _docketCounts.entries
//         .where((e) => e.key.toLowerCase().contains(_query))
//         .toList()
//       ..sort((a, b) => b.value.compareTo(a.value));
//
//     final topThree = (_docketCounts.entries.toList()
//       ..sort((a, b) => b.value.compareTo(a.value)))
//         .take(3)
//         .toList();
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Dockets Summary'),
//         backgroundColor: const Color(0xFF003366),
//         foregroundColor: Colors.white,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             tooltip: 'Refresh',
//             onPressed: _fetchAndBuild,
//           ),
//         ],
//       ),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.only(bottom: 16.0),
//           child: Column(
//             children: [
//               // Header
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
//                 child: Row(
//                   children: [
//                     const Icon(Icons.list_alt, color: Color(0xFF003366)),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         'Available Number of Dockets',
//                         style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                           fontWeight: FontWeight.bold,
//                           color: const Color(0xFF003366),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               // Filter bar (depot + search) — fixed height; no Expanded in a Column
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 child: _FilterBar(
//                   depots: _depots,
//                   selectedDepot: _selectedDepot,
//                   canPickDepot: _canPickDepot,
//                   onDepotChanged: (v) {
//                     setState(() {
//                       _selectedDepot = v;
//                     });
//                     _recount();
//                   },
//                   searchController: _searchController,
//                 ),
//               ),
//
//               // Top 3 (horizontal scroll to avoid tall layout)
//               if (topThree.isNotEmpty) ...[
//                 SizedBox(
//                   height: 130,
//                   child: ListView.separated(
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     scrollDirection: Axis.horizontal,
//                     itemCount: topThree.length,
//                     separatorBuilder: (_, __) => const SizedBox(width: 12),
//                     itemBuilder: (_, idx) {
//                       final e = topThree[idx];
//                       return _TopDocketCard(
//                         title: e.key,
//                         count: e.value,
//                         rank: idx + 1,
//                         icon: _iconFor(e.key),
//                         onTap: () {
//                           Navigator.of(context).push(
//                             MaterialPageRoute(
//                               builder: (_) => ShowDocketsList(title: e.key),
//                             ),
//                           );
//                         },
//                       );
//                     },
//                   ),
//                 ),
//                 const SizedBox(height: 8),
//               ],
//
//               // Count text
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//                 child: Align(
//                   alignment: Alignment.centerLeft,
//                   child: Text(
//                     '${entries.length} docket types',
//                     style: const TextStyle(
//                       fontSize: 14,
//                       color: Color(0xFF666666),
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ),
//               ),
//
//               // Grid (scrollable area)
//               Expanded(
//                 child: entries.isEmpty
//                     ? Center(
//                   child: Text(
//                     _query.isEmpty
//                         ? 'No dockets found for selected depot'
//                         : 'No results for "$_query"',
//                     style: const TextStyle(color: Colors.black54),
//                   ),
//                 )
//                     : Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   child: GridView.builder(
//                     itemCount: entries.length,
//                     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                       crossAxisCount: crossAxisCount,
//                       crossAxisSpacing: 16,
//                       mainAxisSpacing: 16,
//                       childAspectRatio: 0.9,
//                     ),
//                     itemBuilder: (_, i) {
//                       final e = entries[i];
//                       return _DocketCard(
//                         title: e.key,
//                         count: e.value,
//                         icon: _iconFor(e.key),
//                         onTap: () {
//                           Navigator.of(context).push(
//                             MaterialPageRoute(
//                               builder: (_) => ShowDocketsList(title: e.key),
//                             ),
//                           );
//                         },
//                       );
//                     },
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   IconData _iconFor(String title) {
//     switch (title) {
//       case 'Service Line Maintenance':
//         return Icons.handyman;
//       case 'Meter Testing':
//         return Icons.speed;
//       case 'Estimate':
//         return Icons.request_quote;
//       case 'Per Visit':
//         return Icons.directions_walk;
//       case 'Pole Disconnection':
//         return Icons.power_off;
//       case 'Material Remove':
//         return Icons.remove_circle_outline;
//       case 'Meter Replacement Only':
//         return Icons.swap_horiz;
//       case 'Visit with Contractor':
//         return Icons.group;
//       case 'Pole Top Maintenance':
//         return Icons.engineering;
//       default:
//         return Icons.widgets;
//     }
//   }
// }
//
// /// ✓ Fixed filter bar (no Expanded inside a Column)
// class _FilterBar extends StatelessWidget {
//   final List<String> depots;
//   final String selectedDepot;
//   final bool canPickDepot;
//   final ValueChanged<String> onDepotChanged;
//   final TextEditingController searchController;
//
//   const _FilterBar({
//     required this.depots,
//     required this.selectedDepot,
//     required this.canPickDepot,
//     required this.onDepotChanged,
//     required this.searchController,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final isWide = MediaQuery.of(context).size.width >= 700;
//
//     final depotDropdown = DropdownButtonFormField<String>(
//       value: selectedDepot,
//       isExpanded: true,
//       onChanged: canPickDepot ? (v) {
//         if (v != null) onDepotChanged(v);
//       } : null,
//       items: depots
//           .map((d) => DropdownMenuItem<String>(value: d, child: Text(d)))
//           .toList(),
//       decoration: InputDecoration(
//         labelText: 'Depot',
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       ),
//     );
//
//     final searchField = TextField(
//       controller: searchController,
//       decoration: InputDecoration(
//         hintText: 'Search docket types...',
//         prefixIcon: const Icon(Icons.search),
//         suffixIcon: searchController.text.isEmpty
//             ? null
//             : IconButton(
//           icon: const Icon(Icons.clear),
//           onPressed: () => searchController.clear(),
//         ),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       ),
//     );
//
//     if (isWide) {
//       return Row(
//         children: [
//           ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 320),
//             child: depotDropdown,
//           ),
//           const SizedBox(width: 16),
//           Expanded(child: searchField),
//         ],
//       );
//     }
//
//     // Narrow: stack vertically (NO Expanded here)
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         depotDropdown,
//         const SizedBox(height: 12),
//         searchField,
//       ],
//     );
//   }
// }
//
// class _DocketCard extends StatelessWidget {
//   final String title;
//   final int count;
//   final IconData icon;
//   final VoidCallback onTap;
//
//   const _DocketCard({
//     required this.title,
//     required this.count,
//     required this.icon,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       elevation: 3,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(12),
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(icon, size: 42, color: const Color(0xFF003366)),
//               const SizedBox(height: 12),
//               Text(
//                 title,
//                 textAlign: TextAlign.center,
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   fontWeight: FontWeight.w700,
//                   color: Color(0xFF003366),
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFFFFD700),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Text(
//                   '$count',
//                   style: const TextStyle(
//                     color: Color(0xFF003366),
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class _TopDocketCard extends StatelessWidget {
//   final String title;
//   final int count;
//   final int rank;
//   final IconData icon;
//   final VoidCallback onTap;
//
//   const _TopDocketCard({
//     required this.title,
//     required this.count,
//     required this.rank,
//     required this.icon,
//     required this.onTap,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final Color rankColor = rank == 1
//         ? const Color(0xFFFFD700) // gold
//         : rank == 2
//         ? const Color(0xFFC0C0C0) // silver
//         : const Color(0xFFCD7F32); // bronze
//
//     return SizedBox(
//       width: 260,
//       child: Card(
//         elevation: 5,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         child: InkWell(
//           onTap: onTap,
//           borderRadius: BorderRadius.circular(12),
//           child: Container(
//             padding: const EdgeInsets.all(14),
//             decoration: BoxDecoration(
//               borderRadius: BorderRadius.circular(12),
//               gradient: LinearGradient(
//                 colors: [rankColor.withOpacity(0.12), Colors.white],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // rank + icon
//                 Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: rankColor,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Text(
//                         '#$rank',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                     const Spacer(),
//                     Icon(icon, color: const Color(0xFF003366)),
//                   ],
//                 ),
//                 const SizedBox(height: 10),
//                 Text(
//                   title,
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     color: Color(0xFF003366),
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//                 const Spacer(),
//                 Align(
//                   alignment: Alignment.bottomRight,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFF003366),
//                       borderRadius: BorderRadius.circular(16),
//                     ),
//                     child: Text(
//                       '$count',
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 )
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
