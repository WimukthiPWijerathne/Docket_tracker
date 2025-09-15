import 'package:flutter/material.dart';
import 'package:leco_docket_tracker/pages/staffManagement/viewStaff/viewPerson.dart';

import 'addStaff/addPerson.dart';


class StaffHomePage extends StatelessWidget {
  const StaffHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: MediaQuery.of(context).size.width >= 700 ? 3 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _Tile(
            icon: Icons.person_add_alt_1,
            title: 'Add Person',
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
            title: 'View People',
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
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _Tile({required this.icon, required this.title, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
