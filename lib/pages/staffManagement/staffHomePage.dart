import 'package:flutter/material.dart';
import 'package:leco_docket_tracker/pages/staffManagement/viewStaff/viewPerson.dart';
import 'addStaff/addPerson.dart';

class StaffHomePage extends StatelessWidget {
  const StaffHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate cross axis count based on screen width
          final width = constraints.maxWidth;
          int crossAxisCount;
          double childAspectRatio;
          
          if (width > 1200) {
            crossAxisCount = 4;
            childAspectRatio = 1.2;
          } else if (width > 800) {
            crossAxisCount = 3;
            childAspectRatio = 1.0;
          } else if (width > 500) {
            crossAxisCount = 2;
            childAspectRatio = 1.0;
          } else {
            crossAxisCount = 1;
            childAspectRatio = 1.5;
          }
          
          return GridView.count(
            padding: EdgeInsets.symmetric(
              horizontal: width > 600 ? 32 : 16,
              vertical: 16,
            ),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
            children: [
              _Tile(
                icon: Icons.person_add_alt_1,
                title: 'Add Staff',
                subtitle: 'Add new staff member',
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
                title: 'View Staff',
                subtitle: 'View and manage staff',
                color: Colors.teal.shade700,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ViewPeoplePage()),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isSmallScreen ? 36 : 48,
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
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
