import 'package:flutter/material.dart';

import 'daily assignments/seeAssignment.dart' as daily_assignments;
import 'workersSummery/WorkersSummery.dart';
import 'depotwiseSummary/depotwiseSummary.dart';

class SeeAssignmentsOptionsPage extends StatelessWidget {
  const SeeAssignmentsOptionsPage({super.key});

  static const Color _primaryColor = Color(0xFF003366);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey[50],
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OptionCard(
              icon: Icons.today,
              title: 'Daily Assignments',
              subtitle: 'View today\'s assignments with filters and charts',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const daily_assignments.SeeAssignmentsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _OptionCard(
              icon: Icons.groups,
              title: 'Workers Summary',
              subtitle: 'See worker-wise assignment summary',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WorkersSummeryPage()),
                );
              },
            ),
            const SizedBox(height: 16),
            _OptionCard(
              icon: Icons.analytics,
              title: 'Depot-wise Summary',
              subtitle: 'View depot and branch-wise assignment analytics',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DepotWiseSummaryPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF003366).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF003366)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
