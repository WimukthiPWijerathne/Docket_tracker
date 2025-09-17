import 'package:flutter/material.dart';
import 'package:leco_docket_tracker/pages/staffManagement/viewStaff/viewPerson.dart';
import 'addStaff/addPerson.dart';

class StaffHomePage extends StatelessWidget {
  const StaffHomePage({super.key});

  // Calculate responsive grid count based on screen width
  int _calculateGridCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 4;  // Extra large screens
    if (screenWidth > 800) return 3;   // Large screens
    if (screenWidth > 600) return 2;   // Tablets
    return 2;                           // Phones (default)
  }

  // Calculate responsive padding based on screen size
  EdgeInsets _calculatePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return const EdgeInsets.all(32);
    if (screenWidth > 800) return const EdgeInsets.all(24);
    return const EdgeInsets.all(16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            padding: _calculatePadding(context),
            constraints: const BoxConstraints.expand(),
            child: GridView.count(
              crossAxisCount: _calculateGridCount(context),
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 1.0, // Square tiles
              shrinkWrap: true,
              children: [
                _Tile(
                  icon: Icons.person_add_alt_1,
                  title: 'Add Staff Member',
                  color: const Color(0xFF003366),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddPersonPage()),
                    );
                  },
                ),
                _Tile(
                  icon: Icons.people_alt_outlined,
                  title: 'View Staff Directory',
                  color: Colors.teal.shade700,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ViewPeoplePage()),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isSmallScreen ? 42 : 56,
                color: color,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
