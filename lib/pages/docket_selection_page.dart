import 'package:flutter/material.dart';
import 'show_dockets.dart';

class DocketSelectionPage extends StatefulWidget {
  const DocketSelectionPage({super.key});

  @override
  State<DocketSelectionPage> createState() => _DocketSelectionPageState();
}

class _DocketSelectionPageState extends State<DocketSelectionPage> {
  // Mock data for docket counts - in real app this would come from API/database
  static const Map<String, int> _docketCounts = {
    'Service Line Maintenance': 12,
    'Meter Testing': 8,
    'Estimate': 15,
    'Per Visit': 23,
    'Pole Disconnection': 5,
    'Material Remove': 9,
    'Meter Replacement Only': 17,
    'Visit with Contractor': 11,
    'Pole Top Maintenance': 6,
  };

  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, int>> filtered = _docketCounts.entries
        .where((entry) => entry.key.toLowerCase().contains(_query))
        .toList();

    // Get top 3 most common docket types
    final List<MapEntry<String, int>> topThree = _docketCounts.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value))
        ..take(3).toList();

    final double width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width >= 900
        ? 4
        : width >= 600
            ? 3
            : 2; // keep 2 on phones

    return Scaffold(
      appBar: AppBar(
        title: const Text('Docket Selection'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
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
              
              // Top 3 Most Common Docket Types Section
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
                            children: topThree.asMap().entries.map((entry) {
                              final index = entry.key;
                              final docketEntry = entry.value;
                              return Container(
                                width: double.infinity,
                                margin: EdgeInsets.only(
                                  bottom: index < topThree.length - 1 ? 8 : 0,
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
                            children: topThree.asMap().entries.map((entry) {
                              final index = entry.key;
                              final docketEntry = entry.value;
                              return Expanded(
                                child: Container(
                                  margin: EdgeInsets.only(
                                    right: index < topThree.length - 1 ? 8 : 0,
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
              
              // Grid of docket cards
              Expanded(
                child: GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
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

  // Removed dialog in favor of direct navigation to ShowDocketsPage.
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
      color: const Color(0xFFF8F9FA),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: const Color(0xFFFFD700).withOpacity(0.25),
        overlayColor: MaterialStateProperty.resolveWith<Color?>((states) {
          if (states.contains(MaterialState.pressed) ||
              states.contains(MaterialState.focused) ||
              states.contains(MaterialState.hovered)) {
            return const Color(0xFFFFD700).withOpacity(0.18);
          }
          return null;
        }),
                 child: ClipRRect(
           borderRadius: BorderRadius.circular(16),
           child: Padding(
             padding: const EdgeInsets.all(12.0),
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 // Icon
                 Icon(icon, color: const Color(0xFF003366), size: 28),
                 const SizedBox(height: 8),
                 
                 // Title
                 Text(
                   title,
                   textAlign: TextAlign.center,
                   style: const TextStyle(
                     color: Color(0xFF003366),
                     fontWeight: FontWeight.w600,
                     fontSize: 13,
                   ),
                   maxLines: 2,
                   overflow: TextOverflow.ellipsis,
                 ),
                 const SizedBox(height: 6),
                 
                 // Count badge
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                   decoration: BoxDecoration(
                     color: const Color(0xFFFFD700),
                     borderRadius: BorderRadius.circular(16),
                     boxShadow: [
                       BoxShadow(
                         color: const Color(0xFFFFD700).withOpacity(0.3),
                         blurRadius: 3,
                         offset: const Offset(0, 1),
                       ),
                     ],
                   ),
                   child: Text(
                     '$count',
                     style: const TextStyle(
                       color: Color(0xFF003366),
                       fontWeight: FontWeight.bold,
                       fontSize: 14,
                     ),
                   ),
                 ),
                 
                 const SizedBox(height: 2),
                 
                 // Label
                 const Text(
                   'Available',
                   style: TextStyle(
                     color: Color(0xFF666666),
                     fontSize: 11,
                     fontWeight: FontWeight.w500,
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

class _TopDocketCard extends StatelessWidget {
  final String title;
  final int count;
  final int rank;
  final IconData icon;
  final VoidCallback onTap;
  final bool isMobile;

  const _TopDocketCard({
    required this.title,
    required this.count,
    required this.rank,
    required this.icon,
    required this.onTap,
    this.isMobile = false,
  });

  Color get _rankColor {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFF003366);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: isMobile ? const EdgeInsets.all(16) : const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                _rankColor.withOpacity(0.1),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: isMobile 
            ? Row(
                children: [
                  // Rank badge
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _rankColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _rankColor.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Icon
                  Icon(
                    icon,
                    color: const Color(0xFF003366),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  
                  // Title and count
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF003366),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003366),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$count available',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rank badge
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _rankColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _rankColor.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$rank',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Icon
                  Icon(
                    icon,
                    color: const Color(0xFF003366),
                    size: 20,
                  ),
                  const SizedBox(height: 6),
                  
                  // Title
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003366),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Count
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003366),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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
