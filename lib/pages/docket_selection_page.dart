import 'package:flutter/material.dart';
import 'show_dockets.dart';
import '../service/dockey_service.dart';

enum DocketFilter { all, assigned, unassigned, completed }

class DocketSelectionPage extends StatefulWidget {
  const DocketSelectionPage({super.key});

  @override
  State<DocketSelectionPage> createState() => _DocketSelectionPageState();
}

class _DocketSelectionPageState extends State<DocketSelectionPage>
    with TickerProviderStateMixin {
  final DocketService _docketService = DocketService();
  final TextEditingController _searchController = TextEditingController();

  Map<String, int> _docketCounts = {};
  Map<String, Map<DocketFilter, int>> _docketFilterCounts = {};
  bool _isLoading = true;
  String _errorMessage = '';
  String _query = '';
  DocketFilter _selectedFilter = DocketFilter.all;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _fetchDocketCounts();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  Future<void> _fetchDocketCounts() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final dockets = await _docketService.fetchDockets();

      // Count dockets by type
      final Map<String, int> counts = {};
      final Map<String, Map<DocketFilter, int>> filterCounts = {};

      for (final docket in dockets) {
        if (docket.docketType.isNotEmpty) {
          counts[docket.docketType] = (counts[docket.docketType] ?? 0) + 1;

          // Initialize filter counts for this docket type if not exists
          if (!filterCounts.containsKey(docket.docketType)) {
            filterCounts[docket.docketType] = {
              DocketFilter.all: 0,
              DocketFilter.assigned: 0,
              DocketFilter.unassigned: 0,
              DocketFilter.completed: 0,
            };
          }

          // Count all
          filterCounts[docket.docketType]![DocketFilter.all] =
              (filterCounts[docket.docketType]![DocketFilter.all] ?? 0) + 1;

          // Count by status
          if (docket.completedTime.isNotEmpty) {
            filterCounts[docket.docketType]![DocketFilter.completed] =
                (filterCounts[docket.docketType]![DocketFilter.completed] ??
                    0) +
                1;
          } else if (docket.assignedTo.isNotEmpty) {
            // If assignedPersons is not empty, it's assigned
            filterCounts[docket.docketType]![DocketFilter.assigned] =
                (filterCounts[docket.docketType]![DocketFilter.assigned] ?? 0) +
                1;
          } else {
            // If assignedPersons is empty and not completed, it's unassigned
            filterCounts[docket.docketType]![DocketFilter.unassigned] =
                (filterCounts[docket.docketType]![DocketFilter.unassigned] ??
                    0) +
                1;
          }
        }
      }

      setState(() {
        _docketCounts = counts;
        _docketFilterCounts = filterCounts;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load dockets: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Map<String, int> get _filteredDocketCounts {
    if (_selectedFilter == DocketFilter.all) {
      return _docketCounts;
    }

    final Map<String, int> filtered = {};
    _docketFilterCounts.forEach((type, counts) {
      final count = counts[_selectedFilter] ?? 0;
      if (count > 0) {
        filtered[type] = count;
      }
    });
    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildFilterChips() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: DocketFilter.values.map((filter) {
            final isSelected = _selectedFilter == filter;
            final totalCount = _getTotalCountForFilter(filter);

            return Container(
              margin: const EdgeInsets.only(right: 12),
              child: FilterChip(
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getFilterDisplayName(filter),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF003366),
                      ),
                    ),
                    if (totalCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.3)
                              : const Color(0xFF003366).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          totalCount.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF003366),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF003366),
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF003366)
                      : const Color(0xFF003366).withOpacity(0.2),
                  width: 1.5,
                ),
                elevation: isSelected ? 4 : 1,
                shadowColor: const Color(0xFF003366).withOpacity(0.3),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  int _getTotalCountForFilter(DocketFilter filter) {
    if (filter == DocketFilter.all) {
      return _docketCounts.values.fold(0, (sum, count) => sum + count);
    }

    int total = 0;
    _docketFilterCounts.forEach((type, counts) {
      total += counts[filter] ?? 0;
    });
    return total;
  }

  String _getFilterDisplayName(DocketFilter filter) {
    switch (filter) {
      case DocketFilter.all:
        return 'All';
      case DocketFilter.assigned:
        return 'Assigned';
      case DocketFilter.unassigned:
        return 'Unassigned';
      case DocketFilter.completed:
        return 'Completed';
    }
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Docket Selection',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF003366).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: Color(0xFF003366),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading dockets...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Docket Selection',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: Colors.red[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Unable to Load Dockets',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please check your connection and try again',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _fetchDocketCounts,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTopDockets() {
    final currentCounts = _filteredDocketCounts;
    if (currentCounts.isEmpty) return const SizedBox.shrink();

    // Get top 3 most common docket types for current filter
    final List<MapEntry<String, int>> topThree = currentCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topThreeList = topThree.take(3).toList();

    if (topThreeList.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF003366).withOpacity(0.03), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF003366).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: Colors.amber[700],
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Most Active',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const Spacer(),
              Text(
                'Top ${topThreeList.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: topThreeList.asMap().entries.map((entry) {
              final index = entry.key;
              final docketEntry = entry.value;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: index < topThreeList.length - 1 ? 8 : 0,
                  ),
                  child: _CompactTopDocketCard(
                    title: docketEntry.key,
                    count: docketEntry.value,
                    rank: index + 1,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              ShowDocketsPage(title: docketEntry.key),
                        ),
                      );
                    },
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    final currentCounts = _filteredDocketCounts;
    final List<MapEntry<String, int>> filtered = currentCounts.entries
        .where((entry) => entry.key.toLowerCase().contains(_query))
        .toList();

    final double width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width >= 900
        ? 4
        : width >= 600
        ? 3
        : 2;

    final int totalDockets = currentCounts.values.fold(
      0,
      (sum, count) => sum + count,
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Docket Selection',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            Text(
              '$totalDockets total dockets',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchDocketCounts,
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeInAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced header with summary stats
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF003366).withOpacity(0.05),
                          Colors.white,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF003366).withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003366).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.dashboard_customize_rounded,
                            color: Color(0xFF003366),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Docket Overview',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF003366),
                                ),
                              ),
                              Text(
                                '${currentCounts.length} types • $totalDockets ${_getFilterDisplayName(_selectedFilter).toLowerCase()}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Filter chips
                  _buildFilterChips(),

                  // Compact Top 3 Most Active Dockets
                  _buildCompactTopDockets(),

                  // Enhanced search section
                  Container(
                    padding: const EdgeInsets.all(20),
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
                        Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: const Color(0xFF003366),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Find Docket Type',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF003366),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Search by docket type name...',
                              hintStyle: TextStyle(color: Colors.grey[500]),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: Colors.grey[500],
                              ),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color: Colors.grey[500],
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${filtered.length} of ${currentCounts.length} types ${_query.isNotEmpty ? 'matching "$_query"' : 'available'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Grid of docket cards or empty state
                  filtered.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _query.isEmpty
                                      ? Icons.inventory_2_outlined
                                      : Icons.search_off_rounded,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _query.isEmpty
                                    ? 'No ${_getFilterDisplayName(_selectedFilter)} Dockets'
                                    : 'No Results Found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _query.isEmpty
                                    ? 'No ${_getFilterDisplayName(_selectedFilter).toLowerCase()} dockets available'
                                    : 'Try adjusting your search terms or filter',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                          children: filtered
                              .map(
                                (entry) => _DocketCard(
                                  title: entry.key,
                                  count: entry.value,
                                  icon: _iconFor(entry.key),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ShowDocketsPage(title: entry.key),
                                      ),
                                    );
                                  },
                                ),
                              )
                              .toList(),
                        ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String title) {
    switch (title.toLowerCase()) {
      case 'service line maintenance':
      case 'service line maintainance':
        return Icons.handyman_rounded;
      case 'meter testing':
        return Icons.speed_rounded;
      case 'estimate':
        return Icons.request_quote_rounded;
      case 'per visit':
        return Icons.directions_walk_rounded;
      case 'pole disconnection':
        return Icons.power_off_rounded;
      case 'material remove':
        return Icons.remove_circle_outline_rounded;
      case 'meter replacement only':
        return Icons.swap_horiz_rounded;
      case 'visit with contractor':
        return Icons.group_rounded;
      case 'pole top maintenance':
        return Icons.engineering_rounded;
      default:
        return Icons.widgets_rounded;
    }
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 32, color: const Color(0xFF003366)),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF003366),
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF003366),
                        const Color(0xFF004080),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF003366).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
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
}

class _CompactTopDocketCard extends StatelessWidget {
  final String title;
  final int count;
  final int rank;
  final VoidCallback onTap;

  const _CompactTopDocketCard({
    required this.title,
    required this.count,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
        ? const Color(0xFF78909C)
        : const Color(0xFFFF8A65);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: rankColor.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: rankColor.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: rankColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF003366),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF003366), const Color(0xFF004080)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
