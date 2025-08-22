import 'package:flutter/material.dart';

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
              const SizedBox(height: 28),
              
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
                              _showDocketDetails(context, entry.key, entry.value);
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

  void _showDocketDetails(BuildContext context, String title, int count) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text('There are $count dockets available for $title.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Navigate to docket list page or create new docket
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Selected $title with $count dockets'),
                    backgroundColor: const Color(0xFF003366),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                foregroundColor: Colors.white,
              ),
              child: const Text('Select'),
            ),
          ],
        );
      },
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
