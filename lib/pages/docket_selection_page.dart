import 'package:flutter/material.dart';
import 'show_dockets.dart';
import '../service/dockey_service.dart';
import '../models/dockets.dart';

class DocketSelectionPage extends StatefulWidget {
  const DocketSelectionPage({super.key});

  @override
  State<DocketSelectionPage> createState() => _DocketSelectionPageState();
}

class _DocketSelectionPageState extends State<DocketSelectionPage> {
  final DocketService _docketService = DocketService();
  final TextEditingController _searchController = TextEditingController();
  
  Map<String, int> _docketCounts = {};
  bool _isLoading = true;
  String _errorMessage = '';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchDocketCounts();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
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
      for (final docket in dockets) {
        if (docket.docketType.isNotEmpty) {
          counts[docket.docketType] = (counts[docket.docketType] ?? 0) + 1;
        }
      }

      setState(() {
        _docketCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load dockets: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Docket Selection'),
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF003366),
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Docket Selection'),
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchDocketCounts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final List<MapEntry<String, int>> filtered = _docketCounts.entries
        .where((entry) => entry.key.toLowerCase().contains(_query))
        .toList();

    // Get top 3 most common docket types
    final List<MapEntry<String, int>> topThree = _docketCounts.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    final topThreeList = topThree.take(3).toList();

    final double width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width >= 900
        ? 4
        : width >= 600
            ? 3
            : 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Docket Selection'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDocketCounts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // H1 Heading with suitable styling
                const Text(
                  'Available No of Dockets',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003366),
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // Top 3 Most Common Docket Types Section - only show if we have data
                if (topThreeList.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF003366).withOpacity(0.1),
                          const Color(0xFFFFD700).withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF003366).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.trending_up,
                              color: const Color(0xFF003366),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Most Common Docket Types',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF003366),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Use column layout for very narrow screens
                            if (constraints.maxWidth < 400) {
                              return Column(
                                children: topThreeList.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final docketEntry = entry.value;
                                  return Container(
                                    width: double.infinity,
                                    margin: EdgeInsets.only(
                                      bottom: index < topThreeList.length - 1 ? 8 : 0,
                                    ),
                                    child: _TopDocketCard(
                                      title: docketEntry.key,
                                      count: docketEntry.value,
                                      rank: index + 1,
                                      icon: _iconFor(docketEntry.key),
                                      isMobile: true,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => ShowDocketsPage(title: docketEntry.key),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                }).toList(),
                              );
                            } else {
                              // Use row layout for wider screens
                              return Row(
                                children: topThreeList.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final docketEntry = entry.value;
                                  return Expanded(
                                    child: Container(
                                      margin: EdgeInsets.only(
                                        right: index < topThreeList.length - 1 ? 8 : 0,
                                      ),
                                      child: _TopDocketCard(
                                        title: docketEntry.key,
                                        count: docketEntry.value,
                                        rank: index + 1,
                                        icon: _iconFor(docketEntry.key),
                                        isMobile: false,
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => ShowDocketsPage(title: docketEntry.key),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search docket types...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF003366)),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF003366)),
                            onPressed: () {
                              _searchController.clear();
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF003366)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Results count
                Text(
                  '${filtered.length} docket types available',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Grid of docket cards or empty state
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6, // Fixed height with some padding
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _query.isEmpty
                                    ? 'No dockets available'
                                    : 'No dockets found for "$_query"',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.count(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8, // Adjust the aspect ratio as needed
                          children: filtered
                              .map((entry) => _DocketCard(
                                    title: entry.key,
                                    count: entry.value,
                                    icon: _iconFor(entry.key),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => ShowDocketsPage(title: entry.key),
                                        ),
                                      );
                                    },
                                  ))
                              .toList(),
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

// Missing widget classes that were referenced but not defined
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
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: const Color(0xFF003366),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003366),
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
  final bool isMobile;
  final VoidCallback onTap;

  const _TopDocketCard({
    required this.title,
    required this.count,
    required this.rank,
    required this.icon,
    required this.isMobile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color rankColor = rank == 1
        ? const Color(0xFFFFD700) // Gold
        : rank == 2
            ? const Color(0xFFC0C0C0) // Silver
            : const Color(0xFFCD7F32); // Bronze

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                rankColor.withOpacity(0.1),
                Colors.white,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Icon(
                    icon,
                    size: 24,
                    color: const Color(0xFF003366),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF003366),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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